
(function () {
  // ---------------- Site chrome (nav / lang / mobile) — unchanged mechanism ----------------
  var LANGS = [
    { code: "en", label: "English" }, { code: "fr", label: "Français" }, { code: "de", label: "Deutsch" },
    { code: "es", label: "Español" }, { code: "it", label: "Italiano" }, { code: "pt", label: "Português" },
    { code: "nl", label: "Nederlands" }, { code: "zh", label: "简体中文" }, { code: "ja", label: "日本語" },
    { code: "ko", label: "한국어" }, { code: "hi", label: "हिन्दी" }, { code: "ar", label: "العربية" }, { code: "ru", label: "Русский" }
  ];
  var COPY_LANGS = ["en", "fr"];
  var current = "en";
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
    current = lang;
    langButton.textContent = lang.toUpperCase() + " ▾";
    langMenu.querySelectorAll(".lang-option").forEach(function (opt) { opt.classList.toggle("active", opt.getAttribute("data-lang") === lang); });
    applyCopy(lang);
    setWidgetLang(lang);
    renderHistory(lang);
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

  function setWidgetLang(lang) {
    var frame = document.getElementById("iframe-quiz-daily");
    if (!frame) return;
    var base = frame.getAttribute("data-src");
    var url = new URL(base, window.location.href);
    var currentParams = new URL(frame.src, window.location.href).searchParams;
    currentParams.set("lang", lang);
    url.search = currentParams.toString();
    frame.src = url.toString();
  }

  var quizFrame = document.getElementById("iframe-quiz-daily");
  if (quizFrame) {
    window.addEventListener("message", function (event) {
      if (event.source !== quizFrame.contentWindow) return;
      if (!event.data || event.data.type !== "nm-quiz-resize") return;
      if (typeof event.data.height === "number") quizFrame.style.height = event.data.height + "px";
    });
    quizFrame.addEventListener("error", function () {
      var fb = document.getElementById("quiz-fallback");
      if (fb) fb.style.display = "block";
    });
  }

  // ---------------- Condition helpers (shared by wall + history) ----------------
  var CONDITION_COLOR = { clear: "#22c55e", watch: "#facc15", unsettled: "#fb923c", alert: "#b91c1c" };
  var CONDITION_SEVERITY = { clear: 0, watch: 1, unsettled: 2, alert: 3 };
  function pad2(n) { return String(n).padStart(2, "0"); }
  function formatUtcParts(iso) {
    var d = new Date(iso);
    return { date: d, hh: pad2(d.getUTCHours()), mm: pad2(d.getUTCMinutes()) };
  }

  // ---------------- Hero + native wall ----------------
  function renderHeroAndWall(data, panelSystems, historyMap) {
    var ps = data.panel_summary || {};
    var badge = document.getElementById("hero-state-badge");
    var cond = data.global_condition;
    var STATE_LABEL = {
      en: { clear: "Normal", watch: "Watch", unsettled: "Warning", alert: "Critical" },
      fr: { clear: "Normal", watch: "Vigilance", unsettled: "Alerte", alert: "Critique" }
    };
    if (cond && CONDITION_COLOR[cond]) {
      badge.hidden = false;
      badge.className = "state-badge st-" + cond;
      badge.innerHTML = '<span class="dot" aria-hidden="true"></span><span></span>';
      badge.dataset.stateEn = STATE_LABEL.en[cond];
      badge.dataset.stateFr = STATE_LABEL.fr[cond];
      badge.querySelector("span:last-child").textContent = STATE_LABEL[current] ? STATE_LABEL[current][cond] : STATE_LABEL.en[cond];
    }

    if (typeof ps.systems_count === "number") document.getElementById("stat-systems").textContent = ps.systems_count;
    if (typeof ps.panel_coverage === "number") document.getElementById("stat-coverage").textContent = Math.round(ps.panel_coverage * 1000) / 10 + "%";
    var measuredAt = ps.last_measurement_at || data.generated_at;
    if (measuredAt) {
      var parts = formatUtcParts(measuredAt);
      document.getElementById("stat-measured").textContent = parts.hh + ":" + parts.mm;
    }
    if (typeof ps.total_observations === "number") {
      document.getElementById("stat-runs-block").hidden = false;
      document.getElementById("stat-runs").textContent = ps.total_observations;
    }

    var wall = document.getElementById("wall-native");
    wall.innerHTML = "";
    if (!panelSystems.length) {
      wall.innerHTML = '<p class="wall-state-msg" data-en="No systems in the observed panel yet." data-fr="Aucun système dans le panel observé pour le moment.">No systems in the observed panel yet.</p>';
      applyCopy(current);
      return;
    }
    panelSystems.forEach(function (system) {
      var identity = NMData.getPublicIdentity(system);
      var history = NMData.getSystemHistory(historyMap, system.id);
      var card = document.createElement("div");
      card.className = "wcard is-" + system.condition;
      card.setAttribute("role", "listitem");
      card.setAttribute("aria-label", identity.label + " — " + system.condition);
      card.innerHTML =
        '<div class="wcard-top"><span class="wcard-dot" aria-hidden="true"></span><span class="wcard-name"></span></div>' +
        buildSparklineSvg(history);
      card.querySelector(".wcard-name").textContent = identity.label;
      wall.appendChild(card);
    });

    // Question of the day (moved here, right after the wall — never left for later).
    var daily = (data.probe_contract && data.probe_contract.daily) || {};
    var originalQuestion = daily.question;
    var qodBlock = document.getElementById("qod-block");
    if (originalQuestion) {
      qodBlock.hidden = false;
      var translations = daily.question_translations || {};
      var translated = current === "en" ? originalQuestion : (translations[current] || originalQuestion);
      document.getElementById("qod-text").textContent = histDisplayQuestion(translated);
      var hasDistinct = current !== "en" && translated && translated !== originalQuestion;
      var originalBlock = document.getElementById("qod-original");
      originalBlock.hidden = !hasDistinct;
      if (hasDistinct) document.getElementById("qod-original-text").textContent = histDisplayQuestion(originalQuestion);
    }
  }

  function buildSparklineSvg(points) {
    if (!points || !points.length) return "";
    var W = 112, H = 26, PAD_X = 4, PAD_Y = 4;
    var n = points.length;
    var stepX = n > 1 ? (W - PAD_X * 2) / (n - 1) : 0;
    var coords = points.map(function (p, i) {
      var sev = CONDITION_SEVERITY[p.condition];
      return {
        x: PAD_X + stepX * i,
        y: sev === undefined ? H / 2 : PAD_Y + (sev / 3) * (H - PAD_Y * 2),
        condition: p.condition, valid: sev !== undefined
      };
    });
    var segments = [], cur = [];
    coords.forEach(function (c) {
      if (c.valid) cur.push(c);
      else { if (cur.length > 1) segments.push(cur); cur = []; }
    });
    if (cur.length > 1) segments.push(cur);
    var polylines = segments.map(function (seg) {
      var pts = seg.map(function (c) { return c.x.toFixed(1) + "," + c.y.toFixed(1); }).join(" ");
      return '<polyline points="' + pts + '" fill="none" stroke="var(--on-navy-faint)" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" opacity="0.55" />';
    }).join("");
    var dots = coords.map(function (c) {
      if (c.valid) return '<circle cx="' + c.x.toFixed(1) + '" cy="' + c.y.toFixed(1) + '" r="2.3" fill="' + (CONDITION_COLOR[c.condition] || "var(--on-navy-faint)") + '" />';
      return '<circle cx="' + c.x.toFixed(1) + '" cy="' + c.y.toFixed(1) + '" r="2.3" fill="var(--on-navy-faint)" />';
    }).join("");
    return '<svg class="wcard-spark" viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none" aria-hidden="true">' + polylines + dots + "</svg>";
  }

  // ---------------- 15-day history: own minimal i18n, no shared side effects ----------------
  var HIST_WORDS = {
    en: ['Play', 'Pause', 'Previous day', 'Next day', 'Insufficient data', 'No observation', 'Unrecognized or ambiguous observation', 'Scroll horizontally ↔ · Select a cell to inspect its measurement.', 'Automatic playback disabled: reduced motion.', 'No capsules available.', 'History unavailable. Reload to retry.', 'Question unavailable in this capsule.', 'System', 'Model', 'Coverage', 'Observations', 'Loading history…'],
    fr: ['Lecture', 'Pause', 'Jour précédent', 'Jour suivant', 'Données insuffisantes', 'Observation absente', 'Observation non reconnue ou ambiguë', 'Défilement horizontal ↔ · Sélectionnez une cellule pour consulter sa mesure.', 'Lecture automatique désactivée : mouvements réduits.', 'Aucune capsule disponible.', 'Historique indisponible. Rechargez pour réessayer.', 'Question absente de cette capsule.', 'Système', 'Modèle', 'Couverture', 'Observations', 'Chargement de l’historique…'],
    de: ['Wiedergabe', 'Pause', 'Vorheriger Tag', 'Nächster Tag', 'Unzureichende Daten', 'Keine Beobachtung', 'Unbekannte oder mehrdeutige Beobachtung', 'Horizontal scrollen ↔ · Zelle auswählen, um die Messung zu prüfen.', 'Automatische Wiedergabe deaktiviert: reduzierte Bewegung.', 'Keine Kapseln verfügbar.', 'Verlauf nicht verfügbar. Zum Wiederholen neu laden.', 'Frage in dieser Kapsel nicht verfügbar.', 'System', 'Modell', 'Abdeckung', 'Beobachtungen', 'Verlauf wird geladen…'],
    es: ['Reproducir', 'Pausa', 'Día anterior', 'Día siguiente', 'Datos insuficientes', 'Sin observación', 'Observación desconocida o ambigua', 'Desplazamiento horizontal ↔ · Seleccione una celda para consultar su medición.', 'Reproducción automática desactivada: movimiento reducido.', 'No hay cápsulas disponibles.', 'Historial no disponible. Recargue para reintentar.', 'Pregunta no disponible en esta cápsula.', 'Sistema', 'Modelo', 'Cobertura', 'Observaciones', 'Cargando historial…'],
    it: ['Riproduci', 'Pausa', 'Giorno precedente', 'Giorno successivo', 'Dati insufficienti', 'Nessuna osservazione', 'Osservazione sconosciuta o ambigua', 'Scorri orizzontalmente ↔ · Seleziona una cella per consultare la misurazione.', 'Riproduzione automatica disattivata: movimento ridotto.', 'Nessuna capsula disponibile.', 'Storico non disponibile. Ricarica per riprovare.', 'Domanda non disponibile in questa capsula.', 'Sistema', 'Modello', 'Copertura', 'Osservazioni', 'Caricamento dello storico…'],
    pt: ['Reproduzir', 'Pausa', 'Dia anterior', 'Dia seguinte', 'Dados insuficientes', 'Sem observação', 'Observação desconhecida ou ambígua', 'Deslocamento horizontal ↔ · Selecione uma célula para consultar a medição.', 'Reprodução automática desativada: movimento reduzido.', 'Nenhuma cápsula disponível.', 'Histórico indisponível. Recarregue para tentar novamente.', 'Pergunta indisponível nesta cápsula.', 'Sistema', 'Modelo', 'Cobertura', 'Observações', 'Carregando histórico…'],
    nl: ['Afspelen', 'Pauze', 'Vorige dag', 'Volgende dag', 'Onvoldoende gegevens', 'Geen waarneming', 'Onbekende of dubbelzinnige waarneming', 'Horizontaal scrollen ↔ · Selecteer een cel om de meting te bekijken.', 'Automatisch afspelen uitgeschakeld: verminderde beweging.', 'Geen capsules beschikbaar.', 'Geschiedenis niet beschikbaar. Herlaad om opnieuw te proberen.', 'Vraag niet beschikbaar in deze capsule.', 'Systeem', 'Model', 'Dekking', 'Waarnemingen', 'Geschiedenis laden…'],
    ru: ['Воспроизведение', 'Пауза', 'Предыдущий день', 'Следующий день', 'Недостаточно данных', 'Нет наблюдения', 'Неизвестное или неоднозначное наблюдение', 'Прокрутка по горизонтали ↔ · Выберите ячейку для просмотра измерения.', 'Автовоспроизведение отключено: уменьшение движения.', 'Нет доступных капсул.', 'История недоступна. Перезагрузите страницу.', 'Вопрос отсутствует в этой капсуле.', 'Система', 'Модель', 'Покрытие', 'Наблюдения', 'Загрузка истории…'],
    ar: ['تشغيل', 'إيقاف مؤقت', 'اليوم السابق', 'اليوم التالي', 'بيانات غير كافية', 'لا توجد ملاحظة', 'ملاحظة غير معروفة أو ملتبسة', 'تمرير أفقي ↔ · اختر خلية للاطّلاع على قياسها.', 'التشغيل التلقائي معطّل: تقليل الحركة.', 'لا توجد كبسولات متاحة.', 'السجل غير متاح. أعد تحميل الصفحة للمحاولة.', 'السؤال غير متاح في هذه الكبسولة.', 'النظام', 'النموذج', 'التغطية', 'الملاحظات', 'جارٍ تحميل السجل…'],
    hi: ['चलाएँ', 'रोकें', 'पिछला दिन', 'अगला दिन', 'अपर्याप्त डेटा', 'कोई अवलोकन नहीं', 'अज्ञात या अस्पष्ट अवलोकन', 'क्षैतिज स्क्रॉल ↔ · माप देखने के लिए सेल चुनें।', 'स्वचालित प्लेबैक बंद: कम गति।', 'कोई कैप्सूल उपलब्ध नहीं है।', 'इतिहास उपलब्ध नहीं है। पुनः लोड करें।', 'इस कैप्सूल में प्रश्न उपलब्ध नहीं है।', 'प्रणाली', 'मॉडल', 'कवरेज', 'अवलोकन', 'इतिहास लोड हो रहा है…'],
    ja: ['再生', '一時停止', '前の日', '次の日', 'データ不足', '観測なし', '不明または曖昧な観測', '横スクロール ↔ · セルを選択して測定を確認します。', '自動再生は無効です：視差効果を減らす設定。', '利用可能なカプセルはありません。', '履歴を利用できません。再読み込みしてください。', 'このカプセルには質問がありません。', 'システム', 'モデル', 'カバレッジ', '観測数', '履歴を読み込み中…'],
    ko: ['재생', '일시 정지', '이전 날짜', '다음 날짜', '데이터 부족', '관측 없음', '알 수 없거나 모호한 관측', '가로 스크롤 ↔ · 셀을 선택하여 측정을 확인하세요.', '자동 재생 비활성화: 동작 줄이기.', '사용 가능한 캡슐이 없습니다.', '이력을 사용할 수 없습니다. 새로고침하세요.', '이 캡슐에 질문이 없습니다.', '시스템', '모델', '커버리지', '관측 수', '이력 로드 중…'],
    zh: ['播放', '暂停', '前一天', '后一天', '数据不足', '无观测', '未知或有歧义的观测', '水平滚动 ↔ · 选择单元格以查看测量。', '自动播放已禁用：减少动态效果。', '没有可用的胶囊。', '历史记录不可用。请重新加载。', '此胶囊中没有问题。', '系统', '模型', '覆盖率', '观测数', '正在加载历史记录…']
  };
  var i18nCache = {};
  function loadOfficialStrings(lang) {
    if (i18nCache[lang]) return Promise.resolve(i18nCache[lang]);
    return fetch("@@RUNTIME@@/i18n/en.json").then(function (r) { return r.json(); }).catch(function () { return {}; }).then(function (base) {
      if (lang === "en") { i18nCache[lang] = base; return base; }
      return fetch("@@RUNTIME@@/i18n/" + lang + ".json").then(function (r) { return r.json(); }).catch(function () { return {}; }).then(function (over) {
        var merged = Object.assign({}, base, over);
        i18nCache[lang] = merged;
        return merged;
      });
    });
  }
  var languagesConfigCache = null;
  function loadLanguagesConfig() {
    if (languagesConfigCache) return Promise.resolve(languagesConfigCache);
    return fetch("@@RUNTIME@@/config/languages.json").then(function (r) { return r.json(); }).then(function (cfg) {
      languagesConfigCache = cfg; return cfg;
    }).catch(function () { return { available: [] }; });
  }

  var HIST = { days: [], day: 0, row: 0, timer: null, motion: window.matchMedia("(prefers-reduced-motion: reduce)"), systems: [], strings: {}, words: HIST_WORDS.en, isRtl: false };

  function hw(i) { return HIST.words[i]; }
  function ht(key, fallback) {
    var v = HIST.strings[key];
    return v === undefined || v === key ? fallback : v;
  }
  function histCondition(observation) {
    if (!observation) return "absent";
    var condition = observation.condition;
    if (condition === "insufficient_data" || observation.coverage_status === "insufficient_data") return "insufficient";
    return ["clear", "watch", "unsettled", "alert"].indexOf(condition) !== -1 ? condition : "unknown";
  }
  function histLabel(condition) {
    var idx = ["clear", "watch", "unsettled", "alert"].indexOf(condition);
    if (idx >= 0) {
      var prefix = ht("legend.prefix", "Judgment");
      var word = ht("judgment.j" + (idx + 1), ["Normal", "Watch", "Warning", "Critical"][idx]);
      return prefix + " " + word;
    }
    return condition === "insufficient" ? hw(4) : condition === "absent" ? hw(5) : hw(6);
  }
  // Some older capsule translations were stored as UTF-8 bytes misread as
  // Windows-1252 at write time (real, pre-existing data issue — visible
  // e.g. in a handful of German questions from late August). This repairs
  // the DISPLAY only, once, never the capsule file itself, and only when
  // the mojibake signature is actually detected. Ported from
  // index_full.html's chDisplayQuestion(), unchanged.
  function histDisplayQuestion(text) {
    var mojibake = /Ã|Â|â€|ðŸ/;
    if (typeof text !== "string" || !mojibake.test(text)) return text;
    try {
      // The corruption is raw UTF-8 bytes read back as ISO-8859-1 (Latin-1),
      // where byte value === code point 1:1 — NOT windows-1252, whose
      // 0x80-0x9F range remaps to curly quotes/dashes/€ instead of the
      // literal C1 control code points. Browsers alias the "iso-8859-1"
      // TextDecoder label to windows-1252 (WHATWG spec), so there is no
      // decoder to ask for here; String.fromCharCode's inverse is exact.
      var bytes = [];
      for (var ch of text) {
        var code = ch.codePointAt(0);
        if (code > 255) return text;
        bytes.push(code);
      }
      var repaired = new TextDecoder("utf-8", { fatal: true }).decode(Uint8Array.from(bytes));
      return mojibake.test(repaired) ? text : repaired;
    } catch (e) { return text; }
  }
  function histDate(iso, short) {
    try {
      return new Intl.DateTimeFormat(HIST.lang, { year: short ? undefined : "numeric", month: short ? "2-digit" : "short", day: "2-digit", timeZone: "UTC" }).format(new Date(iso + "T00:00:00Z"));
    } catch (e) { return iso; }
  }
  // Find, for a given (already-live) system, the matching observation in a
  // historical capsule. Matched on the technical `model` string only — the
  // one field both weather.json's live systems and a capsule's own
  // observations actually share. A model rename between two capsules is
  // therefore shown honestly as "no observation that day" rather than
  // guessed via a hardcoded alias table (see project note on CH_SYSTEMS).
  function histObservation(capsule, model) {
    var matches = (capsule.observations || []).filter(function (o) { return o && o.model === model; });
    return matches.length > 1 ? { condition: "ambiguous" } : matches[0];
  }
  function histPause() {
    clearInterval(HIST.timer); HIST.timer = null;
    var btn = document.getElementById("hist-play");
    btn.textContent = hw(0); btn.setAttribute("aria-pressed", "false");
  }
  function histMotion() {
    histPause();
    var btn = document.getElementById("hist-play");
    btn.disabled = HIST.motion.matches || HIST.days.length < 2;
    document.getElementById("hist-hint").textContent = hw(7) + (HIST.motion.matches ? " " + hw(8) : "");
  }
  function histSelect(day, row, reveal) {
    if (row === undefined) row = HIST.row;
    HIST.day = day; HIST.row = row;
    document.querySelectorAll("#hist-strip .hist-day").forEach(function (el) { el.classList.toggle("is-active", Number(el.dataset.day) === day); });
    document.querySelectorAll("#hist-table [data-day]").forEach(function (el) {
      if (el.tagName !== "BUTTON") return;
      var active = Number(el.dataset.day) === day && Number(el.dataset.row) === row;
      el.setAttribute("aria-pressed", String(active));
    });
    var record = HIST.days[day], system = HIST.systems[row];
    if (!system) return;
    var identity = NMData.getPublicIdentity(system);
    var observation = histObservation(record.capsule, system.model);
    document.getElementById("hist-detail-title").textContent = identity.label + " · " + histDate(record.date) + " · " + histLabel(histCondition(observation));
    var daily = (record.capsule.probe_contract || {}).daily || {};
    var measured = (observation && observation.daily) || observation || {};
    var protocol = record.capsule.protocol || {};
    var metadata = document.getElementById("hist-metadata");
    metadata.innerHTML = "";
    var measuredAtRaw = (measured && measured.last_observed_at) || (record.capsule.coverage && record.capsule.coverage.last_measurement_at);
    var measuredAtDisplay = "—";
    if (measuredAtRaw) {
      try {
        var md = new Date(measuredAtRaw);
        measuredAtDisplay = new Intl.DateTimeFormat(HIST.lang, { year: "numeric", month: "long", day: "numeric", timeZone: "UTC" }).format(md) +
          ", " + pad2(md.getUTCHours()) + ":" + pad2(md.getUTCMinutes()) + " UTC";
      } catch (e) { measuredAtDisplay = measuredAtRaw; }
    }
    var pairs = [
      [hw(13), (observation && observation.model) || "—"],
      [ht("ui.measured_on", "Measured on"), measuredAtDisplay],
      [ht("ui.protocol_label", "Protocol"), [protocol.id, protocol.version].filter(Boolean).join(" · ") || "—"],
      [hw(14), measured && typeof measured.coverage === "number" ? Math.round(measured.coverage * 100) + "%" : "—"],
      [hw(15), (measured && measured.observations) || "—"]
    ];
    pairs.forEach(function (pair) {
      var dt = document.createElement("dt"); dt.textContent = pair[0];
      var dd = document.createElement("dd"); dd.textContent = pair[1];
      metadata.appendChild(dt); metadata.appendChild(dd);
    });
    var original = typeof daily.question === "string" && daily.question.trim() ? daily.question : null;
    var translated = daily.question_translations && daily.question_translations[HIST.lang];
    var hasTranslation = HIST.lang !== "en" && typeof translated === "string" && translated.trim();
    document.getElementById("hist-question").textContent = histDisplayQuestion((hasTranslation ? translated : original) || hw(11));
    document.getElementById("hist-question-label").textContent = ht("ui.question_of_day", "Question of the day");
    var originalDetails = document.getElementById("hist-original");
    document.getElementById("hist-original-toggle").textContent = ht("ui.view_original_en", "View original EN");
    document.getElementById("hist-original-text").textContent = histDisplayQuestion(original || "—");
    originalDetails.hidden = !(hasTranslation && original);
    var jsonLink = document.getElementById("hist-json");
    jsonLink.href = record.url;
    jsonLink.textContent = "JSON · " + (record.capsule.capsule_id || record.date);
    document.getElementById("hist-prev").disabled = day === 0;
    document.getElementById("hist-next").disabled = day === HIST.days.length - 1;
    if (reveal) {
      var cell = document.querySelector('#hist-table button[data-day="' + day + '"][data-row="' + row + '"]');
      var scroller = document.getElementById("hist-table-scroll");
      if (cell && scroller) {
        var bounds = scroller.getBoundingClientRect(), rect = cell.getBoundingClientRect();
        var sticky = document.querySelector("#hist-table th") ? document.querySelector("#hist-table th").getBoundingClientRect().width : 0;
        var rtl = HIST.isRtl;
        var left = bounds.left + (rtl ? 0 : sticky) + 8, right = bounds.right - (rtl ? sticky : 0) - 8;
        if (rect.left < left) scroller.scrollLeft += rect.left - left;
        else if (rect.right > right) scroller.scrollLeft += rect.right - right;
      }
    }
  }
  function buildHistoryDom() {
    var strip = document.getElementById("hist-strip");
    strip.innerHTML = "";
    HIST.days.forEach(function (record, i) {
      var btn = document.createElement("button");
      btn.type = "button";
      btn.className = "hist-day cond-" + histCondition({ condition: record.capsule.global_condition });
      btn.dataset.day = i;
      btn.setAttribute("role", "tab");
      var label = histLabel(histCondition({ condition: record.capsule.global_condition }));
      btn.setAttribute("aria-label", histDate(record.date) + " · " + label);
      btn.title = histDate(record.date) + " · " + label;
      btn.innerHTML = '<span class="hist-day-date">' + histDate(record.date, true) + '</span><span class="hist-day-dot" aria-hidden="true"></span>';
      btn.addEventListener("click", function () { histPause(); histSelect(i, HIST.row, true); });
      strip.appendChild(btn);
    });

    var table = document.getElementById("hist-table");
    table.innerHTML = "";
    var thead = document.createElement("thead");
    var headRow = document.createElement("tr");
    var corner = document.createElement("th"); corner.scope = "col"; corner.textContent = hw(12);
    headRow.appendChild(corner);
    HIST.days.forEach(function (record, i) {
      var th = document.createElement("th"); th.scope = "col"; th.dataset.day = i;
      th.textContent = histDate(record.date, true);
      th.title = histDate(record.date);
      th.setAttribute("aria-label", histDate(record.date));
      headRow.appendChild(th);
    });
    thead.appendChild(headRow); table.appendChild(thead);

    var tbody = document.createElement("tbody");
    HIST.systems.forEach(function (system, row) {
      var identity = NMData.getPublicIdentity(system);
      var tr = document.createElement("tr");
      var th = document.createElement("th"); th.scope = "row"; th.textContent = identity.label;
      tr.appendChild(th);
      HIST.days.forEach(function (record, day) {
        var observation = histObservation(record.capsule, system.model);
        var condition = histCondition(observation);
        var td = document.createElement("td");
        var btn = document.createElement("button");
        btn.type = "button"; btn.className = "hist-cell-btn cond-" + condition;
        btn.dataset.day = day; btn.dataset.row = row;
        btn.setAttribute("aria-controls", "hist-detail");
        var description = identity.label + " · " + histDate(record.date) + " · " + histLabel(condition);
        btn.setAttribute("aria-label", description); btn.title = description;
        btn.innerHTML = '<span class="hist-mark" aria-hidden="true"></span>';
        btn.addEventListener("click", function () { histPause(); histSelect(day, row); });
        td.appendChild(btn); tr.appendChild(td);
      });
      tbody.appendChild(tr);
    });
    table.appendChild(tbody);

    var legend = document.getElementById("history-legend");
    var LEVELS = ["clear", "watch", "unsettled", "alert"];
    legend.innerHTML = LEVELS.map(function (cond) {
      return '<span><i style="background:' + CONDITION_COLOR[cond] + '"></i>' + ht("judgment.j" + (LEVELS.indexOf(cond) + 1), cond) + "</span>";
    }).join("") + '<span><i class="dashed"></i>' + hw(4) + "</span>";

    document.getElementById("hist-prev").textContent = hw(2);
    document.getElementById("hist-next").textContent = hw(3);
    document.getElementById("hist-prev").onclick = function () { histPause(); histSelect(Math.max(0, HIST.day - 1), HIST.row, true); };
    document.getElementById("hist-next").onclick = function () { histPause(); histSelect(Math.min(HIST.days.length - 1, HIST.day + 1), HIST.row, true); };
    document.getElementById("hist-play").onclick = function () {
      if (HIST.timer) { histPause(); return; }
      if (HIST.motion.matches || HIST.days.length < 2) return;
      if (HIST.day === HIST.days.length - 1) histSelect(0, HIST.row, true);
      document.getElementById("hist-play").textContent = hw(1);
      document.getElementById("hist-play").setAttribute("aria-pressed", "true");
      HIST.timer = setInterval(function () {
        if (HIST.day >= HIST.days.length - 1) { histPause(); return; }
        histSelect(HIST.day + 1, HIST.row, true);
        if (HIST.day === HIST.days.length - 1) histPause();
      }, 2500);
    };
    document.getElementById("hist-original").addEventListener("toggle", function () { if (this.open) histPause(); });
    document.getElementById("hist-detail").addEventListener("focusin", histPause);
    document.getElementById("hist-table-scroll").addEventListener("pointerdown", histPause);
    HIST.motion.addEventListener("change", histMotion);
    document.addEventListener("visibilitychange", function () { if (document.hidden) histPause(); });
    window.addEventListener("pagehide", histPause);
    histMotion();
    histSelect(HIST.days.length - 1, 0, true);
  }

  var historyLoadStarted = false;
  function loadHistoryOnce(weatherData, panelSystems) {
    if (historyLoadStarted) return;
    historyLoadStarted = true;
    HIST.systems = panelSystems;
    var status = document.getElementById("history-status");
    status.textContent = hw(16) || "Loading history…";

    var manifestUrl = new URL("@@RUNTIME@@/data/capsule-index.json", window.location.href);
    function json(url) {
      var controller = new AbortController();
      var timeout = setTimeout(function () { controller.abort(); }, 15000);
      return fetch(url, { cache: "no-store", signal: controller.signal }).then(function (r) {
        clearTimeout(timeout);
        if (!r.ok) throw new Error("HTTP " + r.status);
        return r.json();
      }, function (err) { clearTimeout(timeout); throw err; });
    }
    json(manifestUrl).then(function (manifest) {
      if (manifest.schema_version !== 1 || !Array.isArray(manifest.capsules)) throw new Error("Invalid manifest");
      var seen = {};
      manifest.capsules.forEach(function (entry) {
        if (!entry || !/^\d{4}-\d{2}-\d{2}$/.test(entry.date) || seen[entry.date]) throw new Error("Invalid or duplicate date");
        seen[entry.date] = true;
      });
      var selected = manifest.capsules.slice().sort(function (a, b) { return b.date.localeCompare(a.date); }).slice(0, 15).reverse();
      return Promise.all(selected.map(function (entry) {
        var url = new URL(entry.path, manifestUrl).href;
        return json(url).then(function (capsule) {
          if (capsule.date !== entry.date || !Array.isArray(capsule.observations)) throw new Error("Invalid capsule");
          return Object.assign({}, entry, { url: url, capsule: capsule });
        });
      }));
    }).then(function (days) {
      HIST.days = days;
      if (!days.length) { status.textContent = hw(9); return; }
      status.textContent = "";
      document.getElementById("history-content").hidden = false;
      buildHistoryDom();
    }).catch(function () {
      document.getElementById("history-content").hidden = true;
      status.textContent = hw(10);
    });
  }

  var weatherDataGlobal = null, panelSystemsGlobal = null;

  function renderHistory(lang) {
    HIST.lang = lang;
    HIST.words = HIST_WORDS[lang] || HIST_WORDS.en;
    Promise.all([loadOfficialStrings(lang), loadLanguagesConfig()]).then(function (results) {
      HIST.strings = results[0] || {};
      var langsCfg = results[1] || { available: [] };
      var meta = (langsCfg.available || []).find(function (l) { return l.code === lang; });
      HIST.isRtl = !!(meta && meta.direction === "rtl");
      // Scoped to the data-driven widget only (not .history-head above it,
      // which is this page's own EN/FR-only chrome copy) — otherwise an
      // un-translated English heading sitting inside a dir="rtl" ancestor
      // gets its digits/punctuation visually reordered by the browser's
      // bidi algorithm even though the text itself is plain English.
      var root = document.getElementById("history-content");
      root.setAttribute("dir", HIST.isRtl ? "rtl" : "ltr");
      if (HIST.days.length) buildHistoryDom();
      else if (weatherDataGlobal) loadHistoryOnce(weatherDataGlobal, panelSystemsGlobal);
    });
  }

  // ---------------- Boot ----------------
  // NMData.load()/loadPanels()/loadHistory() hardcode "./..." paths that
  // assume the calling page lives at the repo root (like index.html
  // itself). today.html is one directory deeper, so those fixed paths
  // would resolve wrong here. We fetch with the correct relative paths
  // ourselves and only reuse NMData's pure, path-free helpers
  // (getPanelSystems / getPublicIdentity / getSystemHistory) — exactly
  // the functions relevant to "don't hardcode system identity".
  function loadWeatherJson() {
    return fetch("@@RUNTIME@@/weather.json?v=" + Date.now(), { cache: "no-store" }).then(function (r) {
      if (!r.ok) throw new Error("Failed to load weather.json");
      return r.json();
    });
  }
  function loadPanelsConfig() {
    return fetch("@@RUNTIME@@/config/panels.json").then(function (r) {
      if (!r.ok) throw new Error("Failed to load panels.json");
      return r.json();
    });
  }
  function loadHistory7(anchorData) {
    var anchorDate = anchorData && anchorData.generated_at ? new Date(anchorData.generated_at) : new Date();
    var datesToFetch = [];
    for (var i = 6; i >= 1; i--) {
      var d = new Date(anchorDate);
      d.setDate(d.getDate() - i);
      datesToFetch.push(d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()));
    }
    return Promise.all(datesToFetch.map(function (iso) {
      return fetch("@@RUNTIME@@/data/history/" + iso + ".json").then(function (r) { if (!r.ok) throw new Error("missing"); return r.json(); }).catch(function () { return null; });
    })).then(function (fetchedDays) {
      var historyBySystem = {};
      fetchedDays.forEach(function (dayData, idx) {
        if (!dayData) return;
        var iso = datesToFetch[idx];
        (dayData.systems || []).forEach(function (system) {
          if (!historyBySystem[system.id]) historyBySystem[system.id] = [];
          historyBySystem[system.id].push({ date: iso, condition: system.condition });
        });
      });
      var todayIso = anchorDate.getFullYear() + "-" + pad2(anchorDate.getMonth() + 1) + "-" + pad2(anchorDate.getDate());
      (anchorData.systems || []).forEach(function (system) {
        if (!historyBySystem[system.id]) historyBySystem[system.id] = [];
        historyBySystem[system.id].push({ date: todayIso, condition: system.condition });
      });
      return historyBySystem;
    });
  }

  Promise.all([loadWeatherJson(), loadPanelsConfig()])
    .then(function (results) {
      return loadHistory7(results[0]).catch(function () { return {}; }).then(function (historyMap) {
        return [results[0], results[1], historyMap];
      });
    })
    .then(function (results) {
      var data = results[0], panelsConfig = results[1], historyMap = results[2];
      weatherDataGlobal = data;
      var fullIds = (panelsConfig.panels && panelsConfig.panels.full) || (data.systems || []).map(function (s) { return s.id; });
      panelSystemsGlobal = NMData.getPanelSystems(data, fullIds);
      renderHeroAndWall(data, panelSystemsGlobal, historyMap);
      applyCopy(current);
      loadHistoryOnce(data, panelSystemsGlobal);
      renderHistory(current);
    })
    .catch(function () {
      document.getElementById("wall-native").innerHTML = "";
      document.getElementById("wall-fallback").hidden = false;
    });
})();
