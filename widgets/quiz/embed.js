/**
 * NeoMundi AI Weather — "Spot the Drift" universal embed script.
 *
 * Third-party usage (Step 5):
 *
 *   <script src="https://weather.controltowerai.io/widgets/quiz/embed.js"
 *           data-mode="quiz-full"
 *           data-theme="light"
 *           data-lang="en"
 *           async></script>
 *
 * data-mode   "quiz-full" | "quiz-daily" (default: "quiz-full")
 * data-theme  "light" | "dark" (optional — omit to let the loaded page fall
 *             back to its own default, same as every other AI Weather widget)
 * data-lang   any of the 13 supported codes (optional — omit to let
 *             NMi18n's own browser-detection decide, same convention as
 *             every other widget)
 *
 * This is a NEW pattern for this repo — every existing widget
 * (weather-bar-*.html, provider-widget.html, ...) is embedded as a plain
 * hand-written <iframe> with a fixed height (see integration_EN.md).
 * That works there because their content height is fixed per format. The
 * quiz's height genuinely varies (question length, RÉAGI grid vs. not,
 * variable-length real response text in quiz-daily) enough that a fixed
 * height would either clip content or waste space, so this script injects
 * the iframe itself and auto-resizes it via postMessage — the counterpart
 * to quiz-engine.js's reportHeight(), which every quiz screen calls on
 * render and on window resize.
 *
 * A plain hand-written <iframe> (matching every other widget's embed
 * style) is also documented separately for embedders who don't want an
 * extra script tag — see the copy-paste snippets shared alongside this
 * file. Both point at the same two pages; this script is purely a
 * convenience wrapper, not a requirement.
 */
(function (window, document) {
  "use strict";

  // Absolute — this script runs on THIRD-PARTY pages, so a relative path
  // would resolve against the host page's own origin, not ours.
  var BASE_URL = "https://weather.controltowerai.io/";

  var PAGE_BY_MODE = {
    "quiz-full": "widgets/quiz/quiz-full.html",
    "quiz-daily": "widgets/quiz/quiz-daily.html",
  };

  var DEFAULT_HEIGHT = 420; // sensible pre-first-resize height, avoids a 0px flash

  function buildSrc(scriptEl) {
    var mode = scriptEl.getAttribute("data-mode") || "quiz-full";
    var page = PAGE_BY_MODE[mode] || PAGE_BY_MODE["quiz-full"];

    var params = new URLSearchParams();
    var theme = scriptEl.getAttribute("data-theme");
    var lang = scriptEl.getAttribute("data-lang");
    if (theme) params.set("theme", theme);
    if (lang) params.set("lang", lang);

    var query = params.toString();
    return BASE_URL + page + (query ? "?" + query : "");
  }

  function init(scriptEl) {
    var iframe = document.createElement("iframe");
    iframe.src = buildSrc(scriptEl);
    iframe.title = "NeoMundi AI Weather — Spot the Drift";
    iframe.loading = "lazy";
    iframe.style.width = "100%";
    iframe.style.border = "none";
    iframe.style.display = "block";
    iframe.height = String(DEFAULT_HEIGHT);
    iframe.style.height = DEFAULT_HEIGHT + "px";

    scriptEl.parentNode.insertBefore(iframe, scriptEl.nextSibling);

    // Scoped to THIS iframe instance (via event.source) so multiple quiz
    // embeds on the same host page each resize independently instead of
    // cross-talking.
    window.addEventListener("message", function (event) {
      if (event.source !== iframe.contentWindow) return;
      if (!event.data || event.data.type !== "nm-quiz-resize") return;
      var height = parseInt(event.data.height, 10);
      if (!isFinite(height) || height <= 0) return;
      iframe.style.height = height + "px";
    });
  }

  // document.currentScript is correctly scoped to the executing <script>
  // element at call time — including for async scripts — as long as init()
  // runs synchronously within this IIFE (it does).
  var thisScript = document.currentScript;
  if (thisScript) {
    init(thisScript);
  }
})(window, document);
