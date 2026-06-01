// EB Finder — toolbar popup.
//
// Shows the partner status for the active tab (direct match, or the list of
// partners the content script spotted on a Google results page) and the
// "log in & earn" CTA. Shared data + the i18n helper come from the `EB`
// namespace (shared.js, loaded before this file — see popup.html). UI strings
// live in _locales/<lang>/messages.json (standard WebExtension i18n).

(async function () {
  const api = globalThis.browser || globalThis.chrome;
  const {
    t,
    formatPoints,
    fetchShopMap,
    fetchShopDetail,
    getShopMatchId,
    storePendingReturn,
  } = globalThis.EB;

  const statusEl = document.getElementById("status");
  const ctaEl = document.getElementById("cta");
  const listEl = document.getElementById("match-list");

  // Localize the static popup chrome (HTML ships with English defaults).
  // The browser-resolved UI locale (matched against _locales) drives <html lang>.
  document.documentElement.lang = api.i18n.getUILanguage();
  const statusBody = statusEl.querySelector(".status-body");
  if (statusBody) statusBody.textContent = t("searching");
  ctaEl.textContent = t("cta");
  const creditEl = document.getElementById("credit");
  if (creditEl) {
    creditEl.innerHTML =
      t("creditPrefix") +
      ' <a href="https://www.brine.co" target="_blank" rel="noopener noreferrer">Brine AB</a>';
  }

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

  // Match-list row = shadcn Item: media (EB glyph) · content (name + suffix) · actions (points).
  const renderMatchItem = (li, detail) => {
    if (!detail) {
      li.innerHTML = `<div class="item"><span class="item-media">${ebGlyph(15)}</span><span class="item-content"><div class="item-title">${t("unknownShop")}</div></span></div>`;
      return;
    }
    const points = formatPoints(detail.points || detail.cashback || 0);
    const suffix = t(detail.commission_type === "fixed" ? "suffixFixed" : "suffixVariable");
    li.innerHTML = `
      <a href="${detail.url || "#"}" target="_blank" rel="noopener noreferrer">
        <div class="item">
          <span class="item-media">${ebGlyph(15)}</span>
          <span class="item-content">
            <div class="item-title">${detail.name || ""}</div>
            <div class="item-desc">${suffix}</div>
          </span>
          <span class="item-actions">${t("pointsShort", [points])}</span>
        </div>
      </a>
    `;
  };

  const renderMatchList = async (uuids) => {
    listEl.innerHTML = "";
    listEl.classList.add("visible");
    const items = uuids.map((uuid) => {
      const li = document.createElement("li");
      li.innerHTML = `<div class="item"><span class="item-media">${ebGlyph(15)}</span><span class="item-content"><div class="item-title">${t("loading")}</div></span><span class="item-actions placeholder">…</span></div>`;
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
    setStatus(t("noActiveTab"), "no-match");
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
      setStatus(t("googleNoMatch"), "no-match");
      return;
    }
    setStatus(t("googleMatch", [String(matches.length)]), "match");
    await renderMatchList(matches);
    return;
  }

  const shops = await fetchShopMap();
  if (!shops) {
    setStatus(t("listFetchError"), "no-match");
    return;
  }

  const matchedId = getShopMatchId(tab.url, shops);
  if (!matchedId) {
    setStatus(t("notPartner"), "no-match");
    return;
  }

  const detail = await fetchShopDetail(matchedId);
  if (!detail) {
    setStatus(t("partnerFallback"), "match");
    return;
  }

  const points = formatPoints(detail.points || detail.cashback || 0);
  const suffix = t(detail.commission_type === "fixed" ? "suffixFixed" : "suffixVariable");
  setStatus(t("partner", [detail.name, points, suffix]), "match");
  if (detail.url) {
    ctaEl.href = detail.url;
    ctaEl.style.display = "block";
    ctaEl.addEventListener("click", () => {
      // Fire-and-forget so the browser's default new-tab navigation keeps the user-gesture.
      storePendingReturn(tab.url, matchedId);
    });
  }
})();
