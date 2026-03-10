let PRODUCTS = {};
let BASKET_CONFIG = {};

(function() {
  let basketSection = document.getElementById("basket");
  if (!basketSection) { return; }

  let C = BASKET_CONFIG;
  let warningText = C.warning || "";
  let waWarningText = C.waWarning || "";
  let shippingWarningText = C.shippingWarning || "";
  let currencySymbol = C.currency || "\u20BA";
  let waNumber = C.waNumber || "";
  let tgUsername = C.tgUsername || "";
  let labels = C.labels || {};
  let L = function(k) { return labels[k]; };

  let addToBasketText = L("addToBasket");
  let badge;
  let basketOpen = false;

  let emptyEl, descEl, wrapEl, toggleBtnEl, toggleInfoEl, contentEl, itemsEl, totalsEl;
  let lastItems, lastSubtotal, lastShipping, lastTotal;
  let cachedLinks;

  function getCart() {
    let params = new URLSearchParams(location.search);
    let cart = {};
    params.forEach(function(val, key) {
      if (PRODUCTS[key]) {
        let qty = parseInt(val, 10);
        if (qty > 0) { cart[key] = qty; }
      }
    });
    return cart;
  }

  function setCart(cart) {
    let params = new URLSearchParams(location.search);
    let toRemove = [];
    params.forEach(function(val, key) {
      if (PRODUCTS[key]) { toRemove.push(key); }
    });
    for (let r = 0; r < toRemove.length; r++) params.delete(toRemove[r]);
    for (let id in cart) {
      if (cart[id] > 0) { params.set(id, cart[id]); }
    }
    let qs = params.toString();
    let url = location.pathname + (qs ? "?" + qs : "") + location.hash;
    history.replaceState(null, "", url);
    render();
  }

  function getTotalQty(cart) {
    if (!cart) { cart = getCart(); }
    let total = 0;
    for (let id in cart) total += cart[id];
    return total;
  }

  function getItems(cart) {
    if (!cart) { cart = getCart(); }
    let items = [];
    for (let id in cart) {
      let prod = PRODUCTS[id];
      if (prod) {
        items.push({
          id: id, name: prod.name, price: prod.price,
          weight: prod.weight, img: prod.img, quantity: cart[id]
        });
      }
    }
    return items;
  }

  function addToBasket(id) {
    let cart = getCart();
    cart[id] = (cart[id] || 0) + 1;
    basketOpen = true;
    setCart(cart);
  }

  function updateQty(id, delta) {
    let cart = getCart();
    let qty = (cart[id] || 0) + delta;
    if (qty <= 0) { delete cart[id]; }
    else { cart[id] = qty; }
    setCart(cart);
  }

  function removeItem(id) {
    let cart = getCart();
    delete cart[id];
    setCart(cart);
  }

  function render() {
    let cart = getCart();
    renderButtons(cart);
    renderBadge(cart);
    renderBasket(cart);
    updateLinks();
  }

  function renderButtons(cart) {
    let buttons = document.querySelectorAll("button[data-id]");
    for (let i = 0; i < buttons.length; i++) {
      let btn = buttons[i];
      let id = btn.getAttribute("data-id");
      let qty = cart[id] || 0;
      if (qty > 0) {
        btn.className = "qty-ctrl";
        empty(btn);
        let minus = actionImg("/img/minus.png", "-", "minus", id);
        let qtyEl = txt(span, qty + " " + L("unit"));
        let plus = actionImg("/img/plus.png", "+", "plus", id);
        btn.append(minus, qtyEl, plus);
      } else {
        btn.className = "";
        btn.textContent = addToBasketText;
      }
    }
  }

  function createBadge() {
    badge = a("hidden");
    badge.id = "basket-badge";
    badge.href = "#basket";
    badge.append(img("/img/basket.png", L("basket")), txt(span, "0"));
    badge.addEventListener("click", function(e) {
      e.preventDefault();
      if (getTotalQty() === 0) { return; }
      basketOpen = true;
      renderBasket();
      basketSection.scrollIntoView({ behavior: "smooth" });
    });
    document.querySelector("header").append(badge);
  }

  function renderBadge(cart) {
    let total = getTotalQty(cart);
    badge.querySelector("span").textContent = total;
    if (total > 0) { show(badge); }
    else { hide(badge); }
  }

  function initBasketDOM() {
    emptyEl = div("empty hidden");
    emptyEl.append(img("/img/basket.png", L("basket")), txt(p, L("emptyBasket")));
    basketSection.append(emptyEl);

    if (warningText) {
      descEl = h5("hidden");
      parseBr(warningText, descEl);
      basketSection.append(descEl);
    }

    wrapEl = div("wrap hidden");

    toggleBtnEl = button();
    toggleInfoEl = i();
    toggleBtnEl.append(txt(b, L("basket")), toggleInfoEl, em());
    toggleBtnEl.addEventListener("click", function() {
      basketOpen = !basketOpen;
      if (basketOpen) { show(contentEl); }
      else { hide(contentEl); }
      toggleBtnEl.classList.toggle("open", basketOpen);
    });
    wrapEl.append(toggleBtnEl);

    contentEl = div("hidden");
    itemsEl = div("items");
    totalsEl = div("totals");
    contentEl.append(itemsEl, totalsEl);

    let waBtn = txt(button, L("whatsAppOrder"), "wa");
    waBtn.addEventListener("click", function() {
      if (lastItems) { sendWhatsApp(lastItems, lastSubtotal, lastShipping, lastTotal); }
    });
    contentEl.append(waBtn);

    if (tgUsername) {
      let tgBtn = txt(button, L("telegramOrder"), "tg");
      tgBtn.addEventListener("click", function() {
        if (lastItems) { sendTelegram(lastItems, lastSubtotal, lastShipping, lastTotal); }
      });
      contentEl.append(tgBtn);
    }

    if (waWarningText) {
      let warn = h6();
      parseBr(waWarningText, warn);
      contentEl.append(warn);
    }

    wrapEl.append(contentEl);
    basketSection.append(wrapEl);
  }

  function renderBasket(cart) {
    let items = getItems(cart);

    if (items.length === 0) {
      show(emptyEl);
      if (descEl) { hide(descEl); }
      hide(wrapEl);
      basketOpen = false;
      hide(contentEl);
      toggleBtnEl.classList.remove("open");
      return;
    }

    hide(emptyEl);
    if (descEl) { show(descEl); }
    show(wrapEl);
    if (basketOpen) { show(contentEl); }
    else { hide(contentEl); }
    toggleBtnEl.classList.toggle("open", basketOpen);

    empty(itemsEl);

    let subtotal = 0, totalQty = 0;
    for (let i = 0; i < items.length; i++) {
      let item = items[i];
      let lineTotal = item.price * item.quantity;
      subtotal += lineTotal;
      totalQty += item.quantity;

      let row = div();

      let del = actionImg("/img/delete.png", L("delete"), "delete", item.id, "del");

      let qc = div("qty-ctrl");
      let qMinus = actionImg("/img/minus.png", "-", "minus", item.id);
      let qPlus = actionImg("/img/plus.png", "+", "plus", item.id);
      qc.append(qMinus, txt(span, item.quantity), qPlus);

      row.append(del, img("/img/products/" + item.img, item.name), txt(b, item.name), qc, txt(span, fmt(lineTotal) + " " + currencySymbol));
      itemsEl.append(row);
    }

    toggleInfoEl.textContent = "(" + totalQty + " " + L("itemSuffix") + " " + L("for") + " " + L("total") + " " + fmt(subtotal) + " " + currencySymbol + ")";

    empty(totalsEl);

    let shipping = calculateShippingPrice(items);
    let total = subtotal + shipping;

    lastItems = items;
    lastSubtotal = subtotal;
    lastShipping = shipping;
    lastTotal = total;

    totalsEl.append(makeRow(L("subtotal") + ":", fmt(subtotal) + " " + currencySymbol));
    totalsEl.append(makeRow(L("shipping") + ":", shipping > 0 ? fmt(shipping) + " " + currencySymbol : L("freeShipping")));
    if (shippingWarningText) {
      totalsEl.append(txt(small, shippingWarningText));
    }
    totalsEl.append(makeRow(L("total") + ":", fmt(total) + " " + currencySymbol, "total"));
  }

  function updateLinks() {
    let qs = location.search;
    if (!cachedLinks) {
      let all = document.querySelectorAll('a[href^="/"], a[href^="./"], a[href^="../"]');
      cachedLinks = [];
      for (let i = 0; i < all.length; i++) {
        let href = all[i].getAttribute("href");
        let hashPos = href.indexOf("#");
        cachedLinks.push({
          el: all[i],
          base: (hashPos !== -1 ? href.substring(0, hashPos) : href).split("?")[0],
          hash: hashPos !== -1 ? href.substring(hashPos) : ""
        });
      }
    }
    for (let i = 0; i < cachedLinks.length; i++) {
      let l = cachedLinks[i];
      l.el.setAttribute("href", l.base + qs + l.hash);
    }
  }

  function buildOrderMessage(items, subtotal, shipping, total, greetingKey) {
    let msg = L(greetingKey) + "\n";
    for (let i = 0; i < items.length; i++) {
      msg += items[i].quantity + "x " + items[i].name + " - " + fmt(items[i].price * items[i].quantity) + " " + currencySymbol + "\n";
    }
    msg += L("subtotal") + ": " + fmt(subtotal) + " " + currencySymbol + "\n";
    msg += L("shipping") + ": " + (shipping > 0 ? fmt(shipping) + " " + currencySymbol : L("freeShipping")) + "\n";
    msg += L("total") + ": " + fmt(total) + " " + currencySymbol;
    return msg;
  }

  function sendWhatsApp(items, subtotal, shipping, total) {
    let msg = buildOrderMessage(items, subtotal, shipping, total, "whatsAppGreeting");
    window.open("https://wa.me/" + waNumber + "?text=" + encodeURIComponent(msg), "_blank");
  }

  function sendTelegram(items, subtotal, shipping, total) {
    let msg = buildOrderMessage(items, subtotal, shipping, total, "telegramGreeting");
    window.open("https://t.me/" + tgUsername + "?text=" + encodeURIComponent(msg), "_blank");
  }

  document.addEventListener("click", function(e) {
    let t = e.target;
    if (t.tagName === "IMG" && t.hasAttribute("data-action")) {
      e.stopPropagation();
      let action = t.getAttribute("data-action");
      let id = t.getAttribute("data-id");
      if (action === "plus") { updateQty(id, 1); }
      else if (action === "minus") { updateQty(id, -1); }
      else if (action === "delete") { removeItem(id); }
      return;
    }
    let btn = t;
    while (btn && btn.tagName !== "BUTTON") { btn = btn.parentElement; }
    if (btn && btn.hasAttribute("data-id") && !btn.classList.contains("qty-ctrl")) {
      addToBasket(btn.getAttribute("data-id"));
    }
  });

  createBadge();
  let fb = document.querySelector("button[data-id]");
  if (fb) { addToBasketText = fb.textContent.trim(); }
  initBasketDOM();
  if (getTotalQty() > 0) { basketOpen = true; }
  render();
})();
