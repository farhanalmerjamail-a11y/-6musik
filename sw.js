const CACHE_NAME = 'soundsphere-cache-v1';
const ASSETS_TO_CACHE = [
  './',
  './index.html',
  './css/styles.css',
  './js/app.js',
  './js/store/audioStore.js',
  './js/audio/audioEngine.js',
  './js/data/mockCatalog.js',
  './js/components/sidebar.js',
  './js/components/mainView.js',
  './js/components/rightPanel.js',
  './js/components/bottomPlayer.js',
  './js/components/mobileFullPlayer.js',
  './js/components/playlistModal.js',
  './manifest.json'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE).catch((err) => console.warn('Cache add error:', err));
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      );
    })
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  // Pass-through audio and dynamic external media
  if (event.request.url.includes('.mp3') || event.request.url.includes('unsplash.com') || event.request.url.includes('freesound.org')) {
    return;
  }

  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      return cachedResponse || fetch(event.request);
    })
  );
});
