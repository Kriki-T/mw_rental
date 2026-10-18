const $ = (s) => document.querySelector(s);
const post = (name, data = {}) =>
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  })
    .then((r) => r.json())
    .catch(() => ({}));

const S = {
  d: null,
  sel: null,
  period: 30,
  method: "cash",
  filter: "all",
  rental: null,
  t0: 0,
  timer: null,
  busy: false,
  tab: "vehicles",
};
const T = (k) => (S.d && S.d.locale && S.d.locale[k]) || k;
const money = (n) => S.d.currency + Math.round(n).toLocaleString("en-US");
const fmt = (sec) => {
  sec = Math.max(0, Math.floor(sec));
  const h = Math.floor(sec / 3600),
    m = Math.floor((sec % 3600) / 60),
    s = sec % 60;
  const p = (n) => String(n).padStart(2, "0");
  return h > 0 ? `${h}:${p(m)}:${p(s)}` : `${p(m)}:${p(s)}`;
};
const esc = (s) =>
  String(s).replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );

function toast(msg) {
  const t = $("#toast");
  t.textContent = msg;
  t.classList.add("show");
  clearTimeout(toast.h);
  toast.h = setTimeout(() => t.classList.remove("show"), 2800);
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
  $("#rulesTitle").textContent = T("ui_rules_title");
  $("#rules").innerHTML = [1, 2, 3, 4, 5, 6, 7]
    .map(
      (i) => `
    <div class="rule"><div class="n">${i}</div>
      <h3>${esc(T("ui_r" + i + "_t"))}</h3><p>${esc(T("ui_r" + i + "_d"))}</p></div>`,
    )
    .join("");
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
  const list = S.d.vehicles.filter(
    (v) => S.filter === "all" || v.category === S.filter,
  );
  $("#grid").innerHTML = list
    .map(
      (v) => `
    <div class="card ${S.sel === v.model ? "sel" : ""}" data-model="${esc(v.model)}">
      <div class="img"><img loading="lazy" src="https://docs.fivem.net/vehicles/${esc(v.model)}.webp" onerror="this.style.display='none'"></div>
      <h3>${esc(v.label)}</h3>
      <div class="meta"><span>${esc(v.category)}</span><span>&bull;</span><span>${v.seats} ${esc(T("ui_seats"))}</span></div>
      <div class="bar"><i style="width:${Math.min(100, v.speed || 50)}%"></i></div>
      <div class="price">${money(v.price)} <small>${esc(T("ui_hour"))}</small></div>
    </div>`,
    )
    .join("");
}

function renderCheckout() {
  const el = $("#checkout");
  const v = S.sel && S.d.vehicles.find((x) => x.model === S.sel);
  if (!v) {
    el.innerHTML = `<div class="empty"><div class="ico">&#128663;</div><p>${esc(T("ui_select_hint"))}</p></div>`;
    return;
  }
  const cycle = Math.max(1, Math.ceil((v.price * S.period) / 60));
  const total = cycle + v.deposit;
  el.innerHTML = `
    <div><h2>${esc(v.label)}</h2><div class="sub">${esc(v.category)} &bull; ${v.seats} ${esc(T("ui_seats"))}</div></div>
    <div><div class="lbl">${esc(T("ui_period"))}</div>
      <div class="opts">${S.d.periods
        .map(
          (p) =>
            `<div class="opt ${S.period === p ? "active" : ""}" data-period="${p}">${p} ${esc(T("ui_min"))}</div>`,
        )
        .join("")}</div></div>
    <div><div class="lbl">${esc(T("ui_payment"))}</div>
      <div class="opts">
        <div class="opt ${S.method === "cash" ? "active" : ""}" data-method="cash">${esc(T("ui_cash"))}</div>
        <div class="opt ${S.method === "bank" ? "active" : ""}" data-method="bank">${esc(T("ui_bank"))}</div>
      </div></div>
    <div class="sum">
      <div><span>${esc(T("ui_first"))}</span><b>${money(cycle)}</b></div>
      <div><span>${esc(T("ui_deposit"))}</span><b>${money(v.deposit)}</b></div>
      <div class="tot"><span>${esc(T("ui_total_now"))}</span><b>${money(total)}</b></div>
    </div>
    <div class="note">${esc(T("ui_then").replace("%s", S.period))}: <b>${money(cycle)}</b></div>
    ${S.rental ? `<div class="warn">${esc(T("ui_has_rental"))}</div>` : ""}
    <button class="btn" id="rentBtn" ${S.rental ? "disabled" : ""}>${esc(T("ui_rent_now"))}</button>`;
}

