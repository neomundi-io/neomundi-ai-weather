/**
 * NeoMundi AI Weather — i18n loader.
 *
 * Presentation rule:
 * - Measurement data stays language-neutral.
 * - Translation happens only in the presentation layer.
 * - English is always the fallback language.
 * - Text direction is controlled by config/languages.json.
 *
 * Adding a new language:
 * 1. create i18n/<code>.json
 * 2. add it to config/languages.json
 * 3. optionally set "direction": "rtl"
 *
 * No other JS or HTML change should be required.
 */
(function (window) {
  "use strict";

  const BASE_LANG = "en";

  let currentLang = BASE_LANG;
  let currentDirection = "ltr";

  let baseStrings = {};
  let activeStrings = {};
  let languagesConfig = null;

  function assetPath(rel) {
    return rel;
  }

  function normalizeLang(value) {
    if (!value) return null;

    return String(value)
      .trim()
      .toLowerCase()
      .replace("_", "-")
      .split("-")[0];
  }

  function detectLang() {
    const params = new URLSearchParams(window.location.search);

    const fromQuery = normalizeLang(params.get("lang"));
    if (fromQuery) return fromQuery;

    const nav =
      navigator.language ||
      navigator.userLanguage ||
      BASE_LANG;

    return normalizeLang(nav) || BASE_LANG;
  }

  function fetchJson(path) {
    return fetch(path).then(r => {
      if (!r.ok) {
        throw new Error("Failed to load " + path);
      }

      return r.json();
    });
  }

  async function loadLanguagesConfig() {
    if (languagesConfig) {
      return languagesConfig;
    }

    try {
      languagesConfig = await fetchJson(
        assetPath("./config/languages.json")
      );
    } catch (e) {
      languagesConfig = {
        default: BASE_LANG,
        available: [
          {
            code: BASE_LANG,
            label: "English",
            direction: "ltr"
          }
        ]
      };
    }

    return languagesConfig;
  }

  function getLanguageMeta(code) {
    if (!languagesConfig) return null;

    const normalized = normalizeLang(code);

    return (languagesConfig.available || []).find(
      item => normalizeLang(item.code) === normalized
    ) || null;
  }

  function applyDocumentLanguage(lang) {
    const meta = getLanguageMeta(lang);

    const direction =
      meta && meta.direction === "rtl"
        ? "rtl"
        : "ltr";

    currentDirection = direction;

    document.documentElement.setAttribute("lang", lang);
    document.documentElement.setAttribute("dir", direction);

    document.body?.setAttribute("dir", direction);
  }

  async function init(preferredLang) {
    const config = await loadLanguagesConfig();

    const available = (config.available || [])
      .map(item => normalizeLang(item.code))
      .filter(Boolean);

    const defaultLang =
      normalizeLang(config.default) ||
      BASE_LANG;

    let lang =
      normalizeLang(preferredLang) ||
      detectLang() ||
      defaultLang;

    if (available.indexOf(lang) === -1) {
      lang = available.indexOf(defaultLang) !== -1
        ? defaultLang
        : BASE_LANG;
    }

    /*
     * English is always loaded first as the canonical fallback layer.
     */
    baseStrings = await fetchJson(
      assetPath(`./i18n/${BASE_LANG}.json`)
    ).catch(() => ({}));

    if (lang === BASE_LANG) {
      activeStrings = baseStrings;
    } else {
      const langStrings = await fetchJson(
        assetPath(`./i18n/${lang}.json`)
      ).catch(() => ({}));

      /*
       * Any missing translation automatically falls back to English.
       */
      activeStrings = Object.assign(
        {},
        baseStrings,
        langStrings
      );
    }

    currentLang = lang;

    applyDocumentLanguage(currentLang);

    return currentLang;
  }

  function t(key) {
    if (
      Object.prototype.hasOwnProperty.call(
        activeStrings,
        key
      )
    ) {
      return activeStrings[key];
    }

    if (
      Object.prototype.hasOwnProperty.call(
        baseStrings,
        key
      )
    ) {
      return baseStrings[key];
    }

    return key;
  }

  function lang() {
    return currentLang;
  }

  function direction() {
    return currentDirection;
  }

  function isRTL() {
    return currentDirection === "rtl";
  }

  function getLanguagesConfig() {
    return languagesConfig;
  }

  window.NMi18n = {
    init,
    t,
    lang,
    direction,
    isRTL,
    getLanguagesConfig
  };

})(window);
