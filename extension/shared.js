// EB Finder — shared data layer.
//
// The LoyaltyKey shop client, storage cache, URL matching and small helpers
// used by BOTH the content script and the popup. Loaded before content.js
// (manifest content_scripts) and before popup.js (popup.html); attaches its
// exports to the shared global `EB` namespace.

(function () {
  const EB = (globalThis.EB = globalThis.EB || {});
  const api = globalThis.browser || globalThis.chrome;

  // i18n — thin wrapper over the standard WebExtension i18n API. The browser
  // selects the locale from _locales/ against the manifest default_locale, so
  // there is no manual language detection here. `subs` is an array of
  // positional substitutions ($1, $2, … in messages.json).
  const t = (key, subs) => api.i18n.getMessage(key, subs);

  const API_BASE = "https://onlineshopping.loyaltykey.com";
  const CHANNEL = "sas/sv-SE";
  const CACHE_TTL_MS = 60 * 60 * 1000;
  const PENDING_KEY_PREFIX = "pending_return_";

  // --- storage cache -------------------------------------------------------
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

  // --- LoyaltyKey client ---------------------------------------------------
  const fetchJson = async (url) => {
    try {
      const res = await fetch(url, { credentials: "omit" });
      if (!res.ok) return null;
      return await res.json();
    } catch (e) {
      return null;
    }
  };

  // Map of "normalized shop url" → uuid for the whole channel.
  const fetchShopMap = async () => {
    const cacheKey = `list_${CHANNEL}`;
    const cached = await getCache(cacheKey);
    if (cached) return cached;
    const json = await fetchJson(`${API_BASE}/api/browser-extension/${CHANNEL}/shops`);
    if (json && typeof json === "object") await setCache(cacheKey, json);
    return json;
  };

  // Per-shop detail (name, points/cashback, commission_type, click-through url).
  const fetchShopDetail = async (uuid) => {
    const cacheKey = `detail_${uuid}_${CHANNEL}`;
    const cached = await getCache(cacheKey);
    if (cached) return cached;
    const json = await fetchJson(`${API_BASE}/api/browser-extension/${CHANNEL}/shops/${uuid}`);
    const data = json && json.data ? json.data : null;
    if (data) await setCache(cacheKey, data);
    return data;
  };

  // --- URL matching --------------------------------------------------------
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

  // --- helpers -------------------------------------------------------------
  // 12345 → "12 345" (thin-grouped, locale-neutral).
  const formatPoints = (value) => {
    const n = parseInt(value, 10) || 0;
    return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ");
  };

  // Remember where the user was before the SAS click-through, so the content
  // script can bounce them back after the affiliate redirect (keyed by uuid).
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

  EB.t = t;
  EB.fetchShopMap = fetchShopMap;
  EB.fetchShopDetail = fetchShopDetail;
  EB.normalizeUrl = normalizeUrl;
  EB.getShopMatchId = getShopMatchId;
  EB.formatPoints = formatPoints;
  EB.storePendingReturn = storePendingReturn;
  EB.PENDING_KEY_PREFIX = PENDING_KEY_PREFIX;
})();
