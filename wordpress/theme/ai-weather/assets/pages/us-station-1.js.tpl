/**
 * NeoMundi US Station Edition — presentation adapter.
 *
 * The canonical observation remains weather.json. The capsule is loaded only
 * as provenance. This adapter never changes measurement values and never
 * invents an interoperability schema. If a signed machine-readable object is
 * added to a future observation, the existing object is passed through.
 *
 * Local copy, adapted 2026-09-12 from the production build
 * (neomundi-ai-weather-production.up.railway.app/us-station.html) so this
 * experimental page can read this repo's own weather.json/capsules — only
 * the "./aiweather-capsule" paths were rewritten to "../aiweather-capsule"
 * (one directory up). No other line was changed.
 */
(function (window) {
  "use strict";

  const CONDITION_COPY = Object.freeze({
    clear: {
      label: "Clear",
      field: "stability across the measured field",
      tone: "quiet"
    },
    watch: {
      label: "Watch",
      field: "attention gathering across the measured field",
      tone: "attentive"
    },
    unsettled: {
      label: "Unsettled",
      field: "variation moving through the measured field",
      tone: "variable"
    },
    alert: {
      label: "Alert",
      field: "heightened attention across the measured field",
      tone: "heightened"
    },
    insufficient_data: {
      label: "Not assessed",
      field: "insufficient coverage across the measured field",
      tone: "unresolved"
    }
  });

  /**
   * Display aliases preserve the source metric and value. Aliases for signals
   * not present in today's AI Weather payload are registered for future use,
   * but are never rendered until the real field exists.
   */
  const SIGNAL_ALIASES = Object.freeze({
    global_condition: {
      label: "Weather state",
      meaning: "Observed aggregate AI Weather condition"
    },
    global_score: {
      label: "Weather index",
      meaning: "Legacy aggregate observation index; not a quality ranking"
    },
    "global_judgment_demand.level": {
      label: "Judgment demand",
      meaning: "Attention level derived from the observed condition"
    },
    "coverage.panel_coverage": {
      label: "Signal coverage",
      meaning: "Covered fraction of the declared observation panel"
    },
    "coverage.total_observations": {
      label: "Observations",
      meaning: "Completed observations in the current capsule"
    },
    protocol: {
      label: "Protocol",
      meaning: "Versioned measurement protocol"
    },
    stability_score: {
      label: "Atmospheric stability",
      meaning: "NeoMundi stability score"
    },
    delta_g: {
      label: "Weather shift",
      meaning: "Variation or transition in stability over time"
    },
    esi: {
      label: "Weather stability",
      meaning: "Composite Energy Stability Index"
    },
    informational_density: {
      label: "Signal density",
      meaning: "NeoMundi informational density"
    },
    informational_energy: {
      label: "Energy",
      meaning: "NeoMundi informational energy"
    },
    coherence_score: {
      label: "Coherence",
      meaning: "NeoMundi semantic coherence score"
    },
    semantic_variability_signal: {
      label: "Variability",
      meaning: "NeoMundi semantic variability signal"
    },
    factual_validity_signal: {
      label: "Visibility",
      meaning: "NeoMundi factual-validity signal"
    },
    risk_signal: {
      label: "Weather watch",
      meaning: "NeoMundi bounded risk signal"
    }
  });

  const CITIES = Object.freeze([
    {
      id: "tokyo",
      name: "Tokyo",
      country: "Japan",
      lat: 35.6762,
      lon: 139.6503,
      timeZone: "Asia/Tokyo",
      movement: "Pedestrians and traffic continue beneath compressed lines of light.",
      live: {
        provider: "YouTube",
        videoId: "8H3nRCFVR6Y",
        title: "Shibuya Scramble Crossing — ANN live camera",
        sourceUrl: "https://www.youtube.com/watch?v=8H3nRCFVR6Y"
      }
    },
    {
      id: "seoul",
      name: "Seoul",
      country: "South Korea",
      lat: 37.5665,
      lon: 126.978,
      timeZone: "Asia/Seoul",
      movement: "The river holds the horizon while the city crosses it in continuous bands.",
      live: {
        provider: "YouTube",
        videoId: "5gVrWGRZo9s",
        title: "Han River — Seoul 4K live",
        sourceUrl: "https://www.youtube.com/watch?v=5gVrWGRZo9s"
      }
    },
    {
      id: "san-francisco",
      name: "San Francisco",
      country: "United States",
      lat: 37.7749,
      lon: -122.4194,
      timeZone: "America/Los_Angeles",
      movement: "Aircraft, water and traffic divide the bay into separate velocities.",
      live: {
        provider: "YouTube",
        videoId: "wdFQvKAlyA4",
        title: "San Francisco Bay airfield live observation",
        sourceUrl: "https://www.youtube.com/watch?v=wdFQvKAlyA4"
      }
    },
    {
      id: "paris",
      name: "Paris",
      country: "France",
      lat: 48.8566,
      lon: 2.3522,
      timeZone: "Europe/Paris",
      movement: "The city keeps its measured pace as streets fold around the river.",
      live: {
        provider: "YouTube",
        videoId: "OzYp4NRZlwQ",
        title: "Palais d'Iena — Paris live camera",
        sourceUrl: "https://www.youtube.com/watch?v=OzYp4NRZlwQ"
      }
    },
    {
      id: "new-york",
      name: "New York",
      country: "United States",
      lat: 40.7128,
      lon: -74.006,
      timeZone: "America/New_York",
      movement: "Crowds and screens exchange attention without resolving into stillness.",
      live: {
        provider: "YouTube",
        videoId: "JQ_jwk_7OVE",
        title: "Times Square North — EarthCam live",
        sourceUrl: "https://www.youtube.com/watch?v=JQ_jwk_7OVE"
      }
    },
    {
      id: "london",
      name: "London",
      country: "United Kingdom",
      lat: 51.5074,
      lon: -0.1278,
      timeZone: "Europe/London",
      movement: "Crossings open and close while the city maintains its layered rhythm.",
      live: {
        provider: "YouTube",
        videoId: "zMCea32gpmg",
        title: "Abbey Road crossing — EarthCam live",
        sourceUrl: "https://www.youtube.com/watch?v=zMCea32gpmg"
      }
    },
    {
      id: "sydney",
      name: "Sydney",
      country: "Australia",
      lat: -33.8688,
      lon: 151.2093,
      timeZone: "Australia/Sydney",
      movement: "Harbour traffic moves between fixed architecture and an unstable surface.",
      live: {
        provider: "YouTube",
        videoId: "5uZa3-RMFos",
        title: "Sydney Harbour 24/7 live",
        sourceUrl: "https://www.youtube.com/watch?v=5uZa3-RMFos"
      }
    },
    {
      id: "prague",
      name: "Prague",
      country: "Czech Republic",
      lat: 50.0755,
      lon: 14.4378,
      timeZone: "Europe/Prague",
      movement: "Stone, tram lines and pedestrian routes converge through the old city field.",
      live: {
        provider: "YouTube",
        videoId: "0FvTdT3EJY4",
        title: "Prague — SkylineWebcams live camera",
        sourceUrl: "https://www.youtube.com/watch?v=0FvTdT3EJY4"
      }
    },
    {
      id: "reykjavik",
      name: "Reykjavik",
      country: "Iceland",
      lat: 64.1466,
      lon: -21.9426,
      timeZone: "Atlantic/Reykjavik",
      movement: "Low northern light exposes each shift in cloud, surface and visibility.",
      live: {
        provider: "YouTube",
        videoId: "tYgGEC-ESTw",
        title: "Reykjavik — Our World Live camera",
        sourceUrl: "https://www.youtube.com/watch?v=tYgGEC-ESTw"
      }
    },
    {
      id: "istanbul",
      name: "Istanbul",
      country: "Turkey",
      lat: 41.0082,
      lon: 28.9784,
      timeZone: "Europe/Istanbul",
      movement: "Water, bridges and public squares exchange movement across two continental edges.",
      live: {
        provider: "YouTube",
        videoId: "0xFW3MBtpVE",
        title: "Istanbul municipal camera rotation — live",
        sourceUrl: "https://www.youtube.com/watch?v=0xFW3MBtpVE"
      }
    },
    {
      id: "dubai",
      name: "Dubai",
      country: "United Arab Emirates",
      lat: 25.2048,
      lon: 55.2708,
      timeZone: "Asia/Dubai",
      movement: "Heat, haze and vertical surfaces make atmospheric distance physically legible.",
      live: {
        provider: "YouTube",
        videoId: "MgqAn_JYqDQ",
        title: "Dubai — SkylineWebcams live camera",
        sourceUrl: "https://www.youtube.com/watch?v=MgqAn_JYqDQ"
      }
    },
    {
      id: "rome",
      name: "Rome",
      country: "Italy",
      lat: 41.9028,
      lon: 12.4964,
      timeZone: "Europe/Rome",
      movement: "The Vatican horizon holds architecture still while atmosphere moves through the frame.",
      live: {
        provider: "YouTube",
        videoId: "89d3tEaqImM",
        title: "Rome and Vatican skyline — RealViewCam360 live",
        sourceUrl: "https://www.youtube.com/watch?v=89d3tEaqImM"
      }
    },
    {
      id: "amsterdam",
      name: "Amsterdam",
      country: "Netherlands",
      lat: 52.3676,
      lon: 4.9041,
      timeZone: "Europe/Amsterdam",
      movement: "Cyclists, trams and canal weather cross the same compact field at different speeds.",
      live: {
        provider: "YouTube",
        videoId: "Gd9d4q6WvUY",
        title: "Dam Square — Now4Rent live camera",
        sourceUrl: "https://www.youtube.com/watch?v=Gd9d4q6WvUY"
      }
    },
    {
      id: "berlin",
      name: "Berlin",
      country: "Germany",
      lat: 52.52,
      lon: 13.405,
      timeZone: "Europe/Berlin",
      movement: "Traffic and pedestrians cut measured lines across the Frankfurter Tor axis.",
      live: {
        provider: "YouTube",
        videoId: "_pJAwwlzM7I",
        title: "Frankfurter Tor and Karl-Marx-Allee — Berlin live",
        sourceUrl: "https://www.youtube.com/watch?v=_pJAwwlzM7I"
      }
    },
    {
      id: "singapore",
      name: "Singapore",
      country: "Singapore",
      lat: 1.3521,
      lon: 103.8198,
      timeZone: "Asia/Singapore",
      movement: "Tropical humidity softens the distance between towers, water and moving traffic.",
      live: {
        provider: "YouTube",
        videoId: "p39VVXzGdwI",
        title: "Downtown Singapore — live camera",
        sourceUrl: "https://www.youtube.com/watch?v=p39VVXzGdwI"
      }
    },
    {
      id: "bangkok",
      name: "Bangkok",
      country: "Thailand",
      lat: 13.7563,
      lon: 100.5018,
      timeZone: "Asia/Bangkok",
      movement: "Street heat, rain and continuous traffic remain visible at pedestrian scale.",
      live: {
        provider: "YouTube",
        videoId: "UemFRPrl1hk",
        title: "Sukhumvit Road — Bangkok live street camera",
        sourceUrl: "https://www.youtube.com/watch?v=UemFRPrl1hk"
      }
    },
    {
      id: "toronto",
      name: "Toronto",
      country: "Canada",
      lat: 43.6532,
      lon: -79.3832,
      timeZone: "America/Toronto",
      movement: "Rail, expressway and lake weather form a layered metropolitan transit signal.",
      live: {
        provider: "YouTube",
        videoId: "HongS1sx4pY",
        title: "Toronto rail and Gardiner traffic hub — 4K live",
        sourceUrl: "https://www.youtube.com/watch?v=HongS1sx4pY"
      }
    },
    {
      id: "buenos-aires",
      name: "Buenos Aires",
      country: "Argentina",
      lat: -34.6037,
      lon: -58.3816,
      timeZone: "America/Argentina/Buenos_Aires",
      movement: "Street traffic and changing light register weather across the city's long horizontal avenues.",
      live: {
        provider: "YouTube",
        videoId: "urwuIKd8eEo",
        title: "Buenos Aires street, traffic and weather — live",
        sourceUrl: "https://www.youtube.com/watch?v=urwuIKd8eEo"
      }
    },
    {
      id: "auckland",
      name: "Auckland",
      country: "New Zealand",
      lat: -36.8509,
      lon: 174.7645,
      timeZone: "Pacific/Auckland",
      movement: "Harbour traffic, low cloud and the skyline expose the city's maritime weather boundary.",
      live: {
        provider: "YouTube",
        videoId: "PaLDpyFxpXE",
        title: "Auckland harbour and skyline — 4K live",
        sourceUrl: "https://www.youtube.com/watch?v=PaLDpyFxpXE"
      }
    }
  ]);

  const WMO = Object.freeze({
    0: ["Clear", "open"],
    1: ["Mostly clear", "open"],
    2: ["Partly clouded", "clouded"],
    3: ["Overcast", "clouded"],
    45: ["Fog", "veiled"],
    48: ["Rime fog", "veiled"],
    51: ["Light drizzle", "rain"],
    53: ["Drizzle", "rain"],
    55: ["Dense drizzle", "rain"],
    61: ["Light rain", "rain"],
    63: ["Rain", "rain"],
    65: ["Heavy rain", "storm"],
    71: ["Light snow", "snow"],
    73: ["Snow", "snow"],
    75: ["Heavy snow", "snow"],
    80: ["Rain showers", "rain"],
    81: ["Rain showers", "rain"],
    82: ["Heavy showers", "storm"],
    95: ["Thunderstorm", "storm"],
    96: ["Thunderstorm with hail", "storm"],
    99: ["Severe thunderstorm", "storm"]
  });

  function readPath(value, path) {
    return path.split(".").reduce((current, key) => {
      return current && current[key] !== undefined ? current[key] : undefined;
    }, value);
  }

  function resolveCapsulePath(reference) {
    const value = String(reference || "").trim();
    if (!value) {
      return null;
    }
    if (/^https?:\/\//i.test(value)) {
      return value;
    }
    if (value.startsWith("/capsules/")) {
      return "../aiweather-capsule" + value;
    }
    if (value.startsWith("capsules/")) {
      return "@@RUNTIME@@/aiweather-capsule/" + value;
    }
    return value;
  }

  async function fetchJson(path, options) {
    const response = await fetch(path, { cache: "no-store", ...(options || {}) });
    if (!response.ok) {
      throw new Error("Unable to load " + path);
    }
    return response.json();
  }

  async function loadCapsule() {
    try {
      const latest = await fetchJson("@@RUNTIME@@/aiweather-capsule/latest.json?v=" + Date.now());
      const path = resolveCapsulePath(latest && latest.latest);
      return path ? await fetchJson(path + "?v=" + Date.now()) : null;
    } catch (error) {
      return null;
    }
  }

  function findInteroperabilityObject(weather, capsule) {
    const keys = [
      "interoperability",
      "interoperability_json",
      "machine_readable_object",
      "measurement_contract"
    ];
    const sources = [capsule, weather];
    for (const source of sources) {
      for (const key of keys) {
        if (source && source[key] && typeof source[key] === "object") {
          return {
            available: true,
            sourceKey: key,
            value: source[key]
          };
        }
      }
    }
    return {
      available: false,
      sourceKey: null,
      value: null
    };
  }

  function normalizedCoverage(weather, capsule) {
    const capsuleCoverage = (capsule && capsule.coverage) || {};
    const panel = (weather && weather.panel_summary) || {};
    return {
      panel: Number(
        capsuleCoverage.panel_coverage !== undefined
          ? capsuleCoverage.panel_coverage
          : panel.panel_coverage || 0
      ),
      observations: Number(
        capsuleCoverage.total_observations !== undefined
          ? capsuleCoverage.total_observations
          : panel.total_observations || 0
      ),
      expected: Number(
        capsuleCoverage.total_expected_observations !== undefined
          ? capsuleCoverage.total_expected_observations
          : panel.total_expected_observations || 0
      )
    };
  }

  function normalizeObservation(weather, capsule) {
    const coverage = normalizedCoverage(weather, capsule);
    const panel = (weather && weather.panel_summary) || {};
    const condition = String(
      (capsule && capsule.global_condition) || weather.global_condition || "insufficient_data"
    ).toLowerCase();
    const demand =
      (capsule && capsule.global_judgment_demand) ||
      weather.global_judgment_demand ||
      {};
    const protocol = (capsule && capsule.protocol) || weather.protocol || {};
    const score =
      capsule && capsule.legacy_global_score !== undefined
        ? capsule.legacy_global_score
        : weather.global_score;
    const observedAt =
      (capsule && (capsule.issued_at || capsule.date)) ||
      weather.generated_at ||
      null;

    return {
      condition,
      conditionCopy: CONDITION_COPY[condition] || CONDITION_COPY.insufficient_data,
      score: score === null || score === undefined ? null : Number(score),
      judgmentDemand: {
        level: String(demand.level || "—"),
        label: String(demand.label || "not_determined"),
        meaning: String(demand.meaning || "Not determined")
      },
      coverage,
      panelField: {
        systems: Number(panel.systems_count || 0),
        expected: Number(panel.systems_expected || 0),
        clear: Number(panel.systems_clear || 0),
        watch: Number(panel.systems_watch || 0),
        unsettled: Number(panel.systems_unsettled || 0),
        alert: Number(panel.systems_alert || 0),
        unresolved: Number(panel.systems_insufficient_data || 0)
      },
      protocol: {
        id: String(protocol.id || "AI WEATHER"),
        version: String(protocol.version || "—")
      },
      observedAt,
      capsuleId: String((capsule && capsule.capsule_id) || "current-observation"),
      sourceSchema: String((capsule && capsule.schema_version) || "weather.json"),
      systems: Array.isArray(weather.systems) ? weather.systems : [],
      interoperability: findInteroperabilityObject(weather, capsule),
      raw: { weather, capsule }
    };
  }

  async function load() {
    if (!window.NMData || typeof window.NMData.load !== "function") {
      throw new Error("NMData is required before US Station data can load");
    }
    const weather = await window.NMData.load();
    const capsule = await loadCapsule();
    return normalizeObservation(weather, capsule);
  }

  function weatherCode(code) {
    const numeric = code === null || code === undefined || code === "" ? NaN : Number(code);
    const pair = WMO[numeric] || ["Atmospheric variation", "variable"];
    return { label: pair[0], tone: pair[1], baseTone: pair[1], code: numeric };
  }

  function finite(value) {
    if (value === null || value === undefined || value === "") return null;
    const numeric = Number(value);
    return Number.isFinite(numeric) ? numeric : null;
  }

  function at(values, index) {
    return Array.isArray(values) ? finite(values[index]) : null;
  }

  function clamp01(value) {
    return Math.max(0, Math.min(1, Number(value) || 0));
  }

  function enrichWeather(base, metrics) {
    const temperature = finite(metrics.temperature);
    const apparentTemperature = finite(metrics.apparentTemperature);
    const precipitation = finite(metrics.precipitation) || 0;
    const rain = finite(metrics.rain) || 0;
    const showers = finite(metrics.showers) || 0;
    const snowfall = finite(metrics.snowfall) || 0;
    const precipitationProbability = finite(metrics.precipitationProbability);
    const wind = finite(metrics.wind);
    const windGust = finite(metrics.windGust);
    const cloudCover = finite(metrics.cloudCover);
    const thermalPeak = Math.max(
      temperature === null ? -Infinity : temperature,
      apparentTemperature === null ? -Infinity : apparentTemperature
    );
    const liquid = Math.max(precipitation, rain + showers);
    let tone = base.tone;

    if (snowfall >= 0.2 || base.tone === "snow") tone = "snow";
    else if (base.tone === "storm" || liquid >= 18 || (liquid >= 8 && (windGust || 0) >= 55)) tone = "storm";
    else if (base.tone === "rain" || liquid >= 0.5 || (showers >= 0.2 && (precipitationProbability || 0) >= 55)) tone = "rain";
    else if (thermalPeak >= 31) tone = "heat";
    else if ((windGust || wind || 0) >= 45) tone = "wind";
    else if ((cloudCover || 0) >= 78 && tone === "open") tone = "clouded";

    const intensityByTone = {
      storm: 0.72 + liquid / 45 + (windGust || 0) / 220,
      rain: 0.34 + liquid / 16 + (precipitationProbability || 0) / 260,
      snow: 0.42 + snowfall / 7,
      heat: 0.42 + Math.max(0, thermalPeak - 30) / 12,
      wind: 0.34 + (windGust || wind || 0) / 110,
      veiled: 0.72,
      clouded: 0.34 + (cloudCover || 0) / 180,
      open: 0.2,
      variable: 0.28
    };

    return {
      ...base,
      tone,
      intensity: clamp01(intensityByTone[tone] || 0.28),
      temperature,
      apparentTemperature,
      precipitation,
      rain,
      showers,
      snowfall,
      precipitationProbability,
      wind,
      windGust,
      cloudCover
    };
  }

  async function loadCityWeather(city) {
    const query = new URLSearchParams({
      latitude: String(city.lat),
      longitude: String(city.lon),
      current: "temperature_2m,apparent_temperature,weather_code,precipitation,rain,showers,snowfall,wind_speed_10m,wind_gusts_10m,cloud_cover",
      daily: "weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,precipitation_sum,rain_sum,showers_sum,snowfall_sum,precipitation_probability_max,wind_gusts_10m_max,cloud_cover_mean",
      timezone: city.timeZone,
      forecast_days: "3"
    });
    const controller = typeof AbortController === "function" ? new AbortController() : null;
    const timeout = controller ? window.setTimeout(() => controller.abort(), 8000) : 0;
    try {
      const payload = await fetchJson("https://api.open-meteo.com/v1/forecast?" + query, {
        ...(controller ? { signal: controller.signal } : {})
      });
      const currentCode = weatherCode(payload.current && payload.current.weather_code);
      const tomorrowCode = weatherCode(
        payload.daily && payload.daily.weather_code && payload.daily.weather_code[1]
      );
      const current = enrichWeather(currentCode, {
        temperature: payload.current && payload.current.temperature_2m,
        apparentTemperature: payload.current && payload.current.apparent_temperature,
        precipitation: payload.current && payload.current.precipitation,
        rain: payload.current && payload.current.rain,
        showers: payload.current && payload.current.showers,
        snowfall: payload.current && payload.current.snowfall,
        wind: payload.current && payload.current.wind_speed_10m,
        windGust: payload.current && payload.current.wind_gusts_10m,
        cloudCover: payload.current && payload.current.cloud_cover
      });
      const tomorrow = enrichWeather(tomorrowCode, {
        temperature: at(payload.daily && payload.daily.temperature_2m_max, 1),
        apparentTemperature: at(payload.daily && payload.daily.apparent_temperature_max, 1),
        precipitation: at(payload.daily && payload.daily.precipitation_sum, 1),
        rain: at(payload.daily && payload.daily.rain_sum, 1),
        showers: at(payload.daily && payload.daily.showers_sum, 1),
        snowfall: at(payload.daily && payload.daily.snowfall_sum, 1),
        precipitationProbability: at(payload.daily && payload.daily.precipitation_probability_max, 1),
        windGust: at(payload.daily && payload.daily.wind_gusts_10m_max, 1),
        cloudCover: at(payload.daily && payload.daily.cloud_cover_mean, 1)
      });
      return {
        available: true,
        timezone: payload.timezone || city.timeZone,
        current: {
          ...current,
          time: payload.current && payload.current.time,
          wind: current.wind
        },
        tomorrow: {
          ...tomorrow,
          date: payload.daily && payload.daily.time && payload.daily.time[1]
        }
      };
    } catch (error) {
      return {
        available: false,
        timezone: city.timeZone,
        current: weatherCode(null),
        tomorrow: weatherCode(null)
      };
    } finally {
      if (timeout) window.clearTimeout(timeout);
    }
  }

  function formatObservedAt(value, timeZone, projected) {
    const date = value ? new Date(value) : new Date();
    if (projected) {
      date.setDate(date.getDate() + 1);
    }
    try {
      return new Intl.DateTimeFormat("en-GB", {
        timeZone,
        day: "2-digit",
        month: "short",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
        timeZoneName: "short"
      })
        .format(date)
        .toUpperCase();
    } catch (error) {
      return date.toISOString().replace("T", " · ").slice(0, 16) + " UTC";
    }
  }

  function composeDescription(city, physical, observation, projected) {
    const state = physical || { label: "Atmospheric variation" };
    const metric = (value, suffix) => Number.isFinite(Number(value)) ? Math.round(Number(value) * 10) / 10 + suffix : null;
    const measurements = [
      metric(state.temperature, "°C"),
      metric(state.apparentTemperature, "°C perceived"),
      metric(state.precipitation, " mm precipitation"),
      metric(state.cloudCover, "% cloud field"),
      metric(state.windGust || state.wind, " km/h wind")
    ].filter(Boolean);
    const panel = observation.panelField || {};
    const distribution = [
      panel.clear ? panel.clear + " clear" : null,
      panel.watch ? panel.watch + " watch" : null,
      panel.unsettled ? panel.unsettled + " unsettled" : null,
      panel.alert ? panel.alert + " alert" : null
    ].filter(Boolean).join(" · ");
    const first = city.name + " records “" + state.label + "”" +
      (measurements.length ? ": " + measurements.join(" · ") + "." : ".");
    const probability = Number(state.precipitationProbability);
    const second = (projected
      ? "The city-local +24-hour frame carries only resolved physical forecast values."
      : "The city-local live frame carries only resolved physical weather values.") +
      (Number.isFinite(probability) ? " Precipitation probability registers " + Math.round(probability) + "%." : "");
    const third = "NeoMundi holds “" + observation.conditionCopy.label + "” across " +
      observation.coverage.observations + " / " + observation.coverage.expected + " measurements" +
      (distribution ? "; the panel resolves as " + distribution : "") + ".";
    const fourth = projected
      ? "The +24-hour frame applies the physical forecast while the measured NeoMundi field remains fixed at its current observation."
      : "The live frame reports physical city weather and the measured NeoMundi field without merging their sources.";
    return [first, second, third, fourth];
  }

  function cameraEmbed(city) {
    if (!city || !city.live || !city.live.videoId) {
      return null;
    }
    return (
      "https://www.youtube-nocookie.com/embed/" +
      encodeURIComponent(city.live.videoId) +
      "?autoplay=1&mute=1&controls=0&disablekb=1&fs=0&playsinline=1&rel=0"
    );
  }

  window.NMUSStation = Object.freeze({
    load,
    loadCapsule,
    normalizeObservation,
    findInteroperabilityObject,
    resolveCapsulePath,
    loadCityWeather,
    formatObservedAt,
    composeDescription,
    weatherCode,
    cameraEmbed,
    readPath,
    cities: CITIES,
    signalAliases: SIGNAL_ALIASES,
    conditionCopy: CONDITION_COPY
  });
})(window);
