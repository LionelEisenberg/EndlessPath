/* ------------------------------------------------------------------
   app.js — tab switching, grid population, drag-to-trash, selection
------------------------------------------------------------------ */

const EQ_FILTERS = ['All', 'Weapons', 'Armor', 'Accessories'];

const state = {
  tab: 'equipment',
  eqFilterIdx: 0,
  selectedSlotId: 'iron_shortsword',
  trashed: [],
  drag: null,
};

/* ----------------- INIT ----------------- */
document.addEventListener('DOMContentLoaded', () => {
  initBookmarks();
  initFilterArrows();
  populateEquipmentGrid();
  populateConsumablesGrid();
  populateMaterialsGrid();
  populateQuestList();
  initLegendToggle();
  initTrashSlots();
  initDragGhost();
});

/* ----------------- BOOKMARK TABS ----------------- */
function initBookmarks() {
  const btns = document.querySelectorAll('.bookmark');
  btns.forEach(btn => {
    btn.addEventListener('click', () => {
      const target = btn.dataset.target;
      switchTab(target);
    });
  });
}

function switchTab(name) {
  state.tab = name;
  document.querySelectorAll('.bookmark').forEach(b => {
    b.classList.toggle('is-active', b.dataset.target === name);
  });
  document.querySelectorAll('.tab-pane').forEach(p => {
    p.classList.toggle('is-active', p.dataset.pane === name);
  });
  // tiny haptic-feeling page flip animation on the cover
  const cover = document.querySelector('.cover');
  cover.animate(
    [
      { filter: 'brightness(1.0)' },
      { filter: 'brightness(1.18)' },
      { filter: 'brightness(1.0)' },
    ],
    { duration: 240, easing: 'ease-out' }
  );
}

/* ----------------- EQUIPMENT FILTER ----------------- */
function initFilterArrows() {
  const prev = document.querySelector('[data-action="prev-filter"]');
  const next = document.querySelector('[data-action="next-filter"]');
  if (prev) prev.addEventListener('click', () => cycleFilter(-1));
  if (next) next.addEventListener('click', () => cycleFilter(+1));
  renderFilterDots();
}
function cycleFilter(delta) {
  state.eqFilterIdx = (state.eqFilterIdx + delta + EQ_FILTERS.length) % EQ_FILTERS.length;
  document.getElementById('eqFilterLabel').textContent = EQ_FILTERS[state.eqFilterIdx];
  renderFilterDots();
  populateEquipmentGrid();
}
function renderFilterDots() {
  const wrap = document.getElementById('eqDots');
  if (!wrap) return;
  wrap.innerHTML = '';
  EQ_FILTERS.forEach((_, i) => {
    const d = document.createElement('span');
    d.className = 'dot' + (i === state.eqFilterIdx ? ' is-active' : '');
    wrap.appendChild(d);
  });

  // mirror on consumables (decorative)
  const wrap2 = document.getElementById('conDots');
  if (wrap2 && wrap2.children.length === 0) {
    [0, 1, 2, 3].forEach(i => {
      const d = document.createElement('span');
      d.className = 'dot' + (i === 0 ? ' is-active' : '');
      wrap2.appendChild(d);
    });
  }
}

/* ----------------- EQUIPMENT GRID ----------------- */
function filterEquipment() {
  const f = EQ_FILTERS[state.eqFilterIdx];
  if (f === 'All') return EQUIPMENT;
  if (f === 'Weapons')     return EQUIPMENT.filter(e => e.kind === 'main' || e.kind === 'off');
  if (f === 'Armor')       return EQUIPMENT.filter(e => e.kind === 'head' || e.kind === 'armor');
  if (f === 'Accessories') return EQUIPMENT.filter(e => e.kind === 'acc');
  return EQUIPMENT;
}
function populateEquipmentGrid() {
  const grid = document.getElementById('eqGrid');
  if (!grid) return;
  grid.innerHTML = '';
  const items = filterEquipment().filter(it => !state.trashed.includes(it.id));
  for (let i = 0; i < 30; i++) {
    const it = items[i];
    grid.appendChild(makeSlot(it, 'equipment'));
  }
}

