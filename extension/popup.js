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

  const setStatus = (html, klass) => {
    statusEl.className = `status ${klass || ""}`.trim();
    statusEl.innerHTML = html;
  };

  const formatPoints = (v) =>
    (parseInt(v, 10) || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ");

  const renderMatchItem = (li, detail) => {
    if (!detail) {
      li.innerHTML = `<a><span class="shop-name">Okänd butik</span></a>`;
      return;
    }
    const points = formatPoints(detail.points || detail.cashback || 0);
    const suffix = detail.commission_type === "fixed" ? "ny kund" : "per 100 kr";
    li.innerHTML = `
      <a href="${detail.url || "#"}" target="_blank" rel="noopener noreferrer">
        <span class="shop-name">${detail.name || ""}</span>
        <span class="shop-points">${points} poäng / ${suffix}</span>
      </a>
    `;
  };

  const renderMatchList = async (uuids) => {
    listEl.innerHTML = "";
    listEl.classList.add("visible");
    const items = uuids.map((uuid) => {
      const li = document.createElement("li");
      li.innerHTML = `<a><span class="shop-name">Laddar…</span><span class="shop-points placeholder">…</span></a>`;
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
