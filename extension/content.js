// EB Finder — content script.
//
// Runs on every page: detects EuroBonus partner shops (direct visits + Google
// results), shows the top banner / injects result badges, and bounces the user
// back after the SAS click-through. Shared data + the i18n helper come from the
// `EB` namespace (shared.js, loaded before this file — see manifest). UI strings
// live in _locales/<lang>/messages.json (standard WebExtension i18n).

(async function () {
  const api = globalThis.browser || globalThis.chrome;
  if (!api || !api.storage) return;

  reportHostPermission(api);

  const {
    t,
    formatPoints,
    fetchShopMap,
    fetchShopDetail,
    getShopMatchId,
    normalizeUrl,
    storePendingReturn,
    PENDING_KEY_PREFIX,
  } = globalThis.EB;

  const SESSION_KEY = "ebfinder_banner_closed";
  const ROOT_ID = "ebfinder-root";
  const DECORATED_ATTR = "data-ebfinder-decorated";
  const BADGE_CLASS = "ebfinder-badge";
  const PENDING_TTL_MS = 60 * 60 * 1000;

  const detectedMatches = new Set();
  const detailPromises = new Map();

  // The popup asks the content script which partners it has spotted (Google).
  if (api.runtime && api.runtime.onMessage) {
    api.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
      if (msg && msg.type === "ebfinder-detected") {
        sendResponse({ matches: Array.from(detectedMatches) });
      }
    });
  }

  // Memoize per-shop detail fetches so repeated badges share one request.
  const getOrFetchDetail = (uuid) => {
    if (!detailPromises.has(uuid)) {
      detailPromises.set(uuid, fetchShopDetail(uuid));
    }
    return detailPromises.get(uuid);
  };

  // --- pending return after the SAS click-through --------------------------
  const looksLikePostSasLanding = (url) => {
    try {
      const u = new URL(url);
      const p = u.searchParams;
      if (p.has("irclickid") || p.has("irgwc") || p.has("irpid")) return true;
      if (p.has("awc") || p.has("awinmid") || p.has("awinaffid")) return true;
      if (p.has("at_gd") || p.has("tap_a") || p.has("tap_s")) return true;
      if (p.has("tduid")) return true;
      if (p.has("afsrc")) return true;
      const utmSource = (p.get("utm_source") || "").toLowerCase();
      if (/impact|awin|adtraction|tradedoubler|cobiro|loyaltykey/.test(utmSource)) {
        return true;
      }
      const utmCampaign = (p.get("utm_campaign") || "").toLowerCase();
      if (utmCampaign.includes("sas") && utmCampaign.includes("onlineshopping")) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  };

  const buildReturnUrl = (originalUrl, sasLandingUrl) => {
    try {
      const original = new URL(originalUrl);
      const sas = new URL(sasLandingUrl);
      for (const [key, value] of sas.searchParams) {
        original.searchParams.set(key, value);
      }
      return original.toString();
    } catch (e) {
      return originalUrl;
    }
  };

  const handlePendingReturn = async (matchedId) => {
    const key = `${PENDING_KEY_PREFIX}${matchedId}`;
    let stored;
    try {
      stored = await api.storage.local.get([key]);
    } catch (e) {
      return false;
    }
    const pending = stored[key];
    if (!pending) return false;

    if (Date.now() - pending.timestamp > PENDING_TTL_MS) {
      try {
        await api.storage.local.remove([key]);
      } catch (e) {}
      return false;
    }

    const currentUrl = window.location.href;
    if (!looksLikePostSasLanding(currentUrl)) return false;

    if (normalizeUrl(currentUrl) === normalizeUrl(pending.originalUrl)) {
      try {
        await api.storage.local.remove([key]);
      } catch (e) {}
      return false;
    }

    const returnUrl = buildReturnUrl(pending.originalUrl, currentUrl);
    try {
      await api.storage.local.remove([key]);
    } catch (e) {}
    location.replace(returnUrl);
    return true;
  };

  // --- top banner (direct partner visits) ----------------------------------
  const buildBanner = async (uuid) => {
    const data = await fetchShopDetail(uuid);
    if (!data) return null;

    const root = document.createElement("div");
    root.id = ROOT_ID;

    const shadow = root.attachShadow({ mode: "open" });

    const link = document.createElement("link");
    link.rel = "stylesheet";
    link.href = api.runtime.getURL("styles.css");
    shadow.appendChild(link);

    const container = document.createElement("div");
    container.className = "fixed-banner-container";

    const points = formatPoints(data.points || data.cashback || 0);
    const name = data.name || "";
    const suffix = t(data.commission_type === "fixed" ? "suffixFixed" : "suffixVariable");
    const fullText = t("banner", [name, points, suffix]);
    const shortText = t("bannerShort", [name]);

    container.innerHTML = `
      <div class="banner-wrapper">
        <div class="text-section">
          <span class="text-full">${fullText}</span>
          <span class="text-short">${shortText}</span>
        </div>
        <div class="actions">
          <a href="${data.url}" target="_blank" rel="noopener noreferrer" class="cta-btn">
            <span class="cta-full">${t("cta")}</span>
            <span class="cta-short">${t("ctaShort")}</span>
          </a>
          <button class="close-btn" aria-label="${t("close")}">✕</button>
        </div>
      </div>`;
    shadow.appendChild(container);

    const ctaLink = shadow.querySelector(".cta-btn");
    if (ctaLink) {
      ctaLink.addEventListener("click", () => {
        // Fire-and-forget so the browser's default new-tab navigation keeps the user-gesture.
        storePendingReturn(window.location.href, uuid);
      });
    }

    const closeBtn = shadow.querySelector(".close-btn");
    if (closeBtn) {
      closeBtn.addEventListener("click", () => {
        root.remove();
        document.documentElement.style.marginTop = "";
        document.querySelectorAll('[data-ebfinder-pushed="true"]').forEach((el) => {
          el.style.top = el.dataset.ebfinderPrevTop || "";
        });
        try {
          sessionStorage.setItem(SESSION_KEY, "true");
        } catch (e) {}
      });
    }
    return root;
  };

  const showTopBanner = async (uuid) => {
    if (document.getElementById(ROOT_ID)) return;
    const banner = await buildBanner(uuid);
    if (!banner) return;
    document.documentElement.prepend(banner);

    const bannerEl = banner.shadowRoot.querySelector(".fixed-banner-container");
    if (!bannerEl) return;

    document.querySelectorAll("*").forEach((el) => {
      if (el.id === ROOT_ID) return;
      const s = window.getComputedStyle(el);
      if (s.position === "fixed" && s.top === "0px") {
        el.dataset.ebfinderPrevTop = el.style.top || "";
        el.dataset.ebfinderPushed = "true";
      }
    });

    const syncOffset = () => {
      const h = bannerEl.offsetHeight;
      if (h <= 0) return;
      document.documentElement.style.setProperty("margin-top", `${h}px`, "important");
      document.querySelectorAll('[data-ebfinder-pushed="true"]').forEach((el) => {
        el.style.setProperty("top", `${h}px`, "important");
      });
    };

    syncOffset();
    new ResizeObserver(syncOffset).observe(bannerEl);
  };

  // --- Google result badges ------------------------------------------------
  // Mirrors styles.css. Inline !important styles fight third-party CSS on
  // host pages, so `var(--*)` can't reach here — values stay literal.
  const TOKENS = {
    primary:  "#003df5",  /* --primary (SAS blue) */
    radiusMd: "6px",      /* --radius-md */
  };

  // EB icon glyph — the framed "EB" monogram (currentColor).
  const EB_GLYPH_SVG =
    '<svg width="17" height="17" fill="none" viewBox="0 0 24 24" aria-hidden="true" style="display:block">' +
    '<path fill="currentColor" fill-rule="evenodd" d="M12.31 15.5v-7h2.663q.754 0 1.253.24.503.235.75.645.253.411.252.93 0 .428-.163.731-.164.3-.438.49a1.9 1.9 0 0 1-.615.27v.068q.37.02.71.228.344.205.56.582.218.375.218.909 0 .543-.262.977-.261.43-.788.68-.526.25-1.324.25zm1.26-1.06h1.355q.687 0 .989-.263a.87.87 0 0 0 .306-.683 1.05 1.05 0 0 0-.588-.957 1.44 1.44 0 0 0-.673-.147H13.57zm0-2.963h1.247q.326 0 .587-.12a.928.928 0 0 0 .564-.878.87.87 0 0 0-.285-.67q-.282-.263-.84-.263H13.57z" clip-rule="evenodd"></path>' +
    '<path fill="currentColor" d="M6.5 8.5v7h4.552v-1.063H7.76v-1.91h3.03v-1.064H7.76v-1.9h3.264V8.5z"></path>' +
    '<path fill="currentColor" fill-rule="evenodd" d="M4.2 4h15.6A2.2 2.2 0 0 1 22 6.2v11.6a2.2 2.2 0 0 1-2.2 2.2H4.2A2.2 2.2 0 0 1 2 17.8V6.2A2.2 2.2 0 0 1 4.2 4m0 1.5a.7.7 0 0 0-.7.7v11.6a.7.7 0 0 0 .7.7h15.6a.7.7 0 0 0 .7-.7V6.2a.7.7 0 0 0-.7-.7z" clip-rule="evenodd"></path></svg>';

  // Ghost badge: transparent fill, SAS-blue framed-EB glyph (shadcn Badge ghost).
  const BADGE_STYLE = [
    "display:inline-flex !important",
    "align-items:center !important",
    "justify-content:center !important",
    "vertical-align:middle !important",
    "background:transparent !important",
    `color:${TOKENS.primary} !important`,
    "padding:3px !important",
    `border-radius:${TOKENS.radiusMd} !important`,
    "text-decoration:none !important",
    "cursor:pointer !important",
    "margin:0 0 0 6px !important",
    "min-width:0 !important",
    "width:auto !important",
    "height:auto !important",
    "user-select:none !important",
    "position:relative !important",
    "z-index:2147483646 !important",
    "white-space:nowrap !important",
    "opacity:1 !important",
  ].join(";");

  const injectBadge = (target, matchedId) => {
    if (!target || !target.parentNode) return;
    if (target.classList && target.classList.contains(BADGE_CLASS)) return;
    const next = target.nextElementSibling;
    if (next && next.classList && next.classList.contains(BADGE_CLASS)) return;

    const badge = document.createElement("span");
    badge.className = BADGE_CLASS;
    badge.innerHTML = EB_GLYPH_SVG;
    badge.title = t("badgeTitle");
    badge.setAttribute("role", "link");
    badge.setAttribute("aria-label", t("badgeAria"));
    badge.setAttribute("tabindex", "0");
    badge.style.cssText = BADGE_STYLE;

    const activate = async (e) => {
      e.preventDefault();
      e.stopPropagation();
      if (typeof e.stopImmediatePropagation === "function") e.stopImmediatePropagation();
      const detail = await getOrFetchDetail(matchedId);
      if (detail && detail.url) {
        window.open(detail.url, "_blank", "noopener,noreferrer");
      }
    };

    const swallow = (e) => {
      e.stopPropagation();
      if (typeof e.stopImmediatePropagation === "function") e.stopImmediatePropagation();
    };

    badge.addEventListener("click", activate);
    badge.addEventListener("mousedown", swallow);
    badge.addEventListener("pointerdown", swallow);
    badge.addEventListener("touchstart", swallow, { passive: true });
    badge.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") activate(e);
    });

    target.parentNode.insertBefore(badge, target.nextSibling);

    getOrFetchDetail(matchedId).then((detail) => {
      if (!detail) return;
      const points = formatPoints(detail.points || detail.cashback || 0);
      const suffix = t(detail.commission_type === "fixed" ? "suffixFixed" : "suffixVariable");
      badge.title = t("badgeTitleDetail", [detail.name, points, suffix]);
    });
  };

  const matchVendorString = (raw, shopList) => {
    if (!raw) return null;
    const trimmed = raw.trim().toLowerCase();
    let id = getShopMatchId(`https://${trimmed}/`, shopList);
    if (id) return id;
    if (!trimmed.includes(".")) {
      for (const tld of [".se", ".com"]) {
        id = getShopMatchId(`https://${trimmed}${tld}/`, shopList);
        if (id) return id;
      }
    }
    return null;
  };

  const ariaVendorSelector = '[aria-label^="From "],[aria-label^="Från "],[aria-label^="Fra "]';

  const decorateGooglePartners = (shopList) => {
    // Primary signal: Google's `data-dtld` ("displayed top-level domain") attribute,
    // present on both shopping card containers and the URL chip in organic results.
    const dtldElements = document.querySelectorAll(`[data-dtld]:not([${DECORATED_ATTR}])`);
    for (const el of dtldElements) {
      el.setAttribute(DECORATED_ATTR, "1");
      const domain = el.getAttribute("data-dtld");
      if (!domain) continue;
      const matchedId = matchVendorString(domain, shopList);
      if (!matchedId) continue;
      detectedMatches.add(matchedId);
      // Prefer the visible vendor-name display inside the card (aria-label="From X")
      const vendorEl = el.querySelector(ariaVendorSelector);
      const target = vendorEl && el.contains(vendorEl) ? vendorEl : el;
      injectBadge(target, matchedId);
    }

    // Fallback: aria-label="From X" elements outside of any [data-dtld] container
    // (e.g. variant cards, alternate Shopping layouts).
    const ariaElements = document.querySelectorAll(
      `${ariaVendorSelector}:not([${DECORATED_ATTR}])`,
    );
    for (const el of ariaElements) {
      el.setAttribute(DECORATED_ATTR, "1");
      const label = el.getAttribute("aria-label") || "";
      const m = label.match(/^(?:From|Från|Fra)\s+(.+?)$/i);
      if (!m) continue;
      const matchedId = matchVendorString(m[1], shopList);
      if (!matchedId) continue;
      detectedMatches.add(matchedId);
      injectBadge(el, matchedId);
    }
  };

  // --- main ----------------------------------------------------------------
  const shops = await fetchShopMap();
  if (!shops || typeof shops !== "object") return;

  if (window.location.hostname.includes("google.")) {
    decorateGooglePartners(shops);
    let timer;
    const observer = new MutationObserver(() => {
      clearTimeout(timer);
      timer = setTimeout(() => decorateGooglePartners(shops), 200);
    });
    observer.observe(document.body, { childList: true, subtree: true });
    return;
  }

  const matchedId = getShopMatchId(window.location.href, shops);
  if (matchedId) {
    const redirected = await handlePendingReturn(matchedId);
    if (redirected) return;
  }

  try {
    if (sessionStorage.getItem(SESSION_KEY) === "true") return;
  } catch (e) {}

  if (matchedId) await showTopBanner(matchedId);
})();

async function reportHostPermission(api) {
  // Ping the native handler on every page load so the host app can live-verify
  // Safari's website-access grant (e.g. while the onboarding screen waits for
  // the user to switch "All Websites" on). Fire-and-forget — failures just
  // leave the host app on its "set permissions" step.
  if (!api.runtime || !api.runtime.sendNativeMessage) return;
  const hasAllUrls = await hasAllSitesAccess(api);
  try {
    await api.runtime.sendNativeMessage("application.id", {
      type: "host-permission-ping",
      origin: location.origin,
      hasAllUrls: hasAllUrls,
      timestamp: Date.now(),
    });
  } catch (e) {}
}

async function hasAllSitesAccess(api) {
  // Safari can report the all-websites grant under more than one match-pattern
  // shape, so probe several rather than trusting a single pattern (the cause of
  // the host app sometimes never confirming the permission step).
  if (!api.permissions || !api.permissions.contains) return false;
  const candidates = [["*://*/*"], ["https://*/*", "http://*/*"], ["<all_urls>"]];
  for (const origins of candidates) {
    try {
      if (await api.permissions.contains({ origins })) return true;
    } catch (e) {}
  }
  return false;
}
