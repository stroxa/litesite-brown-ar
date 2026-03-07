(function() {
  let imgs = document.querySelectorAll("img[data-src]");
  if (!imgs.length) { return; }

  let observer = new IntersectionObserver(function(entries) {
    for (let i = 0; i < entries.length; i++) {
      if (entries[i].isIntersecting) {
        let img = entries[i].target;
        let real = new Image();
        real.onload = function() {
          this._target.src = this._target.dataset.src;
          this._target.removeAttribute("data-src");
        };
        real._target = img;
        real.src = img.dataset.src;
        observer.unobserve(img);
      }
    }
  });

  for (let i = 0; i < imgs.length; i++) { observer.observe(imgs[i]); }
})();
