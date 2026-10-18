const $ = (s) => document.querySelector(s);
const post = (name, data = {}) =>
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  })
    .then((r) => r.json())
    .catch(() => ({}));

/* ---------- ikone (inline SVG, bez eksternih fajlova) ---------- */
const IC = {
  car: '<path d="M5 17h14M6 17l1.6-6.2a1 1 0 0 1 1-.8h6.8a1 1 0 0 1 1 .8L18 17M7.5 11l1.1-3.2A1 1 0 0 1 9.5 7h5a1 1 0 0 1 .9.8L16.5 11"/><circle cx="8" cy="17" r="1.6"/><circle cx="16" cy="17" r="1.6"/>',
  key: '<circle cx="8" cy="15" r="4"/><path d="M11 12l9-9M16 7l3 3M14 9l2 2"/>',
  shield:
    '<path d="M12 3l8 3v6c0 4.5-3.2 8-8 9-4.8-1-8-4.5-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
  cash: '<rect x="3" y="6" width="18" height="12" rx="2"/><circle cx="12" cy="12" r="2.6"/><path d="M6.5 9.5v.01M17.5 14.5v.01"/>',
  bank: '<path d="M3 10l9-6 9 6M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 20h18"/>',
  pin: '<path d="M12 21s7-6.2 7-11.5A7 7 0 0 0 5 9.5C5 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
  x: '<path d="M6 6l12 12M18 6L6 18"/>',
  search: '<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4-4"/>',
  sort: '<path d="M7 4v16M7 20l-3-3M7 20l3-3M17 20V4M17 4l-3 3M17 4l3 3"/>',
  check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
  alert: '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17v.01"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.2 2"/>',
  coins:
    '<circle cx="9" cy="9" r="5.5"/><path d="M14.5 6.5A5.5 5.5 0 1 1 9.5 14.5"/>',
  doc: '<path d="M7 3h7l4 4v14H7z"/><path d="M14 3v4h4M10 12h5M10 16h5"/>',
  undo: '<path d="M9 7L4 12l5 5"/><path d="M4 12h10a6 6 0 0 1 0 12"/>',
  wrench:
    '<path d="M14.5 6.5a4 4 0 0 0-5 5L4 17l3 3 5.5-5.5a4 4 0 0 0 5-5l-2.5 2.5-2.5-.5-.5-2.5z"/>',
  ban: '<circle cx="12" cy="12" r="9"/><path d="M5.7 5.7l12.6 12.6"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8v.01"/>',
};
const icon = (n) => `<svg viewBox="0 0 24 24">${IC[n] || ""}</svg>`;
const hydrateIcons = (root = document) =>
  root.querySelectorAll("i[data-ic]:not([data-done])").forEach((el) => {
    el.innerHTML = icon(el.dataset.ic);
    el.dataset.done = 1;
  });

/* ---------- state / helpers ---------- */
const S = {
  d: null,
  sel: null,
  period: 30,
  method: "cash",
  filter: "all",
  q: "",
  sort: 0,
  rental: null,
  t0: 0,
  timer: null,
  busy: false,
};
const T = (k) => (S.d && S.d.locale && S.d.locale[k]) || k;
const money = (n) => S.d.currency + Math.round(n).toLocaleString("en-US");
const esc = (s) =>
  String(s).replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const imgOf = (m) =>
  `https://docs.fivem.net/vehicles/${encodeURIComponent(m)}.webp`;
const p2 = (n) => String(n).padStart(2, "0");
const fmt = (sec) => {
  sec = Math.max(0, Math.floor(sec));
  const h = Math.floor(sec / 3600),
    m = Math.floor((sec % 3600) / 60),
    s = sec % 60;
  return h > 0 ? `${h}:${p2(m)}:${p2(s)}` : `${p2(m)}:${p2(s)}`;
};
const cycleCost = (v, p) => Math.max(1, Math.ceil((v.price * p) / 60));

function toast(msg) {
  const t = $("#toast");
  t.innerHTML = `<i data-ic="alert"></i><span>${esc(msg)}</span>`;
  hydrateIcons(t);
  t.classList.add("show");
  clearTimeout(toast.h);
  toast.h = setTimeout(() => t.classList.remove("show"), 3000);
}

