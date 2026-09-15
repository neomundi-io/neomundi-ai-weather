
(function () {
  var LANGS = [
    { code: "en", label: "English" },
    { code: "fr", label: "Français" },
    { code: "de", label: "Deutsch" },
    { code: "es", label: "Español" },
    { code: "it", label: "Italiano" },
    { code: "pt", label: "Português" },
    { code: "nl", label: "Nederlands" },
    { code: "zh", label: "简体中文" },
    { code: "ja", label: "日本語" },
    { code: "ko", label: "한국어" },
    { code: "hi", label: "हिन्दी" },
    { code: "ar", label: "العربية" },
    { code: "ru", label: "Русский" }
  ];
  var COPY_LANGS = ["en", "fr", "es"]; // marketing copy authored so far; widgets support all 13
  var current = "en";

  var langButton = document.getElementById("lang-button");
  var langMenu = document.getElementById("lang-menu");

  langMenu.innerHTML = LANGS.map(function (l) {
    return '<button class="lang-option' + (l.code === "en" ? " active" : "") + '" data-lang="' + l.code + '" type="button">' + l.label + "</button>";
  }).join("");

  function applyCopy(lang) {
    var key = COPY_LANGS.indexOf(lang) !== -1 ? lang : "en";
    document.querySelectorAll("[data-" + key + "]").forEach(function (el) {
      el.textContent = el.getAttribute("data-" + key);
    });
    document.querySelectorAll("[data-" + key + "-placeholder]").forEach(function (el) {
      el.setAttribute("placeholder", el.getAttribute("data-" + key + "-placeholder"));
    });
  }

  function setWidgetLang(lang) {
    ["iframe-quiz-daily"].forEach(function (id) {
      var frame = document.getElementById(id);
      if (!frame) return;
      var base = frame.getAttribute("data-src");
      var url = new URL(base, window.location.href);
      var currentParams = new URL(frame.src, window.location.href).searchParams;
      currentParams.set("lang", lang);
      url.search = currentParams.toString();
      frame.src = url.toString();
    });
  }

  function selectLang(lang) {
    current = lang;
    langButton.textContent = lang.toUpperCase() + " ▾";
    langMenu.querySelectorAll(".lang-option").forEach(function (opt) {
      opt.classList.toggle("active", opt.getAttribute("data-lang") === lang);
    });
    applyCopy(lang);
    setWidgetLang(lang);
    langMenu.classList.remove("open");
    langButton.setAttribute("aria-expanded", "false");
  }

  langButton.addEventListener("click", function () {
    var willOpen = !langMenu.classList.contains("open");
    langMenu.classList.toggle("open", willOpen);
    langButton.setAttribute("aria-expanded", String(willOpen));
  });

  langMenu.addEventListener("click", function (e) {
    var btn = e.target.closest(".lang-option");
    if (btn) selectLang(btn.getAttribute("data-lang"));
  });

  document.addEventListener("click", function (e) {
    if (!document.querySelector(".lang-select").contains(e.target)) {
      langMenu.classList.remove("open");
      langButton.setAttribute("aria-expanded", "false");
    }
  });

  // Mobile nav
  var navToggle = document.getElementById("nav-toggle");
  var mobileNav = document.getElementById("mobile-nav");
  navToggle.addEventListener("click", function () {
    mobileNav.classList.toggle("open");
  });
  mobileNav.querySelectorAll("a").forEach(function (a) {
    a.addEventListener("click", function () { mobileNav.classList.remove("open"); });
  });

  // Live stats — reads the real published weather.json / capsule index.
  // Never fabricates a number: on failure, fields simply keep their
  // static fallback text already in the markup.
  function formatPct(x) {
    return Math.round(x * 1000) / 10 + "%";
  }
  function formatUtc(iso) {
    var d = new Date(iso);
    var pad = function (n) { return String(n).padStart(2, "0"); };
    return d.getUTCFullYear() + "-" + pad(d.getUTCMonth() + 1) + "-" + pad(d.getUTCDate()) +
      " " + pad(d.getUTCHours()) + ":" + pad(d.getUTCMinutes()) + " UTC";
  }

  function setText(id, value) {
    var el = document.getElementById(id);
    if (el) el.textContent = value;
  }

  fetch("@@RUNTIME@@/weather.json").then(function (r) { return r.json(); }).then(function (data) {
    var ps = data.panel_summary || {};
    if (typeof ps.systems_count === "number") {
      setText("il-systems", ps.systems_count + " systems");
    }
    if (typeof ps.panel_coverage === "number") {
      setText("il-coverage", formatPct(ps.panel_coverage));
    }
    var measuredAt = ps.last_measurement_at || data.generated_at;
    if (measuredAt) {
      setText("il-measured", formatUtc(measuredAt));
    }
  }).catch(function () {});

  fetch("@@RUNTIME@@/data/capsule-index.json").then(function (r) { return r.json(); }).then(function (data) {
    var n = (data.capsules || []).length;
    if (n) {
      setText("stat-days", n);
      setText("stat-days-2", n);
      setText("il-days", n);
    }
  }).catch(function () {});

  // Public quiz widget (widgets/quiz-public/daily.html) reports its own
  // rendered height on every state change via postMessage, using the
  // same { type: "nm-quiz-resize", height } contract as the RÉAGI-based
  // widgets/quiz/embed.js, so this listener needs no changes if that
  // widget is ever swapped for another one using the same contract.
  var quizFrame = document.getElementById("iframe-quiz-daily");
  if (quizFrame) {
    window.addEventListener("message", function (event) {
      if (event.source !== quizFrame.contentWindow) return;
      if (!event.data || event.data.type !== "nm-quiz-resize") return;
      var height = parseInt(event.data.height, 10);
      if (!isFinite(height) || height <= 0) return;
      quizFrame.style.height = height + "px";
    });
  }

  // Defensive fallback: same-origin local iframes essentially never fire
  // "error" for a valid HTML response, but a real navigation/network
  // failure (moved file, server down) does. Shown alongside the
  // always-present "open it directly" link below the quiz frame.
  (function () {
    var frame = document.getElementById("iframe-quiz-daily");
    var fallback = document.getElementById("quiz-fallback");
    if (!frame || !fallback) return;
    frame.addEventListener("error", function () {
      fallback.classList.add("is-visible");
    });
  })();
})();
