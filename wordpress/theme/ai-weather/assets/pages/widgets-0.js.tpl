
(function () {
  /* ============== Site copy toggle (existing site-wide pattern, extended to ES) ============== */
  var SITE_LANGS = [
    { code: "en", label: "English" }, { code: "fr", label: "Français" }, { code: "de", label: "Deutsch" },
    { code: "es", label: "Español" }, { code: "it", label: "Italiano" }, { code: "pt", label: "Português" },
    { code: "nl", label: "Nederlands" }, { code: "zh", label: "简体中文" }, { code: "ja", label: "日本語" },
    { code: "ko", label: "한국어" }, { code: "hi", label: "हिन्दी" }, { code: "ar", label: "العربية" }, { code: "ru", label: "Русский" }
  ];
  var COPY_LANGS = ["en", "fr", "es"];
  var current = "en";

  var langButton = document.getElementById("lang-button");
  var langMenu = document.getElementById("lang-menu");

  langMenu.innerHTML = SITE_LANGS.map(function (l) {
    return '<button class="lang-option' + (l.code === "en" ? " active" : "") + '" data-lang="' + l.code + '" type="button">' + l.label + "</button>";
  }).join("");

  function applyCopy(lang) {
    var key = COPY_LANGS.indexOf(lang) !== -1 ? lang : "en";
    document.querySelectorAll("[data-" + key + "]").forEach(function (el) { el.textContent = el.getAttribute("data-" + key); });
    document.documentElement.lang = key;
  }
  function selectSiteLang(lang) {
    current = lang;
    langButton.textContent = lang.toUpperCase() + " ▾";
    langMenu.querySelectorAll(".lang-option").forEach(function (opt) { opt.classList.toggle("active", opt.getAttribute("data-lang") === lang); });
    applyCopy(lang);
    langMenu.classList.remove("open");
    langButton.setAttribute("aria-expanded", "false");
    render(); // preview label + copy button + format/theme card text follow the site language too
  }
  langButton.addEventListener("click", function () {
    var willOpen = !langMenu.classList.contains("open");
    langMenu.classList.toggle("open", willOpen);
    langButton.setAttribute("aria-expanded", String(willOpen));
  });
  langMenu.addEventListener("click", function (e) {
    var btn = e.target.closest(".lang-option");
    if (btn) selectSiteLang(btn.getAttribute("data-lang"));
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

  /* ============== Configurator data ============== */
  var FORMATS = [
    { id: "bar-2x6", base: "@@RUNTIME@@/weather-bar-2x6.html", w: 760, h: 220, orientation: "h", systems: 12,
      name: { en: "Horizontal, 12 systems", fr: "Horizontal, 12 systèmes", es: "Horizontal, 12 sistemas" },
      ctx: { en: "Ideal for a site header or a top banner.", fr: "Idéal pour un en-tête de site ou un bandeau supérieur.", es: "Ideal para la cabecera de un sitio o un banner superior." } },
    { id: "sidebar-us5", base: "@@RUNTIME@@/weather-sidebar-us5.html", w: 320, h: 390, orientation: "v", systems: 5,
      name: { en: "Vertical US, 5 systems", fr: "Vertical US, 5 systèmes", es: "Vertical EE. UU., 5 sistemas" },
      ctx: { en: "A compact panel of US-focused systems, for a sidebar.", fr: "Panneau compact des systèmes utilisés aux États-Unis, pour une barre latérale.", es: "Un panel compacto de sistemas de EE. UU., para una barra lateral." } },
    { id: "sidebar-5", base: "@@RUNTIME@@/weather-sidebar-5.html", w: 320, h: 390, orientation: "v", systems: 5,
      name: { en: "Vertical, 5 systems", fr: "Vertical, 5 systèmes", es: "Vertical, 5 sistemas" },
      ctx: { en: "A tight selection of 5 systems, for a light side column.", fr: "Une sélection resserrée de 5 systèmes, pour une colonne latérale légère.", es: "Una selección reducida de 5 sistemas, para una columna lateral ligera." } },
    { id: "sidebar-8", base: "@@RUNTIME@@/weather-sidebar-8.html", w: 320, h: 580, orientation: "v", systems: 8,
      name: { en: "Vertical, 8 systems", fr: "Vertical, 8 systèmes", es: "Vertical, 8 sistemas" },
      ctx: { en: "Eight systems, for a fuller sidebar.", fr: "Huit systèmes, pour une barre latérale plus complète.", es: "Ocho sistemas, para una barra lateral más completa." } },
    { id: "sidebar-12-v2", base: "@@RUNTIME@@/weather-sidebar-12-v2.html", w: 300, h: 780, orientation: "v", systems: 12,
      name: { en: "Vertical wide, 12 systems", fr: "Vertical large, 12 systèmes", es: "Vertical ancho, 12 sistemas" },
      ctx: { en: "All twelve panel systems, in a wide column.", fr: "Les douze systèmes du panel, dans une colonne large.", es: "Los doce sistemas del panel, en una columna ancha." } },
    { id: "sidebar-12-220", base: "@@RUNTIME@@/weather-sidebar-12-220.html", w: 220, h: 780, orientation: "v", systems: 12,
      name: { en: "Vertical narrow, 12 systems", fr: "Vertical étroit, 12 systèmes", es: "Vertical estrecho, 12 sistemas" },
      ctx: { en: "All twelve panel systems, in a narrow column for tight spaces.", fr: "Les douze systèmes du panel, dans une colonne étroite pour les espaces réduits.", es: "Los doce sistemas del panel, en una columna estrecha para espacios reducidos." } }
  ];
  var THEMES = [
    { id: "light", label: { en: "Light", fr: "Clair", es: "Claro" } },
    { id: "dark", label: { en: "Dark", fr: "Sombre", es: "Oscuro" } },
    { id: "slate", label: { en: "Slate", fr: "Ardoise", es: "Pizarra" } },
    { id: "warm", label: { en: "Warm", fr: "Chaud", es: "Cálido" } },
    { id: "transparent", label: { en: "Transparent", fr: "Transparent", es: "Transparente" } }
  ];
  var WIDGET_LANGS = [
    { code: "en", label: "English" }, { code: "fr", label: "Français" }, { code: "de", label: "Deutsch" },
    { code: "it", label: "Italiano" }, { code: "es", label: "Español" }, { code: "ru", label: "Русский" },
    { code: "pt", label: "Português" }, { code: "zh", label: "中文" }, { code: "ja", label: "日本語" },
    { code: "nl", label: "Nederlands" }, { code: "ko", label: "한국어" }, { code: "ar", label: "العربية" },
    { code: "hi", label: "हिन्दी" }
  ];
  var ORIENTATION_LABEL = { h: { en: "Horizontal", fr: "Horizontal", es: "Horizontal" }, v: { en: "Vertical", fr: "Vertical", es: "Vertical" } };
  var SYSTEMS_LABEL = { en: "systems", fr: "systèmes", es: "sistemas" };
  var STR = {
    en: { copySuccess: "Code copied", copyError: "Copy failed — select and copy the code manually." },
    fr: { copySuccess: "Code copié", copyError: "La copie a échoué — sélectionnez et copiez le code manuellement." },
    es: { copySuccess: "Código copiado", copyError: "No se pudo copiar — selecciona y copia el código manualmente." }
  };
  function copy(key) { return function (l) { return l[key] || l.en; }; }

  var state = { format: FORMATS[0].id, theme: "light", lang: "en" };

  /* ---- Format radiogroup ---- */
  var formatGroup = document.getElementById("format-group");
  formatGroup.innerHTML = FORMATS.map(function (f) {
    var maxSide = 40, scale = maxSide / Math.max(f.w, f.h);
    var tw = Math.round(f.w * scale), th = Math.round(f.h * scale);
    return '<button type="button" class="format-card" role="radio" aria-checked="' + (f.id === state.format) + '" tabindex="' + (f.id === state.format ? "0" : "-1") + '" data-format="' + f.id + '">' +
      '<span class="format-thumb"><i style="width:' + tw + 'px;height:' + th + 'px"></i></span>' +
      '<span class="format-info">' +
        '<span class="fname" data-en="' + f.name.en + '" data-fr="' + f.name.fr + '" data-es="' + f.name.es + '">' + f.name.en + '</span>' +
        '<span class="fmeta"><b data-en="' + ORIENTATION_LABEL[f.orientation].en + '" data-fr="' + ORIENTATION_LABEL[f.orientation].fr + '" data-es="' + ORIENTATION_LABEL[f.orientation].es + '">' + ORIENTATION_LABEL[f.orientation].en + '</b><span>' + f.systems + ' <span data-en="' + SYSTEMS_LABEL.en + '" data-fr="' + SYSTEMS_LABEL.fr + '" data-es="' + SYSTEMS_LABEL.es + '">' + SYSTEMS_LABEL.en + '</span></span><span>' + f.w + ' × ' + f.h + ' px</span></span>' +
        '<span class="fcontext" data-en="' + f.ctx.en + '" data-fr="' + f.ctx.fr + '" data-es="' + f.ctx.es + '">' + f.ctx.en + '</span>' +
      '</span>' +
    '</button>';
  }).join("");

  function selectFormat(id) {
    state.format = id;
    formatGroup.querySelectorAll(".format-card").forEach(function (btn) {
      var isSel = btn.getAttribute("data-format") === id;
      btn.setAttribute("aria-checked", String(isSel));
      btn.tabIndex = isSel ? 0 : -1;
    });
    render();
  }
  wireRadioGroup(formatGroup, ".format-card", "data-format", selectFormat);

  /* ---- Theme radiogroup ---- */
  var themeGroup = document.getElementById("theme-group");
  themeGroup.innerHTML = THEMES.map(function (t) {
    return '<button type="button" class="theme-btn" role="radio" aria-checked="' + (t.id === state.theme) + '" tabindex="' + (t.id === state.theme ? "0" : "-1") + '" data-theme="' + t.id + '">' +
      '<span class="theme-swatch t-' + t.id + '"></span>' +
      '<span data-en="' + t.label.en + '" data-fr="' + t.label.fr + '" data-es="' + t.label.es + '">' + t.label.en + '</span>' +
    '</button>';
  }).join("");
  function selectTheme(id) {
    state.theme = id;
    themeGroup.querySelectorAll(".theme-btn").forEach(function (btn) {
      var isSel = btn.getAttribute("data-theme") === id;
      btn.setAttribute("aria-checked", String(isSel));
      btn.tabIndex = isSel ? 0 : -1;
    });
    render();
  }
  wireRadioGroup(themeGroup, ".theme-btn", "data-theme", selectTheme);

  function wireRadioGroup(container, itemSelector, dataAttr, onSelect) {
    container.addEventListener("click", function (e) {
      var btn = e.target.closest(itemSelector);
      if (btn) onSelect(btn.getAttribute(dataAttr));
    });
    container.addEventListener("keydown", function (e) {
      if (["ArrowRight", "ArrowDown", "ArrowLeft", "ArrowUp", "Home", "End"].indexOf(e.key) === -1) return;
      var items = Array.prototype.slice.call(container.querySelectorAll(itemSelector));
      var idx = items.indexOf(document.activeElement);
      if (idx === -1) return;
      e.preventDefault();
      var next = idx;
      if (e.key === "ArrowRight" || e.key === "ArrowDown") next = (idx + 1) % items.length;
      else if (e.key === "ArrowLeft" || e.key === "ArrowUp") next = (idx - 1 + items.length) % items.length;
      else if (e.key === "Home") next = 0;
      else if (e.key === "End") next = items.length - 1;
      items[next].focus();
      onSelect(items[next].getAttribute(dataAttr));
    });
  }

  /* ---- Widget language select ---- */
  var langSelect = document.getElementById("widget-lang");
  langSelect.innerHTML = WIDGET_LANGS.map(function (l) {
    return '<option value="' + l.code + '">' + l.code + ' — ' + l.label + '</option>';
  }).join("");
  langSelect.addEventListener("change", function () { state.lang = langSelect.value; render(); });

  /* ---- Preview + code render ---- */
  var previewShell = document.getElementById("preview-shell");
  var previewWrap = document.getElementById("preview-wrap");
  var previewIframe = document.getElementById("preview-iframe");
  var previewName = document.getElementById("preview-name");
  var previewDims = document.getElementById("preview-dims");
  var embedCodeEl = document.getElementById("embed-code");
  var copyBtn = document.getElementById("copy-btn");
  var copyStatus = document.getElementById("copy-status");
  var currentRawCode = "";
  var lastSrc = "";

  function findFormat(id) { for (var i = 0; i < FORMATS.length; i++) if (FORMATS[i].id === id) return FORMATS[i]; return FORMATS[0]; }

  function fitPreview(f) {
    var available = previewShell.clientWidth - 4;
    var scale = Math.min(1, available / f.w);
    var sw = Math.round(f.w * scale), sh = Math.round(f.h * scale);
    previewWrap.style.width = sw + "px";
    previewWrap.style.height = sh + "px";
    previewIframe.style.width = f.w + "px";
    previewIframe.style.height = f.h + "px";
    previewIframe.style.transform = "scale(" + scale + ")";
    previewIframe.style.transformOrigin = "top left";
  }

  function render() {
    var f = findFormat(state.format);
    var url = f.base + "?lang=" + state.lang + "&theme=" + state.theme;

    previewShell.className = "preview-shell bg-" + (state.theme === "dark" ? "dark" : state.theme === "transparent" ? "transparent" : "light");
    previewIframe.title = "AI Weather™: " + (f.name[current] || f.name.en) + " — live preview";
    if (url !== lastSrc) { previewIframe.src = url; lastSrc = url; }
    fitPreview(f);

    previewName.textContent = f.name[current] || f.name.en;
    previewDims.textContent = f.w + " × " + f.h + " px";

    currentRawCode = '<iframe src="' + url + '" width="' + f.w + '" height="' + f.h + '" loading="lazy" title="NeoMundi AI Weather"></iframe>';
    renderCode();
  }

  function renderCode() {
    embedCodeEl.textContent = currentRawCode;
  }

  copyBtn.addEventListener("click", function () {
    function showResult(ok) {
      var l = STR[current] || STR.en;
      copyStatus.textContent = ok ? l.copySuccess : l.copyError;
      copyStatus.classList.toggle("is-error", !ok);
      clearTimeout(showResult._t);
      showResult._t = setTimeout(function () { copyStatus.textContent = ""; copyStatus.classList.remove("is-error"); }, 3000);
    }
    function fallbackCopy() {
      try {
        var ta = document.createElement("textarea");
        ta.value = currentRawCode;
        ta.setAttribute("readonly", "");
        ta.style.position = "absolute";
        ta.style.left = "-9999px";
        document.body.appendChild(ta);
        ta.select();
        ta.setSelectionRange(0, currentRawCode.length);
        var ok = document.execCommand("copy");
        document.body.removeChild(ta);
        showResult(ok);
      } catch (e) { showResult(false); }
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(currentRawCode).then(function () { showResult(true); }).catch(fallbackCopy);
    } else {
      fallbackCopy();
    }
  });

  var resizeTimer;
  window.addEventListener("resize", function () {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function () { fitPreview(findFormat(state.format)); }, 120);
  });

  applyCopy("en");
  render();
})();