/* ---------- render ---------- */
function renderStatic() {
  $("#brand").textContent = T("ui_brand");
  $("#brandSub").textContent = T("ui_brand_sub");
  $("#tVehicles").textContent = T("ui_tab_vehicles");
  $("#tInfo").textContent = T("ui_tab_info");
  $("#tRental").textContent = T("ui_tab_rental");
  $("#lCash").textContent = T("ui_cash");
  $("#lBank").textContent = T("ui_bank");
  $("#locLabel").textContent = S.d.location;
  $("#search").placeholder = T("ui_search");
  $("#sortLbl").textContent = T("ui_sort");
  $("#rulesTitle").textContent = T("ui_rules_title");
  const rIc = ["coins", "shield", "doc", "undo", "wrench", "ban", "key"];
  $("#rules").innerHTML = rIc
    .map(
      (ic, i) => `
    <div class="rule ${i === 0 || i === 3 ? "big" : ""}" style="animation-delay:${i * 40}ms">
      <span class="no">0${i + 1}</span>
      <div class="ic"><i data-ic="${ic}"></i></div>
      <h3>${esc(T("ui_r" + (i + 1) + "_t"))}</h3>
      <p>${esc(T("ui_r" + (i + 1) + "_d"))}</p>
    </div>`,
    )
    .join("");
  hydrateIcons();
}

function renderWallet() {
  $("#cash").textContent = money(S.d.cash);
  $("#bank").textContent = money(S.d.bank);
}

function renderFilters() {
  const cats = ["all", ...new Set(S.d.vehicles.map((v) => v.category))];
  $("#filters").innerHTML = cats
    .map(
      (c) =>
        `<button class="pill ${S.filter === c ? "active" : ""}" data-cat="${esc(c)}">${c === "all" ? esc(T("ui_all")) : esc(c)}</button>`,
    )
    .join("");
}

function renderGrid() {
  const q = S.q.trim().toLowerCase();
  let list = S.d.vehicles.filter(
    (v) =>
      (S.filter === "all" || v.category === S.filter) &&
      (!q ||
        v.label.toLowerCase().includes(q) ||
        v.model.toLowerCase().includes(q)),
  );
  if (S.sort) list = [...list].sort((a, b) => (a.price - b.price) * S.sort);

  $("#grid").innerHTML = list.length
    ? list
        .map(
          (v, i) => `
    <div class="card ${S.sel === v.model ? "sel" : ""}" data-model="${esc(v.model)}" style="animation-delay:${Math.min(i, 10) * 30}ms">
      <span class="tag">${esc(v.category)}</span>
      <span class="chk"><i data-ic="check"></i></span>
      <div class="stage"><img loading="lazy" src="${imgOf(v.model)}" onerror="this.style.display='none'"></div>
      <h3>${esc(v.label)}</h3>
      <div class="stats">
        <div class="st"><em>${esc(T("ui_speed"))}</em><div class="b"><i style="width:${Math.min(100, v.speed || 50)}%"></i></div></div>
        <div class="st"><em>${esc(T("ui_seats"))}</em><div class="b"><i style="width:${Math.min(100, v.seats * 20)}%"></i></div></div>
      </div>
      <div class="price"><b>${money(v.price)}</b><small>${esc(T("ui_hour"))}</small></div>
    </div>`,
        )
        .join("")
    : `<div class="none">${esc(T("ui_no_results"))}</div>`;
  hydrateIcons($("#grid"));
}

