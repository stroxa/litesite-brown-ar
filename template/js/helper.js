function _el(tag, cls) {
  let e = document.createElement(tag);
  if (cls) { e.className = cls; }
  return e;
}

function div(cls) { return _el("div", cls); }
function span(cls) { return _el("span", cls); }
function b(cls) { return _el("b", cls); }
function i(cls) { return _el("i", cls); }
function em(cls) { return _el("em", cls); }
function p(cls) { return _el("p", cls); }
function a(cls) { return _el("a", cls); }
function h5(cls) { return _el("h5", cls); }
function h6(cls) { return _el("h6", cls); }
function small(cls) { return _el("small", cls); }
function button(cls) { return _el("button", cls); }

function img(src, title, cls) {
  let e = _el("img", cls);
  if (src) { e.src = src; }
  if (title) { e.alt = title; e.title = title; }
  return e;
}

function txt(fn, text, cls) {
  let e = fn(cls);
  e.textContent = text;
  return e;
}

function show(e) { e.classList.remove("hidden"); }
function hide(e) { e.classList.add("hidden"); }

function makeRow(label, value, cls) {
  let row = div(cls);
  row.append(txt(span, label), txt(b, value));
  return row;
}

function parseBr(text, parent) {
  let parts = text.split(/<br\s*\/?>/i);
  for (let i = 0; i < parts.length; i++) {
    if (i > 0) { parent.append(document.createElement("br")); }
    parent.append(parts[i]);
  }
}

function fmt(n) { return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, "."); }

function empty(el) { el.replaceChildren(); }

function actionImg(src, title, action, id, cls) {
  let e = img(src, title, cls);
  e.setAttribute("data-action", action);
  e.setAttribute("data-id", id);
  return e;
}
