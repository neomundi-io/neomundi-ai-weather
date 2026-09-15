/**
 * NeoMundi AI Weather — "Spot the Drift" quiz telemetry.
 *
 * Same endpoint, same privacy posture as scripts/widget-telemetry.js —
 * host_domain resolved from document.referrer or a ?host= fallback,
 * never an IP address; credentials: 'omit'; failures swallowed
 * silently so telemetry can never affect the quiz itself. Kept as a
 * separate file/widget_id ('quiz_v1' vs 'weather_v1') rather than
 * extended in place, since widget-telemetry.js fires exactly one fixed
 * "load" event on script load and has no generic event API — the quiz
 * needs several distinct lifecycle events instead.
 *
 * NOTE: this sends `event` and `widget_id: "quiz_v1"` values that
 * scripts/widget-telemetry.js never sends. Whether the widget-ping.php
 * endpoint already accepts/logs those is server-side and outside this
 * repo — worth confirming with whoever owns that endpoint before
 * relying on this data.
 *
 * Per-event payload is intentionally limited to structural facts
 * (question position, final regime/condition, CTA target) — never the
 * content of an individual answer, per the brief's requirement.
 */
(function (window) {
  "use strict";

  var ENDPOINT = "https://api.controltowerai.io/widget-ping.php";
  var WIDGET_ID = "quiz_v1";
  var VERSION = "1.0.0";

  function getHostDomain() {
    try {
      if (document.referrer) {
        var referrerHost = new URL(document.referrer).hostname.toLowerCase();
        if (referrerHost) return referrerHost;
      }
    } catch (error) {
      // Ignore and try fallback.
    }

    try {
      var params = new URLSearchParams(window.location.search);
      var host = params.get("host");
      if (host) return host.toLowerCase().trim();
    } catch (error) {
      // Ignore.
    }

    return null;
  }

  function track(event, extra) {
    var hostDomain = getHostDomain();
    if (!hostDomain) return;
    if (typeof fetch !== "function") return;

    var payload = Object.assign(
      {
        widget_id: WIDGET_ID,
        host_domain: hostDomain,
        version: VERSION,
        event: event,
      },
      extra || {}
    );

    fetch(ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      mode: "cors",
      credentials: "omit",
      keepalive: true,
    }).catch(function () {
      // Telemetry must never affect the widget.
    });
  }

  window.NMQuizTelemetry = { track: track };
})(window);