function renderCheckout() {
  const el = $("#checkout");
  const v = S.sel && S.d.vehicles.find((x) => x.model === S.sel);
  if (!v) {
    el.classList.remove("has");
    el.innerHTML = `<div class="empty"><div class="ring"><i data-ic="car"></i></div>${esc(T("ui_select_hint"))}</div>`;
    return hydrateIcons(el);
  }
  const cycle = cycleCost(v, S.period);
  const total = cycle + v.deposit;
  const bal = S.method === "bank" ? S.d.bank : S.d.cash;
  const enough = bal >= total;
  const pm = (id, ic, lbl, b) => `
    <div class="pm ${S.method === id ? "active" : ""} ${b < total ? "low" : ""}" data-method="${id}">
      <div class="t"><i data-ic="${ic}"></i>${esc(lbl)}</div><small>${money(b)}</small>
    </div>`;

  el.classList.add("has");
  el.innerHTML = `
    <div class="hero">
      <img src="${imgOf(v.model)}" onerror="this.style.display='none'">
      <h2>${esc(v.label)}</h2>
      <div class="sub">${esc(v.category)} &bull; ${v.seats} ${esc(T("ui_seats"))} &bull; ${money(v.price)} ${esc(T("ui_hour"))}</div>
    </div>
    <div>
      <div class="lbl">${esc(T("ui_period"))}</div>
      <div class="seg">${S.d.periods
        .map(
          (p) => `
        <div class="o ${S.period === p ? "active" : ""}" data-period="${p}">${p} ${esc(T("ui_min"))}<small>${money(cycleCost(v, p))}</small></div>`,
        )
        .join("")}</div>
    </div>
    <div>
      <div class="lbl">${esc(T("ui_payment"))}</div>
      <div class="pay">${pm("cash", "cash", T("ui_cash"), S.d.cash)}${pm("bank", "bank", T("ui_bank"), S.d.bank)}</div>
    </div>
    <div class="tl">
      <div class="r now"><span>${esc(T("ui_first"))}</span><b>${money(cycle)}</b></div>
      <div class="r now"><span>${esc(T("ui_deposit"))}</span><b>${money(v.deposit)}</b></div>
      <div class="r"><span>${esc(T("ui_then").replace("%s", S.period))}</span><b>${money(cycle)}</b></div>
    </div>
    <div class="total"><span>${esc(T("ui_total_now"))}</span><b>${money(total)}</b></div>
    ${
      S.rental
        ? `<div class="warn"><i data-ic="alert"></i>${esc(T("ui_has_rental"))}</div>`
        : !enough
          ? `<div class="warn"><i data-ic="alert"></i>${esc(T("ui_insufficient"))}</div>`
          : ""
    }
    <button class="btn" id="rentBtn" ${S.rental || !enough ? "disabled" : ""}>${esc(T("ui_rent_now"))}</button>`;
  hydrateIcons(el);
}

function renderRental() {
  const box = $("#rentalBox");
  const r = S.rental;
  $("#dot").classList.toggle("hidden", !r);
  if (!r) {
    box.innerHTML = `<div class="empty" style="padding:120px 0"><div class="ring"><i data-ic="key"></i></div>${esc(T("ui_no_rental"))}</div>`;
    return hydrateIcons(box);
  }
  box.innerHTML = `
    <div class="ticket">
      <div class="tk-main">
        <div class="tk-top"><span class="badge">${esc(T("ui_active"))}</span></div>
        <h2>${esc(r.label)}</h2>
        <div class="plate">${esc(r.plate)}</div>
        <div class="rows">
          <div class="row"><span>${esc(T("ui_renter"))}</span><b>${esc(r.renter)}</b></div>
          <div class="row"><span>${esc(T("ui_started"))}</span><b>${esc(r.started)}</b></div>
          <div class="row"><span>${esc(T("ui_elapsed"))}</span><b id="elapsed">--</b></div>
          <div class="row"><span>${esc(T("ui_per_cycle"))}</span><b>${money(r.cycleCost)} / ${r.period} ${esc(T("ui_min"))}</b></div>
          <div class="row"><span>${esc(T("ui_paid"))}</span><b>${money(r.paid)}</b></div>
          <div class="row ${r.debt > 0 ? "bad" : ""}"><span>${esc(T("ui_debt"))}</span><b>${money(r.debt)}</b></div>
        </div>
      </div>
      <div class="tk-side">
        <div class="ringw">
          <svg viewBox="0 0 120 120">
            <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8b2ff0"/><stop offset="1" stop-color="#e04bff"/></linearGradient></defs>
            <circle class="bg" cx="60" cy="60" r="52"/>
            <circle class="fg" id="ringFg" cx="60" cy="60" r="52" stroke-dasharray="326.7" stroke-dashoffset="0"/>
          </svg>
          <div class="ct"><b id="nextIn">--</b><span>${esc(T("ui_next"))}</span></div>
        </div>
      </div>
    </div>
    <div class="hint"><i data-ic="info"></i><span>${esc(T("ui_return_hint"))}</span></div>`;
  hydrateIcons(box);
  tick();
}

