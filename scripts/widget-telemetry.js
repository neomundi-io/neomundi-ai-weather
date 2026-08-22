(function () {
  'use strict';

  var ENDPOINT = 'https://api.controltowerai.io/widget-ping.php';
  var WIDGET_ID = 'weather_v1';
  var VERSION = '1.0.0';

  function getHostDomain() {
    try {
      if (document.referrer) {
        var referrerHost = new URL(document.referrer).hostname.toLowerCase();

        if (referrerHost) {
          return referrerHost;
        }
      }
    } catch (error) {
      // Ignore and try fallback.
    }

    try {
      var params = new URLSearchParams(window.location.search);
      var host = params.get('host');

      if (host) {
        return host.toLowerCase().trim();
      }
    } catch (error) {
      // Ignore.
    }

    return null;
  }

  function sendPing() {
    var hostDomain = getHostDomain();

    if (!hostDomain) {
      return;
    }

    var payload = JSON.stringify({
      widget_id: WIDGET_ID,
      host_domain: hostDomain,
      version: VERSION,
      event: 'load'
    });

    if (typeof navigator.sendBeacon === 'function') {
      var blob = new Blob([payload], {
        type: 'application/json'
      });

      navigator.sendBeacon(ENDPOINT, blob);
      return;
    }

    if (typeof fetch === 'function') {
      fetch(ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: payload,
        keepalive: true
      }).catch(function () {
        // Telemetry must never affect the widget.
      });
    }
  }

  sendPing();
})();
