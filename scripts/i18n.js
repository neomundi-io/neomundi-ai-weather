/**
 * NeoMundi AI Weather — i18n loader.
 *
 * Data model rule: measurement data (weather.json) never contains
 * translated text, only stable semantic ids ("clear", "variable",
 * "disrupted"). Translation happens only here, at the presentation layer.
 *
 * Usage (any page, after including this script):
 *
 *   NMi18n.init().then(() => {
 *     document.title = NMi18n.t("ui.title");
 *   });
 *
 * Adding a new language: create i18n/<code>.json with the same keys as
 * i18n/en.json, then add it to config/languages.json. No JS/HTML changes
 * required elsewhere.
 */
(function (window) {
  "use strict";

  const BASE_LANG = "en";
  let currentLang = BASE_LANG;
  let baseStrings = {};
  let activeStrings = {};
  let languagesConfig = null;

  function assetPath(rel) {
    // Every page in this repo lives at the repository root, so relative
    // paths resolve the same way everywhere. Kept as a function in case a
    // future page needs a different base.
    return rel;
  }

  function detectLang() {
    const params = new URLSearchParams(window.location.search);
    const fromQuery = params.get("lang");
    if (fromQuery) return fromQuery.toLowerCase().slice(0, 2);

    const nav = (navigator.language || navigator.userLanguage || BASE_LANG);
    return nav.toLowerCase().slice(0, 2);
  }

  function fetchJson(path) {
    return fetch(path).then(r => {
      if (!r.ok) throw new Error("Failed to load " + path);
      return r.json();
    });
  }

  async function loadLanguagesConfig() {
    if (languagesConfig) return languagesConfig;
    try {
      languagesConfig = await fetchJson(assetPath("./config/languages.json"));
    } catch (e) {
      languagesConfig = { default: BASE_LANG, available: [{ code: BASE_LANG, label: "English" }] };
    }
    return languagesConfig;
  }

  async function init(preferredLang) {
    const config = await loadLanguagesConfig();
    const available = (config.available || []).map(l => l.code);

    let lang = (preferredLang || detectLang() || config.default || BASE_LANG).toLowerCase();
    if (available.indexOf(lang) === -1) lang = config.default || BASE_LANG;

    // Always load English as the fallback layer for missing keys.
    baseStrings = await fetchJson(assetPath(`./i18n/${BASE_LANG}.json`)).catch(() => ({}));

    if (lang === BASE_LANG) {
      activeStrings = baseStrings;
    } else {
      const langStrings = await fetchJson(assetPath(`./i18n/${lang}.json`)).catch(() => ({}));
      activeStrings = Object.assign({}, baseStrings, langStrings);
    }

    currentLang = lang;
    return currentLang;
  }

  function t(key) {
    if (Object.prototype.hasOwnProperty.call(activeStrings, key)) return activeStrings[key];
    if (Object.prototype.hasOwnProperty.call(baseStrings, key)) return baseStrings[key];
    return key;
  }

  function lang() {
    return currentLang;
  }

  function getLanguagesConfig() {
    return languagesConfig;
  }

  window.NMi18n = { init, t, lang, getLanguagesConfig };
})(window);
