/**
 * NeoMundi US Station — local bootstrap.
 *
 * This file is NEW, written for this local integration — it is not part
 * of the original "US Station Edition" capture. The capture's own page
 * controller ("us-station-page.js") imports a module,
 * "us-station-tomorrow.js", that was not included in the locally
 * supplied capture. Rather than guess at that missing module, this
 * bootstrap wires only the two REAL, INTACT modules that were supplied —
 * us-station-data.js (window.NMUSStation) and us-station-globe.js
 * (window.USStationGlobe) — together with this repo's own real
 * scripts/weather-data.js (window.NMData), for the artwork's "present"
 * state: the globe, city selection, the real per-city physical weather
 * (openmeteo), the real measured AI Weather condition for the day
 * (this repo's own weather.json / aiweather-capsule), and the real
 * live camera embed for the selected city.
 *
 * The "+24h projected" temporal state is intentionally left inert (its
 * button is disabled) because it depends on the missing module — no
 * projected value is simulated here.
 */
(function () {
  "use strict";

  function query(sel, root) { return (root || document).querySelector(sel); }

  var body = document.body;
  var canvas = query("#us-globe");
  var artwork = query("[data-artwork]");
  var backBtn = query("[data-back]");
  var nextStateBtn = query("[data-next-state]");
  var liveFrame = query("[data-live-frame]");
  var sourceLink = query("[data-source-link]");
  var sourceStateStrong = query("[data-source-state] strong");
  var hoverLabel = query("[data-hover-label]");

  var observationPromise = null;
  function getObservation() {
    if (!observationPromise) {
      observationPromise = window.NMUSStation.load().catch(function () { return null; });
    }
    return observationPromise;
  }

  function setText(sel, value) {
    var el = query(sel);
    if (el) el.textContent = value;
  }

  function fmtMetric(value, unit, decimals) {
    if (value === null || value === undefined || !isFinite(value)) return "—";
    var factor = Math.pow(10, decimals || 0);
    var n = Math.round(value * factor) / factor;
    return n + unit;
  }

  function renderArtwork(city) {
    setText("[data-city-title]", city.name);
    setText("[data-work-subtitle]", "Current city weather");
    setText("[data-artwork-mode-label]", "Live city weather");
    if (artwork) artwork.dataset.city = city.id;

    if (sourceStateStrong) sourceStateStrong.textContent = (city.live && city.live.title) || city.name + " — live";
    if (sourceLink) {
      if (city.live && city.live.sourceUrl) sourceLink.setAttribute("href", city.live.sourceUrl);
      else sourceLink.removeAttribute("href");
    }

    var embedUrl = window.NMUSStation.cameraEmbed(city);
    if (liveFrame) {
      if (embedUrl) liveFrame.setAttribute("src", embedUrl);
      else liveFrame.removeAttribute("src");
    }

    setText("[data-city-time]", window.NMUSStation.formatObservedAt(null, city.timeZone, false));
    setText("[data-meta-temporal]", "Present");
    setText("[data-meta-visibility]", "100%");

    Promise.all([
      window.NMUSStation.loadCityWeather(city),
      getObservation()
    ]).then(function (results) {
      var cityWeather = results[0];
      var observation = results[1];
      var physical = cityWeather && cityWeather.current;

      if (physical) {
        setText("[data-meta-temperature]", fmtMetric(physical.temperature, " °C", 1));
        setText("[data-meta-apparent]", fmtMetric(physical.apparentTemperature, " °C perceived", 1));
        setText("[data-meta-precipitation]", fmtMetric(physical.precipitation, " mm", 1));
        setText("[data-meta-wind]", fmtMetric(physical.windGust || physical.wind, " km/h gust", 1));
        setText("[data-meta-cloud]", fmtMetric(physical.cloudCover, "%", 0));
        setText("[data-meta-physical]", physical.label || "—");
      }

      if (observation) {
        setText("[data-meta-condition]", observation.conditionCopy.label);
        setText("[data-meta-demand]", observation.judgmentDemand.level + " · " + observation.judgmentDemand.meaning);
        setText("[data-meta-stability]", observation.score === null ? "—" : String(observation.score));

        var panel = observation.panelField || {};
        setText("[data-meta-shift]", (panel.watch + panel.unsettled + panel.alert) + " shifted / " + panel.systems + " systems");
        setText("[data-meta-density]", observation.coverage.observations + " / " + observation.coverage.expected + " observations");

        var dist = [
          panel.clear ? panel.clear + " Clear" : null,
          panel.watch ? panel.watch + " Watch" : null,
          panel.unsettled ? panel.unsettled + " Unsettled" : null,
          panel.alert ? panel.alert + " Alert" : null
        ].filter(Boolean).join(" · ");
        setText("[data-meta-coherence]", dist || "—");
        setText("[data-meta-observed]", window.NMUSStation.formatObservedAt(observation.observedAt, city.timeZone, false));
        setText("[data-meta-protocol]", observation.protocol.id + " " + observation.protocol.version);

        if (physical) {
          var lines = window.NMUSStation.composeDescription(city, physical, observation, false);
          var descEl = query("[data-description]");
          if (descEl) descEl.innerHTML = lines.map(function (line) { return "<p>" + line + "</p>"; }).join("");
        }

        if (observation.interoperability) {
          var jsonEl = query("[data-machine-json]");
          var statusEl = query("[data-machine-status]");
          if (jsonEl) {
            jsonEl.hidden = false;
            jsonEl.textContent = JSON.stringify(observation.interoperability, null, 2);
          }
          if (statusEl) statusEl.textContent = "Source-issued interoperability object, passed through unchanged.";
        }
      }
    });
  }

  function openCity(city) {
    if (!city || !artwork) return;
    renderArtwork(city);
    body.classList.add("is-artwork-open");
    artwork.setAttribute("aria-hidden", "false");
  }

  function closeArtwork() {
    body.classList.remove("is-artwork-open");
    if (artwork) artwork.setAttribute("aria-hidden", "true");
    if (liveFrame) liveFrame.removeAttribute("src");
  }

  function hoverCity(city) {
    if (!hoverLabel) return;
    var strong = hoverLabel.querySelector("strong");
    if (city) {
      if (strong) strong.textContent = city.name;
      hoverLabel.classList.add("is-visible");
    } else {
      hoverLabel.classList.remove("is-visible");
    }
  }

  if (backBtn) backBtn.addEventListener("click", closeArtwork);
  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape" && body.classList.contains("is-artwork-open")) closeArtwork();
  });

  if (nextStateBtn) {
    nextStateBtn.setAttribute("disabled", "disabled");
    nextStateBtn.setAttribute("aria-disabled", "true");
    nextStateBtn.title = "Projected +24h state — not available in this local build (its source module was not part of the supplied capture)";
  }

  if (canvas && window.USStationGlobe && window.NMUSStation) {
    try {
      new window.USStationGlobe(canvas, {
        cities: window.NMUSStation.cities,
        onSelect: openCity,
        onHover: hoverCity,
        topologyUrl: "@@THEME@@/assets/station/us-station-earth-topo.json"
      });
    } catch (error) {
      body.classList.add("has-globe-fallback");
    }
  }
})();