function tick() {
  const r = S.rental;
  if (!r) return;
  const d = (performance.now() - S.t0) / 1000;
  const e = $("#elapsed"),
    n = $("#nextIn"),
    f = $("#ringFg");
  const left = Math.max(0, r.nextIn - d);
  if (e) e.textContent = fmt(r.elapsed + d);
  if (n) n.textContent = fmt(left);
  if (f)
    f.style.strokeDashoffset = (
      326.7 *
      (1 - Math.min(1, left / (r.period * 60)))
    ).toFixed(1);
}

function setRental(r) {
  S.rental = r || null;
  S.t0 = performance.now();
  renderRental();
  renderCheckout();
}

function setTab(t) {
  document
    .querySelectorAll(".nav")
    .forEach((b) => b.classList.toggle("active", b.dataset.tab === t));
  document
    .querySelectorAll(".pane")
    .forEach((p) => p.classList.toggle("active", p.id === "pane-" + t));
}

/* ---------- events ---------- */
$("#tabs").addEventListener("click", (e) => {
  const b = e.target.closest(".nav");
  if (b) setTab(b.dataset.tab);
});
$("#filters").addEventListener("click", (e) => {
  const b = e.target.closest(".pill");
  if (!b) return;
  S.filter = b.dataset.cat;
  renderFilters();
  renderGrid();
});
$("#search").addEventListener("input", (e) => {
  S.q = e.target.value;
  renderGrid();
});
$("#sortBtn").addEventListener("click", () => {
  S.sort = S.sort === 0 ? 1 : S.sort === 1 ? -1 : 0;
  $("#sortBtn").classList.toggle("on", S.sort !== 0);
  $("#sortLbl").textContent =
    T("ui_sort") + (S.sort === 1 ? " \u2191" : S.sort === -1 ? " \u2193" : "");
  renderGrid();
});
$("#grid").addEventListener("click", (e) => {
  const c = e.target.closest(".card");
  if (!c) return;
  S.sel = c.dataset.model;
  document
    .querySelectorAll(".card.sel")
    .forEach((x) => x.classList.remove("sel"));
  c.classList.add("sel");
  renderCheckout();
});
$("#checkout").addEventListener("click", async (e) => {
  const p = e.target.closest("[data-period]");
  if (p) {
    S.period = +p.dataset.period;
    return renderCheckout();
  }
  const m = e.target.closest("[data-method]");
  if (m) {
    S.method = m.dataset.method;
    return renderCheckout();
  }
  if (e.target.closest("#rentBtn") && !S.busy && S.sel && !S.rental) {
    S.busy = true;
    const res = await post("rent", {
      model: S.sel,
      period: S.period,
      method: S.method,
    });
    S.busy = false;
    if (!res.ok) toast(res.msg || T("err_generic"));
  }
});
$("#closeBtn").addEventListener("click", () => post("close"));
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") post("close");
});

window.addEventListener("message", ({ data: msg }) => {
  if (msg.action === "open") {
    S.d = msg.data;
    S.sel = null;
    S.filter = "all";
    S.q = "";
    S.sort = 0;
    S.period = S.d.periods.includes(30) ? 30 : S.d.periods[0];
    S.method = "cash";
    S.rental = S.d.rental || null;
    S.t0 = performance.now();
    $("#search").value = "";
    $("#sortBtn").classList.remove("on");
    hydrateIcons();
    renderStatic();
    renderWallet();
    renderFilters();
    renderGrid();
    renderCheckout();
    renderRental();
    setTab("vehicles");
    $("#app").classList.remove("hidden");
    clearInterval(S.timer);
    S.timer = setInterval(tick, 1000);
  } else if (msg.action === "close") {
    $("#app").classList.add("hidden");
    clearInterval(S.timer);
    S.timer = null;
  } else if (msg.action === "rental") {
    setRental(msg.data);
  }
});
