
(function () {
  var LANGS = [
    { code: "en", label: "English" }, { code: "fr", label: "Français" }, { code: "de", label: "Deutsch" },
    { code: "es", label: "Español" }, { code: "it", label: "Italiano" }, { code: "pt", label: "Português" },
    { code: "nl", label: "Nederlands" }, { code: "zh", label: "简体中文" }, { code: "ja", label: "日本語" },
    { code: "ko", label: "한국어" }, { code: "hi", label: "हिन्दी" }, { code: "ar", label: "العربية" }, { code: "ru", label: "Русский" }
  ];
  var COPY_LANGS = ["en", "fr"];
  var langButton = document.getElementById("lang-button");
  var langMenu = document.getElementById("lang-menu");
  langMenu.innerHTML = LANGS.map(function (l) {
    return '<button class="lang-option' + (l.code === "en" ? " active" : "") + '" data-lang="' + l.code + '" type="button">' + l.label + "</button>";
  }).join("");
  function applyCopy(lang) {
    var key = COPY_LANGS.indexOf(lang) !== -1 ? lang : "en";
    document.querySelectorAll("[data-" + key + "]").forEach(function (el) { el.textContent = el.getAttribute("data-" + key); });
  }
  function selectLang(lang) {
    langButton.textContent = lang.toUpperCase() + " ▾";
    langMenu.querySelectorAll(".lang-option").forEach(function (opt) { opt.classList.toggle("active", opt.getAttribute("data-lang") === lang); });
    applyCopy(lang);
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
  var navToggle = document.getElementById("nav-toggle");
  var mobileNav = document.getElementById("mobile-nav");
  navToggle.addEventListener("click", function () { mobileNav.classList.toggle("open"); });
  mobileNav.querySelectorAll("a").forEach(function (a) { a.addEventListener("click", function () { mobileNav.classList.remove("open"); }); });

  function formatUtc(iso) {
    var d = new Date(iso);
    var pad = function (n) { return String(n).padStart(2, "0"); };
    return pad(d.getUTCHours()) + ":" + pad(d.getUTCMinutes()) + " UTC";
  }
  fetch("@@RUNTIME@@/weather.json").then(function (r) { return r.json(); }).then(function (data) {
    var ps = data.panel_summary || {};
    if (typeof ps.panel_coverage === "number") document.getElementById("stat-coverage").textContent = Math.round(ps.panel_coverage * 1000) / 10 + "%";
    var measuredAt = ps.last_measurement_at || data.generated_at;
    if (measuredAt) document.getElementById("stat-measured-at").textContent = formatUtc(measuredAt);
  }).catch(function () {});
  fetch("@@RUNTIME@@/data/capsule-index.json").then(function (r) { return r.json(); }).then(function (data) {
    var n = (data.capsules || []).length;
    if (n) document.getElementById("stat-days").textContent = n;
  }).catch(function () {});
})();
