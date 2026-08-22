(function () {
  'use strict';

  // ============================================================
  // ControlTower / NeoMundi — Widget Telemetry V1 (client)
  // No cookie, no storage, no user identifier. Fire-and-forget.
  //
  // Host domain resolution, in priority order:
  //   1) document.referrer  (browser-supplied, not self-declared)
  //   2) explicit ?host=... query param on this script/iframe's own URL
  //      (publisher-declared at integration time)
  //   3) nothing reliable -> do NOT send a ping. We never fall back to
  //      window.location.hostname, because when this script runs inside
  //      an iframe (e.g. served from weather.controltowerai.io), that
  //      would report OUR domain, not the publisher's site.
  // ============================================================

  var CT_TELEMETRY_ENDPOINT = 'https://api.controltowerai.io/widget-ping.php';
  var CT_WIDGET_ID = 'weather_v1';
  var CT_WIDGET_VERSION = '1.0.0';

  // Mirrors the server-side pattern in widget-ping.php. This is a
  // client-side pre-check only — the server remains the sole authority
  // and re-validates independently regardless of what we send.
  var DOMAIN_PATTERN = /^(?!-)[a-z0-9-]{1,63}(?<!-)(\.(?!-)[a-z0-9-]{1,63}(?<!-))+$/;

  function isValidDomain(v) {
    return typeof v === 'string' && v.length > 0 && v.length <= 255 && DOMAIN_PATTERN.test(v);
  }

  function extractHostname(url) {
    try {
      return new URL(url).hostname.toLowerCase();
    } catch (e) {
      return null;
    }
  }

  function getHostDomain() {
    // 1) Preferred: document.referrer — see limitations below.
    if (document.referrer) {
      var fromReferrer = extractHostname(document.referrer);
      if (isValidDomain(fromReferrer)) return fromReferrer;
    }

    // 2) Fallback: explicit ?host= param, set deliberately by the
    // publisher when they embed the iframe. Weaker trust than the
    // referrer (self-declared, not browser-verified) — used only when
    // the referrer is unavailable or blocked.
    try {
      var params = new URLSearchParams(window.location.search);
      var fromParam = params.get('host');
      if (fromParam) {
        fromParam = fromParam.toLowerCase();
        if (isValidDomain(fromParam)) return fromParam;
      }
    } catch (e) { /* URLSearchParams unsupported in this browser — ignore */ }

    // 3) No reliable host. Do not guess, do not send.
    return null;
  }

  function sendPing(eventName) {
    var domain = getHostDomain();
    if (!domain) return; // nothing trustworthy to report — stay silent

    var payload = JSON.stringify({
      widget_id: CT_WIDGET_ID,
      host_domain: domain,
      version: CT_WIDGET_VERSION,
      event: eventName
    });

    if (navigator.sendBeacon) {
      var blob = new Blob([payload], { type: 'application/json' });
      navigator.sendBeacon(CT_TELEMETRY_ENDPOINT, blob);
    } else {
      // Fallback for very old browsers only. Fire-and-forget, no retry.
      try {
        fetch(CT_TELEMETRY_ENDPOINT, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: payload,
          keepalive: true
        });
      } catch (e) { /* silent */ }
    }
  }

  sendPing('load');
})();

// ------------------------------------------------------------
// LIMITATIONS OF document.referrer — READ BEFORE RELYING ON IT
// ------------------------------------------------------------
// document.referrer, inside an iframe, normally holds the URL of the
// parent page that embedded it. That is exactly what we want. But it
// is not guaranteed:
//
// - Referrer-Policy on the PARENT page controls what the iframe sees.
//   "no-referrer" or "same-origin" suppress it entirely for a
//   cross-origin iframe -> document.referrer is "".
//   The common modern default, "strict-origin-when-cross-origin",
//   still exposes the origin (scheme + hostname) on cross-origin
//   requests, which is all we need — so most sites work out of the box.
// - Browser privacy features and some extensions strip or blank
//   referrers regardless of the page's own policy.
// - document.referrer reflects the state at the iframe's initial load.
//   If the parent is a single-page app that changes route (or even
//   domain, rare) without reloading the iframe, later heartbeat/refresh
//   pings still report the original referrer — a non-issue for a
//   normal embed, worth knowing for unusual setups.
// - It cannot be forged to a domain that never actually referred the
//   frame, which makes it meaningfully more trustworthy than a
//   self-declared value like the ?host= fallback.
//
// Net effect: referrer works correctly for the large majority of
// real embeds; the ?host= param exists specifically to cover the
// remaining cases (strict Referrer-Policy, blocked referrers) without
// ever inventing a value.