function renderRental() {
  const box = $("#rentalBox");
  const r = S.rental;
  if (!r) {
    box.innerHTML = `<div class="empty" style="padding:80px 0"><div class="ico">&#128273;</div><p>${esc(T("ui_no_rental"))}</p></div>`;
    return;
  }
  box.innerHTML = `
    <div class="rental">
      <h2>${esc(r.label)}</h2>
      <div class="plate">${esc(r.plate)}</div>
      <div class="rows">
        <div class="row"><span>${esc(T("ui_renter"))}</span><b>${esc(r.renter)}</b></div>
        <div class="row"><span>${esc(T("ui_started"))}</span><b>${esc(r.started)}</b></div>
        <div class="row"><span>${esc(T("ui_elapsed"))}</span><b id="elapsed">--</b></div>
        <div class="row hot"><span>${esc(T("ui_next"))}</span><b id="nextIn">--</b></div>
        <div class="row"><span>${esc(T("ui_paid"))}</span><b>${money(r.paid)}</b></div>
        <div class="row ${r.debt > 0 ? "bad" : ""}"><span>${esc(T("ui_debt"))}</span><b>${money(r.debt)}</b></div>
      </div>
      <div class="hint">${esc(T("ui_return_hint"))}</div>
    </div>`;
  tick();
}

function tick() {
  if (!S.rental) return;
  const d = (performance.now() - S.t0) / 1000;
  const e = $("#elapsed"),
    n = $("#nextIn");
  if (e) e.textContent = fmt(S.rental.elapsed + d);
  if (n) n.textContent = fmt(S.rental.nextIn - d);
}

function setRental(r) {
  S.rental = r || null;
  S.t0 = performance.now();
  renderRental();
  renderCheckout();
}

function setTab(t) {
  S.tab = t;
  document
    .querySelectorAll(".tab")
    .forEach((b) => b.classList.toggle("active", b.dataset.tab === t));
  document
    .querySelectorAll(".pane")
    .forEach((p) => p.classList.toggle("active", p.id === "pane-" + t));
}

/* ---------- events ---------- */
$("#tabs").addEventListener("click", (e) => {
  const b = e.target.closest(".tab");
  if (b) setTab(b.dataset.tab);
});
$("#filters").addEventListener("click", (e) => {
  const b = e.target.closest(".pill");
  if (!b) return;
  S.filter = b.dataset.cat;
  renderFilters();
  renderGrid();
});
$("#grid").addEventListener("click", (e) => {
  const c = e.target.closest(".card");
  if (!c) return;
  S.sel = c.dataset.model;
  renderGrid();
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
    S.period = S.d.periods.includes(30) ? 30 : S.d.periods[0];
    S.method = "cash";
    S.rental = S.d.rental || null;
    S.t0 = performance.now();
    renderStatic();
    renderWallet();
    renderFilters();
    renderGrid();
    renderCheckout();
    renderRental();
    setTab("vehicles");
    $("#app").classList.remove("hidden");
    clearInterval(S.timer);
    S.timer = setInterval(tick, 1000); // radi samo dok je UI otvoren
  } else if (msg.action === "close") {
    $("#app").classList.add("hidden");
    clearInterval(S.timer);
    S.timer = null;
  } else if (msg.action === "rental") {
    setRental(msg.data);
  }
});
