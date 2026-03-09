let CACHE = "corbaci-ar-v20260309045602";
let CORE = ["/","/site.css","/site.js","/logo.png","/favicon.png","/favicon.ico"];
let PRODUCTS = ["/products/ayran-1l.html","/products/dondurulmus-ayak-paca-corbasi-750ml.html","/products/dondurulmus-iskembe-corbasi-750ml.html","/products/dondurulmus-kelle-paca-corbasi-750ml.html","/products/gazoz-1l-sise.html","/products/gazoz-330ml-kutu.html","/products/kola-1l-sise.html","/products/kola-330ml-kutu.html","/products/salgam-330ml-sise.html","/products/su.html","/products/taze-ayak-paca-corbasi-750ml.html","/products/taze-iskembe-corbasi-750ml.html","/products/taze-kelle-paca-corbasi-750ml.html","/img/products/ayran-1l-k.webp","/img/products/ayran-1l.webp","/img/products/dondurulmus-ayak-paca-corbasi-k.webp","/img/products/dondurulmus-ayak-paca-corbasi.webp","/img/products/dondurulmus-iskembe-corbasi-k.webp","/img/products/dondurulmus-iskembe-corbasi.webp","/img/products/dondurulmus-kelle-paca-corbasi-k.webp","/img/products/dondurulmus-kelle-paca-corbasi.webp","/img/products/gazoz-1l-sise-k.webp","/img/products/gazoz-1l-sise.webp","/img/products/gazoz-330ml-kutu-k.webp","/img/products/gazoz-330ml-kutu.webp","/img/products/kola-1l-sise-k.webp","/img/products/kola-1l-sise.webp","/img/products/kola-330ml-kutu-k.webp","/img/products/kola-330ml-kutu.webp","/img/products/salgam-330ml-sise-k.webp","/img/products/salgam-330ml-sise.webp","/img/products/su-k.webp","/img/products/su.webp","/img/products/taze-ayak-paca-corbasi-k.webp","/img/products/taze-ayak-paca-corbasi.webp","/img/products/taze-iskembe-corbasi-k.webp","/img/products/taze-iskembe-corbasi.webp","/img/products/taze-kelle-paca-corbasi-k.webp","/img/products/taze-kelle-paca-corbasi.webp"];
let PAGES = ["/pages/gizlilik-politikasi.html","/pages/satis-sozlesmesi.html","/pages/site-haritasi.html","/index.html","/404.html","/img/address.png","/img/basket.png","/img/delete.png","/img/email.png","/img/minus.png","/img/phone.png","/img/plus.png","/img/whatsapp.png","/img/pages/hero-header-k.webp","/img/pages/hero-header.webp"];

self.addEventListener("install", function(e) {
  e.waitUntil(
    caches.open(CACHE).then(function(c) { return c.addAll(CORE); })
  );
  self.skipWaiting();
});

self.addEventListener("activate", function(e) {
  e.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(
        keys.filter(function(k) { return k !== CACHE; })
            .map(function(k) { return caches.delete(k); })
      );
    })
  );
  self.clients.claim();
});

self.addEventListener("message", function(e) {
  if (e.data === "cache-all") {
    caches.open(CACHE).then(function(c) {
      c.addAll(PRODUCTS).then(function() {
        return c.addAll(PAGES);
      }, function() {
        return c.addAll(PAGES);
      });
    });
  }
});

self.addEventListener("fetch", function(e) {
  if (e.request.method !== "GET") return;

  let url = new URL(e.request.url);
  let isCore = CORE.indexOf(url.pathname) !== -1;

  if (isCore) {
    e.respondWith(
      fetch(e.request).then(function(res) {
        let clone = res.clone();
        caches.open(CACHE).then(function(c) { c.put(url.pathname, clone); });
        return res;
      }).catch(function() {
        return caches.match(url.pathname);
      })
    );
    return;
  }

  e.respondWith(
    caches.match(e.request, { ignoreSearch: true }).then(function(cached) {
      let fetched = fetch(e.request).then(function(res) {
        let clone = res.clone();
        caches.open(CACHE).then(function(c) { c.put(url.pathname, clone); });
        return res;
      }).catch(function() {
        return cached;
      });
      return cached || fetched;
    })
  );
});
