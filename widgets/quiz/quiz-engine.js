/**
 * NeoMundi AI Weather — "Spot the Drift" quiz engine.
 *
 * Single rendering/scoring engine shared by quiz-full.html (5-question
 * "Spot the Drift") and quiz-daily.html ("signal du jour" — one real
 * question drawn from today's quiz-data/daily-drift.json). Zero
 * scoring/rendering logic is duplicated between the two modes; the
 * thin HTML templates only load this file and call one of the two
 * exposed init functions.
 *
 * Depends on NMi18n (scripts/i18n.js) already having been init()'d by
 * the caller before initQuizFull/initQuizDaily runs — same contract as
 * every other AI Weather widget.
 *
 * Brand line and the RÉAGI footer citation are deliberately NOT i18n
 * keys: same precedent as weather-bar-6.html's BRAND_SIGNATURE, which
 * stays English-only regardless of ?lang= by product decision. "Spot
 * the Drift" is a product name; "Cadre RÉAGI" is a citation — neither
 * is UI copy that should vary per language.
 */
(function (window) {
  "use strict";

  const BRAND_LINE = "NeoMundi · Spot the Drift";
  const REAGI_FOOTER_HTML =
    'Cadre RÉAGI · <a href="https://doi.org/10.5281/zenodo.20259638" target="_blank" rel="noopener">doi.org/10.5281/zenodo.20259638</a>';

  // controltowerai.io is the public hub; weather.controltowerai.io (where
  // this quiz is hosted) is embedded inside it, not a standalone
  // destination — visitors are never sent to the weather subdomain
  // itself. Same URL, same field name (links.full_weather_url), and same
  // fetch pattern (config/wording.json) as weather-bar-6.html already
  // uses for its own "See the full AI Weather" CTA (there: brand.name).
  // The literal string here is only a fallback if that fetch fails; it
  // must stay byte-identical to weather-bar-6.html's own
  // fullWeatherUrl constant.
  const FULL_WEATHER_URL_FALLBACK = "https://controltowerai.io/ai-weather/";
  let fullWeatherUrl = FULL_WEATHER_URL_FALLBACK;

  function loadWordingConfig() {
    return fetch("config/wording.json")
      .then((r) => (r.ok ? r.json() : {}))
      .catch(() => ({}))
      .then((wording) => {
        const url = wording && wording.links && wording.links.full_weather_url;
        if (typeof url === "string" && /^https?:\/\//.test(url)) {
          fullWeatherUrl = url;
        }
      });
  }

  // ---------------------------------------------------------------
  // Fixed pedagogical question set (quiz-full). Translatable text
  // (question, options, rule) lives in i18n under quiz.q<n>.* — see
  // i18n/fr.json / i18n/en.json. reagi/contract/correct are internal
  // metadata, identical across every language.
  // ---------------------------------------------------------------

  const QUESTION_META = [
    { id: "q1", reagi: "R", contract: "Metric Contract §16", correct: 2 },
    { id: "q2", reagi: "E", contract: "Metric Contract §11, §22", correct: 2 },
    { id: "q3", reagi: "A", contract: "Metric Contract §5–§6", correct: 0 },
    { id: "q4", reagi: "G", contract: "Metric Contract §27–§29", correct: 3 },
    { id: "q5", reagi: "I", contract: "Metric Contract §35, §45", correct: 2 },
  ];

  // clear/watch/unsettled/alert, mapped onto the existing judgment.j1-j4
  // i18n labels (Normal/Watch/Warning/Critical EN, Normal/Vigilance/
  // Alerte/Critique FR — already shipped in every i18n/<code>.json and
  // used live by weather-bar-6.html's legend). The longer "meaning"
  // sentence is a quiz-specific key (quiz.level.<condition>), adapted
  // from docs/AI_WEATHER_JUDGMENT_DEMAND_PROFILE_v0.1.md's §5-§8
  // canonical public-meaning text.
  const LEVELS = [
    { min: 5, condition: "clear", judgmentKey: "judgment.j1" },
    { min: 3, condition: "watch", judgmentKey: "judgment.j2" },
    { min: 2, condition: "unsettled", judgmentKey: "judgment.j3" },
    { min: 0, condition: "alert", judgmentKey: "judgment.j4" },
  ];

  const REAGI_LETTERS = ["R", "E", "A", "G", "I"];

  // ---------------------------------------------------------------
  // i18n helpers
  // ---------------------------------------------------------------

  function t(key, fallback) {
    const value = window.NMi18n ? window.NMi18n.t(key) : key;
    if (value === key) {
      return fallback !== undefined ? fallback : key;
    }
    return value;
  }

  function fillTemplate(str, vars) {
    return String(str).replace(/\{(\w+)\}/g, (match, name) =>
      Object.prototype.hasOwnProperty.call(vars, name) ? vars[name] : match
    );
  }

  function loadQuestions() {
    return QUESTION_META.map((meta) => ({
      ...meta,
      text: t(`quiz.${meta.id}.text`),
      options: t(`quiz.${meta.id}.options`, []),
      rule: t(`quiz.${meta.id}.rule`),
    }));
  }

  function levelForScore(score) {
    return LEVELS.find((l) => score >= l.min) || LEVELS[LEVELS.length - 1];
  }

  function escapeHtml(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  // ---------------------------------------------------------------
  // Iframe auto-resize (Step 5's embed.js listens for this on the
  // parent side). Posted after every render since screens change
  // height as the quiz progresses.
  // ---------------------------------------------------------------

  function reportHeight() {
    if (window.parent === window) return;
    const height = document.documentElement.scrollHeight;
    window.parent.postMessage({ type: "nm-quiz-resize", height }, "*");
  }

  // Covers width-driven reflow (host container resized without any quiz
  // state change — e.g. a responsive column going from 300px to 800px,
  // which rewraps the same text to a different number of lines) in
  // addition to the per-render calls above, which only cover height
  // changes caused by moving between quiz screens.
  let resizeListenerAttached = false;
  function attachResizeListener() {
    if (resizeListenerAttached || window.parent === window) return;
    resizeListenerAttached = true;
    let raf = null;
    window.addEventListener("resize", () => {
      if (raf) return;
      raf = requestAnimationFrame(() => {
        raf = null;
        reportHeight();
      });
    });
  }

  function fireEvent(opts, name, payload) {
    if (opts && typeof opts.onEvent === "function") {
      opts.onEvent(name, payload || {});
    }
  }

  // ---------------------------------------------------------------
  // Language selector (quiz-full only) — same markup/behavior as
  // index.html's .lang-select: a full-page reload with an updated
  // ?lang= query param, no soft in-page language switch. This mirrors
  // the site's only existing visible-selector precedent; quiz-daily
  // has no equivalent markup, matching weather-bar-*.html's
  // "configuration via URL only, no in-widget UI" convention for
  // embeddable widgets (see quiz-daily.html header comment).
  // ---------------------------------------------------------------

  function renderLangSelect(controlsEl) {
    if (!controlsEl || !window.NMi18n) return;

    const config = window.NMi18n.getLanguagesConfig();
    if (!config) return;

    const current = window.NMi18n.lang();

    controlsEl.innerHTML = `
      <div class="lang-select">
        <button class="lang-button" id="quiz-lang-button" type="button" aria-haspopup="true" aria-expanded="false">${current.toUpperCase()} ▾</button>
        <div class="lang-menu" id="quiz-lang-menu"></div>
      </div>
    `;

    const menu = controlsEl.querySelector("#quiz-lang-menu");
    menu.innerHTML = (config.available || [])
      .map(
        (l) => `
        <button class="lang-option ${l.code === current ? "active" : ""}" data-lang="${l.code}" type="button">${escapeHtml(l.label)}</button>
      `
      )
      .join("");

    menu.querySelectorAll(".lang-option").forEach((btn) => {
      btn.addEventListener("click", () => {
        const params = new URLSearchParams(window.location.search);
        params.set("lang", btn.dataset.lang);
        window.location.search = params.toString();
      });
    });

    const button = controlsEl.querySelector("#quiz-lang-button");
    button.addEventListener("click", () => {
      const willOpen = !menu.classList.contains("open");
      menu.classList.toggle("open", willOpen);
      button.setAttribute("aria-expanded", String(willOpen));
    });

    document.addEventListener("click", (e) => {
      if (!controlsEl.contains(e.target)) {
        menu.classList.remove("open");
        button.setAttribute("aria-expanded", "false");
      }
    });
  }

  // ---------------------------------------------------------------
  // RÉAGI grid — shared between the full-quiz reveal (5 rows, one per
  // question) and the daily reveal (1 row, the single question asked).
  // ---------------------------------------------------------------

  function renderReagiGrid(rows) {
    const rowsHtml = rows
      .map(
        (row) => `
        <div class="reagi-row ${row.aligned ? "is-aligned" : "is-gap"}">
          <div class="reagi-letter">${row.letter}</div>
          <div class="reagi-body">
            <div class="reagi-name">${escapeHtml(row.name)} — ${row.aligned ? escapeHtml(t("quiz.reveal.aligned", "aligné")) : escapeHtml(t("quiz.reveal.gap", "à muscler"))}</div>
            <div class="reagi-rule">${escapeHtml(row.rule)}${row.contract ? ` <em>(${escapeHtml(row.contract)})</em>` : ""}</div>
          </div>
        </div>
      `
      )
      .join("");

    return `
      <div class="reagi-list">
        <div class="reagi-heading">${escapeHtml(t("quiz.reveal.grid_heading", "Grille RÉAGI"))}</div>
        ${rowsHtml}
      </div>
    `;
  }

  function reagiName(letter) {
    return t(`quiz.reagi.${letter}`, letter);
  }

  // =================================================================
  // quiz-full — 5 fixed questions + full reveal
  // =================================================================

  function initQuizFull(containerEl, opts) {
    opts = opts || {};
    attachResizeListener();
    const questions = loadQuestions();

    const state = { step: 0, answers: [] };

    function render() {
      if (state.step < questions.length) {
        renderQuestion(state.step);
      } else {
        renderReveal();
      }
      reportHeight();
    }

    function renderProgress(currentIndex) {
      return `
        <div class="quiz-progress">
          ${questions
            .map((_, i) => {
              const cls = i < currentIndex ? "is-done" : i === currentIndex ? "is-current" : "";
              return `<span class="step ${cls}"></span>`;
            })
            .join("")}
        </div>
      `;
    }

    function renderQuestion(index) {
      const q = questions[index];
      const stepLabel = fillTemplate(t("quiz.step_label", "Question {n} / {total}"), {
        n: index + 1,
        total: questions.length,
      });

      containerEl.innerHTML = `
        <div class="quiz-brand">${escapeHtml(BRAND_LINE.toUpperCase())}</div>
        <div class="quiz-title">${escapeHtml(t("quiz.title", "Spot the Drift"))}</div>
        ${renderProgress(index)}
        <div class="quiz-step-label">${escapeHtml(stepLabel)}</div>
        <div class="quiz-question">${escapeHtml(q.text)}</div>
        <div class="quiz-options">
          ${q.options.map((opt, i) => `<button class="quiz-option" data-index="${i}">${escapeHtml(opt)}</button>`).join("")}
        </div>
      `;

      containerEl.querySelectorAll(".quiz-option").forEach((btn) => {
        btn.addEventListener("click", () => {
          const choice = parseInt(btn.dataset.index, 10);
          state.answers[index] = choice;
          fireEvent(opts, "quiz_question_answered", { position: index + 1, total: questions.length });
          state.step += 1;
          render();
        });
      });

      if (index === 0) {
        fireEvent(opts, "quiz_start", {});
      }
    }

    function renderReveal() {
      const score = questions.reduce((total, q, i) => total + (state.answers[i] === q.correct ? 1 : 0), 0);
      const level = levelForScore(score);

      const reagiRows = questions.map((q, i) => ({
        letter: q.reagi,
        name: reagiName(q.reagi),
        aligned: state.answers[i] === q.correct,
        rule: q.rule,
        contract: q.contract,
      }));

      containerEl.innerHTML = `
        <div class="quiz-brand">${escapeHtml(BRAND_LINE.toUpperCase())}</div>
        <div class="quiz-disclaimer">${escapeHtml(t("quiz.reveal.disclaimer"))}</div>
        <div class="reveal-status">
          <span class="reveal-dot is-${level.condition}"></span>
          <span class="reveal-level">${escapeHtml(t(level.judgmentKey))}</span>
        </div>
        <p class="reveal-meaning">${escapeHtml(t(`quiz.level.${level.condition}`))}</p>
        ${renderReagiGrid(reagiRows)}
        <a class="quiz-cta" href="${fullWeatherUrl}" target="_blank" rel="noopener" data-cta="weather">${escapeHtml(t("quiz.reveal.cta", "See today's AI Weather →"))}</a>
        <div class="quiz-foot">${REAGI_FOOTER_HTML}</div>
      `;

      containerEl.querySelector('[data-cta="weather"]').addEventListener("click", () => {
        fireEvent(opts, "quiz_cta_click", { target: "weather" });
      });

      fireEvent(opts, "quiz_complete", { score, condition: level.condition });
    }

    loadWordingConfig().then(render);
  }

  // =================================================================
  // quiz-daily — one real question drawn from quiz-data/daily-drift.json
  //
  // Reuses Q2's pedagogical framing verbatim ("même question, deux
  // réponses différentes — est-ce automatiquement un problème ?") but
  // grounds it in TODAY's real divergence pair instead of a
  // hypothetical, so the same RÉAGI letter (É/Evaluation) and Metric
  // Contract citation (§11, §22) apply. A single question can't
  // produce a meaningful 5-row RÉAGI grid or 4-level regime the way
  // quiz-full's 5 questions can, so the reveal here is a single
  // aligned/gap row plus the real underlying NeoMundi signal
  // (decision mismatch, stability delta) as evidence — with a CTA into
  // quiz-full for the full 5-question version.
  // =================================================================

  const DAILY_QUESTION_META = QUESTION_META[1]; // q2 — decision_mismatch is exactly this question's scenario

  function initQuizDaily(containerEl, opts) {
    opts = opts || {};
    attachResizeListener();

    containerEl.innerHTML = `<div class="quiz-loading">${escapeHtml(t("ui.loading", "Loading…"))}</div>`;

    Promise.all([
      fetch("quiz-data/daily-drift.json").then((r) =>
        r.ok ? r.json() : Promise.reject(new Error("daily-drift.json unavailable"))
      ),
      loadWordingConfig(),
    ])
      .then(([payload]) => renderDaily(payload.entry))
      .catch(() => {
        containerEl.innerHTML = `<div class="quiz-error">${escapeHtml(t("quiz.daily.unavailable", "Today's Spot the Drift signal is not available yet."))}</div>`;
        reportHeight();
      });

    function renderDaily(entry) {
      if (!entry) {
        containerEl.innerHTML = `<div class="quiz-error">${escapeHtml(t("quiz.daily.unavailable", "Today's Spot the Drift signal is not available yet."))}</div>`;
        reportHeight();
        return;
      }

      const state = { answered: false };
      const questionText = t(`quiz.${DAILY_QUESTION_META.id}.text`);
      const options = t(`quiz.${DAILY_QUESTION_META.id}.options`, []);
      const rule = t(`quiz.${DAILY_QUESTION_META.id}.rule`);

      const [responseA, responseB] = entry.responses;

      function renderQuestionScreen() {
        containerEl.innerHTML = `
          <div class="quiz-brand">${escapeHtml(BRAND_LINE.toUpperCase())}</div>
          <div class="quiz-title">${escapeHtml(t("ui.question_of_day", "Question of the day"))}</div>
          <div class="quiz-responses">
            <div class="quiz-response">
              <div class="quiz-response-label">${escapeHtml(t("quiz.daily.response_a", "Response A"))}</div>
              <div class="quiz-response-text">${escapeHtml(responseA.text)}</div>
            </div>
            <div class="quiz-response">
              <div class="quiz-response-label">${escapeHtml(t("quiz.daily.response_b", "Response B"))}</div>
              <div class="quiz-response-text">${escapeHtml(responseB.text)}</div>
            </div>
          </div>
          <div class="quiz-question">${escapeHtml(questionText)}</div>
          <div class="quiz-options">
            ${options.map((opt, i) => `<button class="quiz-option" data-index="${i}">${escapeHtml(opt)}</button>`).join("")}
          </div>
        `;

        containerEl.querySelectorAll(".quiz-option").forEach((btn) => {
          btn.addEventListener("click", () => {
            const choice = parseInt(btn.dataset.index, 10);
            fireEvent(opts, "quiz_question_answered", { position: 1, total: 1, mode: "daily" });
            renderRevealScreen(choice);
          });
        });

        fireEvent(opts, "quiz_start", { mode: "daily" });
        reportHeight();
      }

      function renderRevealScreen(choice) {
        const aligned = choice === DAILY_QUESTION_META.correct;
        const row = {
          letter: DAILY_QUESTION_META.reagi,
          name: reagiName(DAILY_QUESTION_META.reagi),
          aligned,
          rule,
          contract: DAILY_QUESTION_META.contract,
        };

        const signal = entry.signal || {};
        const signalLine = fillTemplate(
          t(
            "quiz.daily.signal_line",
            "Real NeoMundi signal for this pair: decision {decisions}, stability spread {range}."
          ),
          {
            decisions: (signal.decisions_observed || []).join(" / "),
            range: typeof signal.stability_score_range === "number" ? signal.stability_score_range.toFixed(2) : "—",
          }
        );

        containerEl.innerHTML = `
          <div class="quiz-brand">${escapeHtml(BRAND_LINE.toUpperCase())}</div>
          ${renderReagiGrid([row])}
          <p class="reveal-meaning">${escapeHtml(signalLine)}</p>
          <a class="quiz-cta" href="widgets/quiz/quiz-full.html" data-cta="full">${escapeHtml(t("quiz.daily.cta_full", "Try the full 5-question quiz →"))}</a>
          <a class="quiz-cta-secondary" href="${fullWeatherUrl}" target="_blank" rel="noopener" data-cta="weather">${escapeHtml(t("quiz.reveal.cta", "See today's AI Weather →"))}</a>
          <div class="quiz-foot">${REAGI_FOOTER_HTML}</div>
        `;

        containerEl.querySelector('[data-cta="full"]').addEventListener("click", () => {
          fireEvent(opts, "quiz_cta_click", { target: "quiz_full" });
        });
        containerEl.querySelector('[data-cta="weather"]').addEventListener("click", () => {
          fireEvent(opts, "quiz_cta_click", { target: "weather" });
        });

        fireEvent(opts, "quiz_complete", { mode: "daily", aligned });
        reportHeight();
      }

      renderQuestionScreen();
    }
  }

  window.NMQuiz = {
    initQuizFull,
    initQuizDaily,
    renderLangSelect,
  };
})(window);
