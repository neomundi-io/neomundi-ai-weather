/**
 * NeoMundi AI Weather — theme loader.
 *
 * Themes only ever redefine --nm-bg / --nm-text / --nm-border / --nm-muted /
 * --nm-card-bg (see styles/themes.css). Condition colors (--nm-clear,
 * --nm-variable, --nm-disrupted) are defined once in :root and never
 * change between themes — the meaning of a color must stay constant
 * regardless of which partner is embedding the widget.
 */
(function (window) {
  "use strict";

  const AVAILABLE = ["light", "dark", "slate", "warm", "transparent"];
  const DEFAULT_THEME = "light";

  function detectTheme() {
    const params = new URLSearchParams(window.location.search);
    const requested = (params.get("theme") || "").toLowerCase();
    return AVAILABLE.indexOf(requested) !== -1 ? requested : DEFAULT_THEME;
  }

  function init() {
    const theme = detectTheme();
    document.documentElement.setAttribute("data-theme", theme);
    return theme;
  }

  window.NMThemes = { init, available: AVAILABLE, default: DEFAULT_THEME };
})(window);