/* ----------------- CONSUMABLES GRID ----------------- */
function populateConsumablesGrid() {
  const grid = document.getElementById('conGrid');
  if (!grid) return;
  grid.innerHTML = '';
  for (let i = 0; i < 24; i++) {
    const it = CONSUMABLES[i];
    grid.appendChild(makeSlot(it, 'consumables', { showCount: true }));
  }
}

/* ----------------- MATERIALS GRID ----------------- */
function populateMaterialsGrid() {
  const grid = document.getElementById('matGrid');
  if (!grid) return;
  grid.innerHTML = '';
  for (let i = 0; i < 30; i++) {
    const it = MATERIALS[i];
    grid.appendChild(makeSlot(it, 'materials', { showCount: true }));
  }
}

/* ----------------- QUEST LIST ----------------- */
function populateQuestList() {
  const list = document.getElementById('questList');
  if (!list) return;
  list.innerHTML = '';
  QUEST_ITEMS.forEach((q, i) => {
    const row = document.createElement('div');
    row.className = 'quest-row' + (i === 0 ? ' is-selected' : '');
    row.dataset.questId = q.id;
    row.innerHTML = `
      <div class="quest-row__icon">${q.glyph}</div>
      <div class="quest-row__body">
        <div class="quest-row__name">${escapeHtml(q.name)}</div>
        <div class="quest-row__sub">${escapeHtml(q.sub)}</div>
      </div>
      <div class="quest-row__seal ${q.questActive ? '' : 'quest-row__seal--done'}"
           title="${q.questActive ? 'Quest active' : 'No active quest'}">${q.questActive ? '!' : '✓'}</div>
    `;
    row.addEventListener('click', () => selectQuest(q.id));
    list.appendChild(row);
  });
}
function selectQuest(id) {
  const q = QUEST_ITEMS.find(x => x.id === id);
  if (!q) return;
  document.querySelectorAll('.quest-row').forEach(r => {
    r.classList.toggle('is-selected', r.dataset.questId === id);
  });
  document.getElementById('questName').textContent = q.name;
  document.getElementById('questSub').textContent = q.sub;
  document.getElementById('questBody').textContent = q.body;
  const seal = document.getElementById('questSeal');
  if (q.questActive) {
    seal.title = 'Quest active';
    seal.querySelector('span').textContent = '!';
    seal.style.background = '';
    seal.style.borderColor = '';
  } else {
    seal.title = 'Quest complete or none';
    seal.querySelector('span').textContent = '✓';
    seal.style.background = 'radial-gradient(circle at 30% 30%, #8a8a8a 0%, #4a4a4a 80%)';
    seal.style.borderColor = '#2a2a2a';
  }
  // update meta block
  const metaRows = document.querySelectorAll('.quest-card .quest-meta__row');
  if (metaRows[0]) metaRows[0].children[1].textContent = q.from;
  if (metaRows[1]) {
    const val = metaRows[1].children[1];
    if (q.questActive && q.quest !== '—') {
      val.classList.add('quest-meta__value--active');
      val.innerHTML = `<span class="quest-dot quest-dot--active"></span>${escapeHtml(q.quest)}`;
    } else {
      val.classList.remove('quest-meta__value--active');
      val.textContent = q.quest;
    }
  }
}

/* ----------------- SLOT MAKER ----------------- */
function makeSlot(it, source, opts = {}) {
  const slot = document.createElement('div');
  slot.className = 'slot';
  if (!it) {
    slot.classList.add('is-empty');
    slot.setAttribute('aria-label', 'Empty slot');
    return slot;
  }
  slot.dataset.itemId = it.id;
  slot.dataset.rarity = it.rarity || 'common';
  slot.dataset.source = source;
  slot.setAttribute('title', `${it.name}${opts.showCount && it.count != null ? ` ×${it.count}` : ''}`);

  const g = document.createElement('span');
  g.className = 'slot__glyph';
  g.textContent = it.glyph;
  slot.appendChild(g);

  if (opts.showCount && it.count != null && it.count > 1) {
    const c = document.createElement('span');
    c.className = 'slot__count';
    c.textContent = '×' + it.count;
    slot.appendChild(c);
  }

  // selection + tooltip update
  slot.addEventListener('click', () => selectItem(it, source));

  // hover (light)
  slot.addEventListener('mouseenter', () => previewItem(it, source));

  // drag
  slot.addEventListener('mousedown', (e) => beginDrag(e, slot, it, source));

  return slot;
}

