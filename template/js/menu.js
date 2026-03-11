let _nav = document.querySelector("nav");
let _btn = document.getElementById("menu-btn");
let _icon = document.getElementById("menu-icon");
if (_btn && _nav) {
  _btn.addEventListener("click", function() {
    _nav.classList.toggle("open");
    if (_icon) {
      _icon.src = _nav.classList.contains("open") ? "/img/menu-close.png" : "/img/menu-open.png";
    }
  });
  _nav.querySelectorAll("a").forEach(function(a) {
    a.addEventListener("click", function() {
      _nav.classList.remove("open");
      if (_icon) { _icon.src = "/img/menu-open.png"; }
    });
  });
}
