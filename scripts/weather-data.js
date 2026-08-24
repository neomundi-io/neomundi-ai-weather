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
   */
  async function load() {
    if (cached) {
      return cached;
    }

    const livePath = "./weather.json?v=" + Date.now();

    cached = await fetchJson(livePath, {
      cache: "no-store"
    });

    return cached;
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
   */
  async function loadPanels() {
    return fetchJson("./config/panels.json");
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
   * Public API exposed to the rest of the frontend.
   */
  window.NMData = {
    load,
    clearCache,
    resolveSystemFromQuery,
    getQueryParam,
    loadPanels,
    getPanelSystems,
    getPublicIdentity
  };
})(window);
