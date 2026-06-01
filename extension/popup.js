(async function () {
  const api = globalThis.browser || globalThis.chrome;
  const statusEl = document.getElementById("status");
  const ctaEl = document.getElementById("cta");
  const listEl = document.getElementById("match-list");

  const API_BASE = "https://onlineshopping.loyaltykey.com";
  const CHANNEL = "sas/sv-SE";
  const CACHE_TTL_MS = 60 * 60 * 1000;

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
        [`pending_return_${shopUuid}`]: {
          originalUrl,
          timestamp: Date.now(),
        },
      });
    } catch (e) {
      return Promise.resolve();
    }
  };

  const cacheGet = async (key) => {
    try {
      const r = await api.storage.local.get([key]);
      const c = r[key];
      if (c && Date.now() - c.timestamp < CACHE_TTL_MS) return c.data;
    } catch (e) {}
    return null;
  };

  const cacheSet = async (key, data) => {
    try {
      await api.storage.local.set({ [key]: { data, timestamp: Date.now() } });
    } catch (e) {}
  };

  const fetchJson = async (url) => {
    try {
      const r = await fetch(url, { credentials: "omit" });
      if (!r.ok) return null;
      return await r.json();
    } catch (e) {
      return null;
    }
  };

  const fetchShopDetail = async (uuid) => {
    const key = `detail_${uuid}_${CHANNEL}`;
    let detail = await cacheGet(key);
    if (detail) return detail;
    const json = await fetchJson(
      `${API_BASE}/api/browser-extension/${CHANNEL}/shops/${uuid}`,
    );
    detail = json && json.data ? json.data : null;
    if (detail) await cacheSet(key, detail);
    return detail;
  };

  // EB icon glyph — the framed "EB" monogram (currentColor).
  const ebGlyph = (size) =>
    `<svg width="${size}" height="${size}" fill="none" viewBox="0 0 24 24" aria-hidden="true">` +
    `<path fill="currentColor" fill-rule="evenodd" d="M12.31 15.5v-7h2.663q.754 0 1.253.24.503.235.75.645.253.411.252.93 0 .428-.163.731-.164.3-.438.49a1.9 1.9 0 0 1-.615.27v.068q.37.02.71.228.344.205.56.582.218.375.218.909 0 .543-.262.977-.261.43-.788.68-.526.25-1.324.25zm1.26-1.06h1.355q.687 0 .989-.263a.87.87 0 0 0 .306-.683 1.05 1.05 0 0 0-.588-.957 1.44 1.44 0 0 0-.673-.147H13.57zm0-2.963h1.247q.326 0 .587-.12a.928.928 0 0 0 .564-.878.87.87 0 0 0-.285-.67q-.282-.263-.84-.263H13.57z" clip-rule="evenodd"></path>` +
    `<path fill="currentColor" d="M6.5 8.5v7h4.552v-1.063H7.76v-1.91h3.03v-1.064H7.76v-1.9h3.264V8.5z"></path>` +
    `<path fill="currentColor" fill-rule="evenodd" d="M4.2 4h15.6A2.2 2.2 0 0 1 22 6.2v11.6a2.2 2.2 0 0 1-2.2 2.2H4.2A2.2 2.2 0 0 1 2 17.8V6.2A2.2 2.2 0 0 1 4.2 4m0 1.5a.7.7 0 0 0-.7.7v11.6a.7.7 0 0 0 .7.7h15.6a.7.7 0 0 0 .7-.7V6.2a.7.7 0 0 0-.7-.7z" clip-rule="evenodd"></path></svg>`;

  const INFO_ICON =
    `<svg width="18" height="18" fill="none" viewBox="0 0 24 24" aria-hidden="true">` +
    `<circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.6"></circle>` +
    `<path d="M12 8v4M12 16h.01" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"></path></svg>`;

  // Status = shadcn Alert: [icon] [title + description]. Match → success + EB glyph.
  const setStatus = (html, klass) => {
    statusEl.className = `status ${klass || ""}`.trim();
    const icon = klass === "match" ? ebGlyph(18) : INFO_ICON;
    statusEl.innerHTML = `<span class="status-icon">${icon}</span><div class="status-body">${html}</div>`;
  };

  const formatPoints = (v) =>
    (parseInt(v, 10) || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ");

  // Match-list row = shadcn Item: media (EB glyph) · content (name + suffix) · actions (points).
  const renderMatchItem = (li, detail) => {
    if (!detail) {
      li.innerHTML = `<div class="item"><span class="item-media">${ebGlyph(15)}</span><span class="item-content"><div class="item-title">Okänd butik</div></span></div>`;
      return;
    }
    const points = formatPoints(detail.points || detail.cashback || 0);
    const suffix = detail.commission_type === "fixed" ? "som ny kund" : "per 100 kr";
    li.innerHTML = `
      <a href="${detail.url || "#"}" target="_blank" rel="noopener noreferrer">
        <div class="item">
          <span class="item-media">${ebGlyph(15)}</span>
          <span class="item-content">
            <div class="item-title">${detail.name || ""}</div>
            <div class="item-desc">${suffix}</div>
          </span>
          <span class="item-actions">${points} p</span>
        </div>
      </a>
    `;
  };

  const renderMatchList = async (uuids) => {
    listEl.innerHTML = "";
    listEl.classList.add("visible");
    const items = uuids.map((uuid) => {
      const li = document.createElement("li");
      li.innerHTML = `<div class="item"><span class="item-media">${ebGlyph(15)}</span><span class="item-content"><div class="item-title">Laddar…</div></span><span class="item-actions placeholder">…</span></div>`;
      listEl.appendChild(li);
      return { uuid, li };
    });
    await Promise.all(
      items.map(async ({ uuid, li }) => {
        const detail = await fetchShopDetail(uuid);
        renderMatchItem(li, detail);
      }),
    );
  };

  const getCurrentTab = async () => {
    try {
      const tabs = await api.tabs.query({ active: true, currentWindow: true });
      return tabs && tabs[0] ? tabs[0] : null;
    } catch (e) {
      return null;
    }
  };

  const tab = await getCurrentTab();
  if (!tab || !tab.url) {
    setStatus("Ingen aktiv flik hittades.", "no-match");
    return;
  }

  let tabHost = "";
  try {
    tabHost = new URL(tab.url).hostname;
  } catch (e) {}
  const isGoogle = tabHost.includes("google.");

  if (isGoogle) {
    let response = null;
    try {
      response = await api.tabs.sendMessage(tab.id, { type: "ebfinder-detected" });
    } catch (e) {}
    const matches = (response && response.matches) || [];
    if (matches.length === 0) {
      setStatus(
        "<strong>Google-sökning</strong>Inga EuroBonus-partner hittade på sidan ännu. Scrolla eller ladda om om sidan precis öppnades.",
        "no-match",
      );
      return;
    }
    setStatus(
      `<strong>${matches.length} EuroBonus-partner på sidan</strong>Öppna en butik via SAS för att tjäna poäng.`,
      "match",
    );
    await renderMatchList(matches);
    return;
  }

  const listKey = `list_${CHANNEL}`;
  let shops = await cacheGet(listKey);
  if (!shops) {
    shops = await fetchJson(`${API_BASE}/api/browser-extension/${CHANNEL}/shops`);
    if (shops) await cacheSet(listKey, shops);
  }
  if (!shops) {
    setStatus("Kunde inte hämta butikslistan. Försök igen senare.", "no-match");
    return;
  }

  const matchedId = getShopMatchId(tab.url, shops);
  if (!matchedId) {
    setStatus(
      "<strong>Inte en EuroBonus-partner</strong>Den här sidan ger inga EuroBonus-poäng.",
      "no-match",
    );
    return;
  }

  const detail = await fetchShopDetail(matchedId);
  if (!detail) {
    setStatus(
      "<strong>EuroBonus-partner</strong>Logga in via SAS för att tjäna poäng.",
      "match",
    );
    return;
  }

  const points = formatPoints(detail.points || detail.cashback || 0);
  const suffix = detail.commission_type === "fixed" ? "som ny kund" : "per 100 kr";
  setStatus(
    `<strong>${detail.name} är en EuroBonus-partner</strong>Tjäna <strong style="display:inline">${points} poäng</strong> ${suffix}.`,
    "match",
  );
  if (detail.url) {
    ctaEl.href = detail.url;
    ctaEl.style.display = "block";
    ctaEl.addEventListener("click", () => {
      // Fire-and-forget so the browser's default new-tab navigation keeps the user-gesture.
      storePendingReturn(tab.url, matchedId);
    });
  }
})();
