/**
 * NeoMundi AI Weather — shared data access.
 *
 * Single source of truth:
 * every widget format (wall, topbar, sidebar, provider widget)
 * reads through this module instead of fetching or parsing weather.json
 * independently.
 *
 * A change in weather.json is automatically visible everywhere.
 */

(function (window) {
  "use strict";

  let cached = null;

  /**
   * Fetch a JSON resource and fail explicitly on HTTP errors.
   *
   * Options can be passed through to fetch(), allowing canonical live
   * resources such as weather.json to bypass browser/service-worker cache.
   */
  function fetchJson(path, options = {}) {
    return fetch(path, options).then((response) => {
      if (!response.ok) {
        throw new Error("Failed to load " + path);
      }

      return response.json();
    });
  }

  /**
   * Load the canonical current AI Weather dataset.
   *
   * The result is cached only for the lifetime of the current page.
   * On every page load, weather.json is requested fresh.
   *
   * The timestamp query parameter prevents stale URL-level cache reuse.
   * cache: "no-store" asks the browser not to reuse a cached response.
   *
   * `sourceOverride` (optional) points load() at an alternate JSON file
   * instead of the public weather.json — used only by dev/shadow test
   * harnesses (e.g. a fixture merging V2 longitudinal states) to verify
   * widget rendering ahead of any public data change. No production
   * widget passes this argument, so this parameter has zero effect on
   * any live embed: load() with no argument behaves exactly as before.
   */
  async function load(sourceOverride) {
    if (cached && !sourceOverride) {
      return cached;
    }

    const livePath = sourceOverride || ("./weather.json?v=" + Date.now());

    const result = await fetchJson(livePath, {
      cache: "no-store"
    });

    if (!sourceOverride) {
      cached = result;
    }

    return result;
  }

  /**
   * Format a Date as an ISO calendar date (YYYY-MM-DD), matching the
   * data/history/<date>.json file naming convention.
   */
  function formatDateISO(d) {
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, "0");
    const day = String(d.getDate()).padStart(2, "0");
    return y + "-" + m + "-" + day;
  }

  /**
   * Load a rolling window of the last `days` calendar days of system
   * conditions, for sparkline/trend rendering.
   *
   * Design notes:
   *
   * - The window is ANCHORED on weather.json's own generated_at date,
   *   not the visitor's local clock, so it stays correct regardless of
   *   the visitor's timezone.
   * - "Today" is never fetched from data/history/ — it is taken
   *   directly from the already-loaded current weather.json. This is
   *   deliberate: the daily automation (~14:00) writes
   *   data/history/<today>.json only once it runs, so a page loaded
   *   earlier in the day would otherwise show a hole for today.
   * - Previous days are fetched from data/history/<date>.json. A
   *   missing file (gap in the archive, a day the pipeline failed to
   *   publish, etc.) is silently skipped rather than padded — the
   *   returned series can therefore have fewer than `days` points.
   *   Callers must not assume a fixed length.
   * - This function requires no maintenance as new days are published:
   *   each call recomputes the window relative to the current date, so
   *   it keeps sliding forward automatically after every automated
   *   release.
   *
   * Returns a map: { [systemId]: [{ date, condition }, ...] }, oldest
   * first, sorted chronologically, with today's point (if the system
   * exists in weather.json) always last.
   */
  async function loadHistory(days = 7) {
    const data = await load();
    const anchorDate = data && data.generated_at ? new Date(data.generated_at) : new Date();

    const datesToFetch = [];
    for (let i = days - 1; i >= 1; i--) {
      const d = new Date(anchorDate);
      d.setDate(d.getDate() - i);
      datesToFetch.push(formatDateISO(d));
    }

    const fetchedDays = await Promise.all(
      datesToFetch.map((iso) =>
        fetchJson("./data/history/" + iso + ".json").catch(() => null)
      )
    );

    const historyBySystem = {};

    fetchedDays.forEach((dayData, idx) => {
      if (!dayData) {
        return;
      }

      const iso = datesToFetch[idx];

      (dayData.systems || []).forEach((system) => {
        if (!historyBySystem[system.id]) {
          historyBySystem[system.id] = [];
        }

        historyBySystem[system.id].push({
          date: iso,
          condition: system.condition
        });
      });
    });

    const todayIso = formatDateISO(anchorDate);

    (data.systems || []).forEach((system) => {
      if (!historyBySystem[system.id]) {
        historyBySystem[system.id] = [];
      }

      historyBySystem[system.id].push({
        date: todayIso,
        condition: system.condition
      });
    });

    return historyBySystem;
  }

  /**
   * Convenience accessor: the trend series for a single system id,
   * or an empty array if none was loaded/found.
   */
  function getSystemHistory(historyMap, systemId) {
    return (historyMap && historyMap[systemId]) || [];
  }

  /**
   * Read a query-string parameter from the current URL.
   */
  function getQueryParam(name) {
    return new URLSearchParams(window.location.search).get(name);
  }

  /**
   * Resolve which system a widget should display from the current URL.
   *
   * Priority:
   *   1. ?system=<id>
   *   2. ?provider=<provider name>
   *
   * ?system= is the durable identifier and should be preferred once a
   * provider exposes more than one observed model.
   */
  function resolveSystemFromQuery(data) {
    const systems = (data && data.systems) || [];

    const systemId = getQueryParam("system");

    if (systemId) {
      const bySystem = systems.find((system) => system.id === systemId);

      if (bySystem) {
        return bySystem;
      }
    }

    const providerName = getQueryParam("provider");

    if (providerName) {
      const needle = providerName.toLowerCase();

      const byProvider = systems.find((system) => {
        return (system.provider || "").toLowerCase() === needle;
      });

      if (byProvider) {
        return byProvider;
      }
    }

    return null;
  }

  /**
   * Load public panel configuration.
   *
   * Panel configuration changes less frequently than weather.json,
   * so normal browser caching is acceptable here.
   *
   * `sourceOverride` (optional), same purpose and same zero-effect-on-
   * production guarantee as load()'s: dev/shadow test harnesses only.
   */
  async function loadPanels(sourceOverride) {
    return fetchJson(sourceOverride || "./config/panels.json");
  }

  /**
   * Resolve an ordered list of system objects for a named panel
   * ("core", "full", ...), following the order defined in
   * config/panels.json.
   *
   * Unknown ids are silently skipped so a stale panel definition does
   * not break the page.
   */
  function getPanelSystems(data, panelIds) {
    const systems = (data && data.systems) || [];

    return (panelIds || [])
      .map((id) => systems.find((system) => system.id === id))
      .filter(Boolean);
  }

  /**
   * Public identity boundary.
   *
   * POLICY v0.3 (2026-08-24)
   *
   * The public brand name is the primary public identity again.
   *
   * Example:
   *
   *   ChatGPT
   *   Claude
   *   Gemini
   *   Grok
   *
   * This reverts POLICY v0.2's technical-first preference (which showed
   * raw model identifiers such as gpt-4o-2024-11-20 as the primary
   * label). The technical identifier remains available on click/detail
   * view — it is simply no longer the first thing shown on the card.
   *
   * Priority:
   *
   *   1. system.model_display
   *   2. system.model_public
   *   3. system.public_label
   *   4. system.model
   *
   * Provider identity remains available separately for accessibility,
   * metadata and contextual rendering.
   */
  function getPublicIdentity(system) {
    const provider =
      (system &&
        (system.provider_display ||
          system.provider)) ||
      "";

    let label = null;

    if (system) {
      if (system.model_display) {
        label = system.model_display;
      } else if (
        system.model_public !== undefined &&
        system.model_public !== null
      ) {
        label = system.model_public;
      } else if (system.public_label) {
        label = system.public_label;
      } else if (system.model) {
        label = system.model;
      }
    }

    return {
      provider,
      label
    };
  }

  /**
   * Clear the in-page weather cache.
   *
   * Mainly useful for future live-refresh controls or debugging.
   */
  function clearCache() {
    cached = null;
  }

  /**
   * AI Weather V2 — longitudinal state resolution (additive, Bloc Samedi).
   *
   * Widgets historically colored themselves from system.condition, which
   * reflects the DAILY question only. V2 makes the longitudinal reference
   * (system.longitudinal.current_longitudinal_state) the sole source of
   * authority for the status shown. This function is the single place
   * that resolves which one a widget should actually display, so all 14
   * widget formats read the same logic instead of re-implementing it.
   *
   * Today, public weather.json/data/current.json never carry
   * system.longitudinal.current_longitudinal_state (that field only
   * exists in the shadow V2 pipeline's own output, data/shadow/v2/*.json).
   * So against real production data this function always falls through
   * to the legacy branch below and returns exactly what system.condition
   * already meant — this is what makes the widget migration provably
   * zero-impact today, while making widgets ready the day the public
   * source is actually switched over.
   *
   * Returns:
   *   {
   *     key: "standard" | "attention_accrue" | "attention_renforcee" |
   *          "attention_critique" | "insufficient_data" | "baseline_window" |
   *          "unknown",
   *     source: "v2" | "legacy",
   *     insufficientCoverage: boolean,
   *     identityUncertain: boolean,
   *     hasActiveEventToday: boolean
   *   }
   */
  function getLongitudinalStateInfo(system, todayIso) {
    const longitudinal = system && system.longitudinal;

    // current_longitudinal_state is an object ({ state, deviation_index,
    // uncertainty, as_of }), not a plain string — matches the real shape
    // written by longitudinal_v2_bridge.ps1 into data/shadow/v2/*.json.
    const stateObj = longitudinal && longitudinal.current_longitudinal_state;
    const stateKey = stateObj && typeof stateObj === "object" ? stateObj.state : null;
    const hasV2State = typeof stateKey === "string";

    if (hasV2State) {
      const events = Array.isArray(longitudinal.detected_events)
        ? longitudinal.detected_events
        : [];
      const hasActiveEventToday =
        !!todayIso &&
        events.some(
          (e) => e && e.date === todayIso && e.type !== "model_identity_unverified"
        );

      return {
        key: stateKey,
        source: "v2",
        insufficientCoverage: stateKey === "insufficient_data",
        identityUncertain: !!(
          longitudinal.system_identity && longitudinal.system_identity.uncertain
        ),
        hasActiveEventToday
      };
    }

    // Legacy fallback: system.condition is the only signal available.
    // Mapped to the V2 vocabulary so callers never need two code paths.
    const LEGACY_TO_V2 = {
      clear: "standard",
      watch: "attention_accrue",
      unsettled: "attention_renforcee",
      alert: "attention_critique"
    };

    return {
      key: LEGACY_TO_V2[system && system.condition] || "unknown",
      source: "legacy",
      insufficientCoverage: false,
      identityUncertain: false,
      hasActiveEventToday: false
    };
  }

  /**
   * Convenience wrapper for widgets: resolves getLongitudinalStateInfo()
   * straight down to the widget's existing 4-color CSS vocabulary
   * (clear/watch/unsettled/alert), plus a 5th "insufficient" bucket for
   * the coverage-insufficient case, which no legacy widget CSS had a
   * class for. A widget that adds an ".is-insufficient" style is ready
   * for that case; one that doesn't yet will simply render the dot
   * without one of the four known colors rather than crash.
   */
  function getDisplayCondition(system, todayIso) {
    const info = getLongitudinalStateInfo(system, todayIso);

    const V2_TO_DISPLAY = {
      standard: "clear",
      attention_accrue: "watch",
      attention_renforcee: "unsettled",
      attention_critique: "alert",
      insufficient_data: "insufficient",
      baseline_window: "insufficient",
      unknown: (system && system.condition) || "insufficient"
    };

    return V2_TO_DISPLAY[info.key] || (system && system.condition) || "insufficient";
  }

  /**
   * Public API exposed to the rest of the frontend.
   */
  window.NMData = {
    load,
    clearCache,
    resolveSystemFromQuery,
    getQueryParam,
    loadPanels,
    getPanelSystems,
    getPublicIdentity,
    loadHistory,
    getSystemHistory,
    getLongitudinalStateInfo,
    getDisplayCondition
  };
})(window);
