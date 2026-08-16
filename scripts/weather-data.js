/**
 * NeoMundi AI Weather — shared data access.
 *
 * Single source of truth: every widget format (wall, topbar, sidebar,
 * provider widget) reads through this module instead of fetching or
 * parsing weather.json independently. Nothing here is hardcoded per
 * widget — a change in weather.json is automatically visible everywhere.
 */
(function (window) {
  "use strict";

  let cached = null;

  function fetchJson(path) {
    return fetch(path).then(r => {
      if (!r.ok) throw new Error("Failed to load " + path);
      return r.json();
    });
  }

  async function load() {
    if (cached) return cached;
    cached = await fetchJson("./weather.json");
    return cached;
  }

  function getQueryParam(name) {
    return new URLSearchParams(window.location.search).get(name);
  }

  /**
   * Resolve which system a widget should display, from the current URL.
   * Priority: ?system=<id>  >  ?provider=<name, case-insensitive match>.
   * ?system= is the durable identifier and should be preferred once a
   * provider ships more than one observed model.
   */
  function resolveSystemFromQuery(data) {
    const systems = (data && data.systems) || [];
    const systemId = getQueryParam("system");
    if (systemId) {
      const bySystem = systems.find(s => s.id === systemId);
      if (bySystem) return bySystem;
    }

    const providerName = getQueryParam("provider");
    if (providerName) {
      const needle = providerName.toLowerCase();
      const byProvider = systems.find(s => (s.provider || "").toLowerCase() === needle);
      if (byProvider) return byProvider;
    }

    return null;
  }

  async function loadPanels() {
    return fetchJson("./config/panels.json");
  }

  /**
   * Resolve an ordered list of system objects for a named panel
   * ("core", "full", ...), following the order defined in
   * config/panels.json. Unknown ids are silently skipped rather than
   * throwing, so a stale panel config never breaks a page.
   */
  function getPanelSystems(data, panelIds) {
    const systems = (data && data.systems) || [];
    return (panelIds || [])
      .map(id => systems.find(s => s.id === id))
      .filter(Boolean);
  }

  /**
   * The desidentification boundary. Public-facing widgets that must not
   * leak an internal model identifier call this instead of reading
   * system.model directly. Only explicitly public-labeled fields
   * (model_public, public_label) are ever returned — if neither is set,
   * label is null and the caller must not fall back to system.model.
   */
  function getPublicIdentity(system) {
    const provider = (system && (system.provider_display || system.provider)) || "";
    let label = null;
    if (system) {
      if (system.model_public !== undefined && system.model_public !== null) {
        label = system.model_public;
      } else if (system.public_label) {
        label = system.public_label;
      }
    }
    return { provider, label };
  }

  window.NMData = { load, resolveSystemFromQuery, getQueryParam, loadPanels, getPanelSystems, getPublicIdentity };
})(window);
