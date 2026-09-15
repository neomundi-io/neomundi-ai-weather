const CACHE = "neomundi-ai-weather-v5";
const ASSETS = [
  "./index.html", "./core-panel.html", "./topbar.html", "./sidebar.html", "./weather.json", "./manifest.json",
  "./config/wording.json", "./config/languages.json", "./config/panels.json",
  "./assets/logo-controltower.png",
  "./styles/themes.css", "./styles/base.css",
  "./scripts/i18n.js", "./scripts/themes.js", "./scripts/weather-data.js",
  "./i18n/en.json", "./i18n/fr.json", "./i18n/de.json", "./i18n/es.json", "./i18n/it.json"
];

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE).then(cache => cache.addAll(ASSETS))
  );
});

self.addEventListener("fetch", event => {
  event.respondWith(
    fetch(event.request)
      .then(response => {
        const copy = response.clone();
        caches.open(CACHE).then(cache => cache.put(event.request, copy));
        return response;
      })
      .catch(() => caches.match(event.request))
  );
});
