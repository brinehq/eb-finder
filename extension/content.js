(async function () {
  const api = globalThis.browser || globalThis.chrome;
  if (!api || !api.storage) return;

  const API_BASE = "https://onlineshopping.loyaltykey.com";
  const CHANNEL = "sas/sv-SE";
  const CACHE_TTL_MS = 60 * 60 * 1000;
  const SESSION_KEY = "ebfinder_banner_closed";
  const ROOT_ID = "ebfinder-root";
  const DECORATED_ATTR = "data-ebfinder-decorated";
  const BADGE_CLASS = "ebfinder-badge";
  const PENDING_KEY_PREFIX = "pending_return_";
  const PENDING_TTL_MS = 60 * 60 * 1000;

  const detectedMatches = new Set();
  const detailPromises = new Map();

  if (api.runtime && api.runtime.onMessage) {
    api.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
      if (msg && msg.type === "ebfinder-detected") {
        sendResponse({ matches: Array.from(detectedMatches) });
      }
    });
  }

  const STRINGS = {
    variable: "{name} är en EuroBonus-partner — tjäna {points} per 100 kr.",
    fixed: "{name} är en EuroBonus-partner — tjäna {points} som ny kund.",
    short: "{name} är en EB-partner",
    cta: "LOGGA IN & TJÄNA",
    ctaShort: "TJÄNA",
  };

  const getCache = async (key) => {
    try {
      const result = await api.storage.local.get([key]);
      const cached = result[key];
      if (cached && Date.now() - cached.timestamp < CACHE_TTL_MS) {
        return cached.data;
      }
    } catch (e) {}
    return null;
  };

  const setCache = async (key, data) => {
    try {
      await api.storage.local.set({ [key]: { data, timestamp: Date.now() } });
    } catch (e) {}
  };

  const fetchJson = async (url) => {
    try {
      const res = await fetch(url, { credentials: "omit" });
      if (!res.ok) return null;
      return await res.json();
    } catch (e) {
      return null;
    }
  };

  const fetchShopMap = async () => {
    const cacheKey = `list_${CHANNEL}`;
    const cached = await getCache(cacheKey);
    if (cached) return cached;
    const json = await fetchJson(`${API_BASE}/api/browser-extension/${CHANNEL}/shops`);
    if (json && typeof json === "object") await setCache(cacheKey, json);
    return json;
  };

  const fetchShopDetail = async (uuid) => {
    const cacheKey = `detail_${uuid}_${CHANNEL}`;
    const cached = await getCache(cacheKey);
    if (cached) return cached;
    const json = await fetchJson(`${API_BASE}/api/browser-extension/${CHANNEL}/shops/${uuid}`);
    const data = json && json.data ? json.data : null;
    if (data) await setCache(cacheKey, data);
    return data;
  };

  const getOrFetchDetail = (uuid) => {
    if (!detailPromises.has(uuid)) {
      detailPromises.set(uuid, fetchShopDetail(uuid));
    }
    return detailPromises.get(uuid);
  };

  const normalizeUrl = (urlStr) => {
    if (!urlStr) return "";
    try {
      const url = new URL(urlStr);
      return (url.hostname + url.pathname)
        .toLowerCase()
        .trim()
        .replace(/^www\./, "")
        .replace(/\/$/, "");
    } catch (e) {
      return urlStr
        .toLowerCase()
        .trim()
        .replace(/^https?:\/\//, "")
        .replace(/^www\./, "")
        .replace(/\/$/, "");
    }
  };

  const getShopMatchId = (currentUrl, shopList) => {
    const testUrl = normalizeUrl(currentUrl);
    if (!testUrl) return null;
    const matchedKey = Object.keys(shopList).find((key) => {
      const normalizedKey = normalizeUrl(key);
      return testUrl === normalizedKey || testUrl.startsWith(normalizedKey + "/");
    });
    return matchedKey ? shopList[matchedKey] : null;
  };

  const storePendingReturn = (originalUrl, shopUuid) => {
    try {
      return api.storage.local.set({
        [`${PENDING_KEY_PREFIX}${shopUuid}`]: {
          originalUrl,
          timestamp: Date.now(),
        },
      });
    } catch (e) {
      return Promise.resolve();
    }
  };

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

  const formatPoints = (value) => {
    const n = parseInt(value, 10) || 0;
    return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ");
  };

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

    const template = data.commission_type === "fixed" ? STRINGS.fixed : STRINGS.variable;
    const points = formatPoints(data.points || data.cashback || 0);
    const name = data.name || "";
    const pointsSpan = `<span class="points-highlight">${points} poäng</span>`;
    const fullText = template.replace("{points}", pointsSpan).replace("{name}", name);
    const shortText = STRINGS.short.replace("{name}", name);

    container.innerHTML = `
      <div class="banner-wrapper">
        <div class="text-section">
          <span class="text-full">${fullText}</span>
          <span class="text-short">${shortText}</span>
        </div>
        <div class="actions">
          <a href="${data.url}" target="_blank" rel="noopener noreferrer" class="cta-btn">
            <span class="cta-full">${STRINGS.cta}</span>
            <span class="cta-short">${STRINGS.ctaShort}</span>
          </a>
          <button class="close-btn" aria-label="Close">✕</button>
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

  const BADGE_STYLE = [
    "display:inline-flex !important",
    "align-items:center !important",
    "justify-content:center !important",
    "vertical-align:middle !important",
    "background:#0f1e82 !important",
    "color:#ffffff !important",
    'font:700 10px/1 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif !important',
    "letter-spacing:0.4px !important",
    "padding:3px 6px !important",
    "border-radius:4px !important",
    "text-decoration:none !important",
    "cursor:pointer !important",
    "margin:0 0 0 6px !important",
    "min-width:0 !important",
    "width:auto !important",
    "height:auto !important",
    "user-select:none !important",
    "position:relative !important",
    "z-index:2147483646 !important",
    "box-shadow:0 1px 2px rgba(0,0,0,0.2) !important",
    "white-space:nowrap !important",
    "text-shadow:none !important",
    "opacity:1 !important",
  ].join(";");

  const injectBadge = (target, matchedId) => {
    if (!target || !target.parentNode) return;
    if (target.classList && target.classList.contains(BADGE_CLASS)) return;
    const next = target.nextElementSibling;
    if (next && next.classList && next.classList.contains(BADGE_CLASS)) return;

    const badge = document.createElement("span");
    badge.className = BADGE_CLASS;
    badge.textContent = "EB";
    badge.title = "EuroBonus-partner — klicka för att handla via SAS";
    badge.setAttribute("role", "link");
    badge.setAttribute("aria-label", "EuroBonus-partner — handla via SAS");
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
      const suffix = detail.commission_type === "fixed" ? "som ny kund" : "per 100 kr";
      badge.title = `${detail.name} – ${points} poäng ${suffix}. Klicka för att handla via SAS.`;
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