function selectItem(it, source) {
  document.querySelectorAll('.inv-grid .slot.is-selected').forEach(s => s.classList.remove('is-selected'));
  const sel = document.querySelector(`.tab-pane.is-active .inv-grid .slot[data-item-id="${it.id}"]`);
  if (sel) sel.classList.add('is-selected');
  state.selectedSlotId = it.id;
  previewItem(it, source);
}

function previewItem(it, source) {
  if (source === 'equipment') updateEqCard(it);
  // Consumables/Materials cards in the mock show a single fixed example for clarity;
  // hook live updates here if you want richer behavior later.
}

function updateEqCard(it) {
  const name = document.getElementById('itemName');
  const sub  = document.getElementById('itemSub');
  const icon = document.getElementById('itemIcon');
  const desc = document.getElementById('itemDesc');
  const eff  = document.getElementById('itemEffects');
  if (!name) return;
  name.textContent = it.name;
  const kindLabel = ({ main: 'Main Hand', off: 'Off Hand', head: 'Head', armor: 'Armor', acc: 'Accessory' })[it.kind] || 'Equipment';
  sub.textContent  = `[Equipment · ${kindLabel}]`;
  icon.dataset.rarity = it.rarity || 'common';
  icon.querySelector('span').textContent = it.glyph || '✦';
  desc.textContent = it.desc || 'No description.';
  eff.innerHTML = '';
  (it.effects || []).forEach(e => {
    const pill = document.createElement('div');
    pill.className = 'effect-pill effect-pill--pos';
    pill.textContent = e;
    eff.appendChild(pill);
  });
}

/* ----------------- LEGEND TOGGLE ----------------- */
function initLegendToggle() {
  const btn = document.getElementById('legendToggle');
  if (!btn) return;
  btn.addEventListener('click', () => {
    const on = btn.getAttribute('aria-pressed') === 'true';
    btn.setAttribute('aria-pressed', on ? 'false' : 'true');
    btn.innerHTML = `<span class="legend-toggle__dot"></span> Annotations: ${on ? 'OFF' : 'ON'}`;
    document.body.classList.toggle('annotations-off', on);
  });
}

/* ----------------- TRASH SLOTS (drag target) ----------------- */
function initTrashSlots() {
  const trashes = document.querySelectorAll('.trash-slot');
  trashes.forEach(t => {
    t.addEventListener('mouseenter', () => {
      if (state.drag) t.classList.add('is-armed');
    });
    t.addEventListener('mouseleave', () => t.classList.remove('is-armed'));
    t.addEventListener('mouseup', () => {
      if (state.drag) confirmTrash();
    });
  });
}
function confirmTrash() {
  const it = state.drag.item;
  state.trashed.push(it.id);
  showTrashFlash(it.name);
  endDrag(true);
  populateEquipmentGrid();
}
function showTrashFlash(name) {
  const flash = document.getElementById('trashFlash');
  document.getElementById('trashFlashName').textContent = name;
  flash.classList.add('is-on');
  setTimeout(() => flash.classList.remove('is-on'), 950);
}

/* ----------------- DRAG GHOST ----------------- */
function initDragGhost() {
  document.addEventListener('mousemove', (e) => {
    if (!state.drag) return;
    const ghost = document.getElementById('dragGhost');
    ghost.style.left = e.clientX + 'px';
    ghost.style.top  = e.clientY + 'px';
  });
  document.addEventListener('mouseup', () => {
    if (state.drag) endDrag(false);
  });
}

function beginDrag(e, slot, it, source) {
  if (e.button !== 0) return;
  e.preventDefault();
  state.drag = { slot, item: it, source };
  slot.classList.add('is-dragging');
  const ghost = document.getElementById('dragGhost');
  ghost.textContent = it.glyph;
  ghost.style.left = e.clientX + 'px';
  ghost.style.top  = e.clientY + 'px';
  ghost.hidden = false;
}
function endDrag(consumed) {
  if (!state.drag) return;
  const { slot } = state.drag;
  if (slot) slot.classList.remove('is-dragging');
  document.querySelectorAll('.trash-slot').forEach(t => t.classList.remove('is-armed'));
  document.getElementById('dragGhost').hidden = true;
  state.drag = null;
}

/* ----------------- HELPERS ----------------- */
function escapeHtml(s) {
  return (s || '').replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}
