(() => {
  'use strict';

  const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ox_doorlock';
  const root = document.getElementById('root');

  const defaultDoor = () => ({
    name: '', passcode: '', autolock: 0,
    items: [{ name: '', metadata: '', remove: false }],
    characters: [''], groups: [{ name: '', grade: undefined }],
    maxDistance: 0, doorRate: 0, lockSound: '', unlockSound: '',
    lockpickDifficulty: [''], auto: false, state: false, lockpick: false,
    hideUi: false, doors: false, holdOpen: false,
  });

  let doors = [];
  let sounds = [''];
  let visible = false;
  let route = 'doors';
  let tab = 'general';
  let current = defaultDoor();
  let clipboard = null;
  let query = '';
  let page = 1;
  let sortKey = null;
  let sortDirection = 'asc';
  let modal = null;
  let toastTimer = null;

  const post = async (event, data = {}) => {
    try {
      const response = await fetch(`https://${resourceName}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
      });
      return await response.json().catch(() => ({}));
    } catch (_) {
      return {};
    }
  };

  const esc = (value) => String(value ?? '')
    .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;').replaceAll("'", '&#039;');
  const clone = (value) => JSON.parse(JSON.stringify(value));

  function normalizeDoor(data) {
    const groups = data && data.groups && !Array.isArray(data.groups)
      ? Object.entries(data.groups).map(([name, grade]) => ({ name, grade: Number(grade) || 0 }))
      : (data?.groups || [{ name: '', grade: undefined }]);

    return {
      ...defaultDoor(), ...clone(data || {}),
      state: data?.state === 1 || data?.state === true,
      characters: data?.characters?.length ? clone(data.characters) : [''],
      groups: groups.length ? groups : [{ name: '', grade: undefined }],
      items: data?.items?.length ? clone(data.items) : [{ name: '', metadata: '', remove: false }],
      lockpickDifficulty: data?.lockpickDifficulty?.length ? clone(data.lockpickDifficulty) : [''],
    };
  }

  function serialiseDoor() {
    const data = clone(current);
    data.name = data.name || null;
    data.passcode = data.passcode || null;
    data.lockSound = data.lockSound || null;
    data.unlockSound = data.unlockSound || null;
    data.autolock = Number(data.autolock) || null;
    data.maxDistance = Number(data.maxDistance) || 2;
    data.doorRate = data.doorRate ? Number(data.doorRate) + 0.0 : null;
    data.auto = data.auto || null;
    data.lockpick = data.lockpick || null;
    data.hideUi = data.hideUi || null;
    data.holdOpen = data.holdOpen || null;

    data.items = (data.items || []).filter((item) => item.name).map((item) => ({
      name: item.name,
      metadata: item.metadata || null,
      remove: item.remove || null,
    }));

    data.characters = (data.characters || []).filter((value) => String(value).trim() !== '').map((value) => {
      const number = Number(value);
      return Number.isNaN(number) ? value : number;
    });

    const groupObject = {};
    (data.groups || []).forEach((group) => {
      if (group.name) groupObject[group.name] = Number(group.grade) || 0;
    });
    data.groups = Object.keys(groupObject).length ? groupObject : null;
    data.lockpickDifficulty = (data.lockpickDifficulty || []).filter((value) => value !== '');
    return data;
  }

  function svg(path, size = 20, viewBox = '0 0 24 24') {
    return `<svg aria-hidden="true" viewBox="${viewBox}" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${path}</svg>`;
  }

  const icons = {
    plus: svg('<path d="M12 5v14M5 12h14"/>'),
    search: svg('<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>'),
    close: svg('<path d="M6 6l12 12M18 6 6 18"/>'),
    dots: svg('<circle cx="12" cy="5" r="1" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1" fill="currentColor" stroke="none"/><circle cx="12" cy="19" r="1" fill="currentColor" stroke="none"/>'),
    selector: svg('<path d="m8 9 4-4 4 4M16 15l-4 4-4-4"/>', 16),
    up: svg('<path d="m7 14 5-5 5 5"/>', 16),
    down: svg('<path d="m7 10 5 5 5-5"/>', 16),
    settings: svg('<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4V21a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H2.8v-4H3a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1A1.7 1.7 0 0 0 9 4.6 1.7 1.7 0 0 0 10 3V2.8h4V3a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1Z"/>'),
    copy: svg('<rect x="9" y="9" width="10" height="10" rx="2"/><path d="M15 9V7a2 2 0 0 0-2-2H7a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2"/>'),
    teleport: svg('<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>'),
    trash: svg('<path d="M4 7h16M9 7V4h6v3M7 7l1 13h8l1-13M10 11v5M14 11v5"/>'),
    back: svg('<path d="m9 7-5 5 5 5M4 12h10a5 5 0 0 1 5 5"/>'),
    user: svg('<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>'),
    briefcase: svg('<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V4h8v3M3 12h18"/>'),
    bottle: svg('<path d="M9 3h6M10 3v5l-4 7a4 4 0 0 0 3.5 6h5a4 4 0 0 0 3.5-6l-4-7V3M8 14h8"/>'),
    lock: svg('<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>'),
    bell: svg('<path d="M18 8a6 6 0 1 0-12 0c0 7-3 7-3 7h18s-3 0-3-7M10 19h4"/>'),
    clipboard: svg('<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V2h6v2M8 13l2 2 5-5"/>'),
    question: svg('<circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.7 2.7 0 1 1 4.2 2.3c-1.2.7-1.7 1.2-1.7 2.7M12 18h.01"/>', 18),
  };

  function showToast(message) {
    const toast = document.querySelector('.toast');
    if (!toast) return;
    toast.textContent = message;
    toast.classList.add('active');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('active'), 1800);
  }

  function filteredDoors() {
    const text = query.trim().toLowerCase();
    const list = doors.filter((door) => !text
      || String(door.name || '').toLowerCase().includes(text)
      || String(door.zone || '').toLowerCase().includes(text));

    if (sortKey) {
      list.sort((a, b) => {
        const av = a[sortKey] ?? '';
        const bv = b[sortKey] ?? '';
        const result = typeof av === 'number' && typeof bv === 'number'
          ? av - bv : String(av).localeCompare(String(bv));
        return sortDirection === 'asc' ? result : -result;
      });
    }
    return list;
  }

  function sortIcon(key) {
    if (sortKey !== key) return icons.selector;
    return sortDirection === 'asc' ? icons.up : icons.down;
  }

  function doorsMarkup() {
    const list = filteredDoors();
    const pageCount = Math.max(1, Math.ceil(list.length / 8));
    if (page > pageCount) page = pageCount;
    const pageRows = list.slice((page - 1) * 8, page * 8);

    return `<section class="doors-view">
      <div class="header">
        <button class="action-icon action-icon-light" data-action="new" title="Create a new door">${icons.plus}</button>
        <label class="search-input"><span>${icons.search}</span><input id="search" placeholder="Search" value="${esc(query)}"></label>
        <button class="close-button" data-action="close" title="Close">${icons.close}</button>
      </div>
      <div class="door-table-layout">
        ${pageRows.length ? `<table class="door-table">
          <thead><tr>
            <th><button class="header-sort" data-sort="id"><span>ID</span>${sortIcon('id')}</button></th>
            <th><button class="header-sort" data-sort="name"><span>Name</span>${sortIcon('name')}</button></th>
            <th><button class="header-sort" data-sort="zone"><span>Zone</span>${sortIcon('zone')}</button></th>
            <th>State</th>
            <th class="action-heading">Options</th>
          </tr></thead>
          <tbody>${pageRows.map((door) => {
            const locked = door.state === 1 || door.state === true;
            return `<tr>
            <td>${esc(door.id)}</td><td>${esc(door.name)}</td><td>${esc(door.zone || '')}</td>
            <td><span class="door-state ${locked ? 'locked' : 'unlocked'}">${locked ? 'Locked' : 'Unlocked'}</span></td>
            <td class="action-cell"><div class="row-options">
              <button class="row-action" data-door-action="settings" data-id="${door.id}" title="Edit door">${icons.settings}<span>Edit</span></button>
              <button class="row-action" data-door-action="copy" data-id="${door.id}" title="Copy settings">${icons.copy}<span>Copy</span></button>
              <button class="row-action" data-door-action="teleport" data-id="${door.id}" title="Teleport to door">${icons.teleport}<span>Go</span></button>
              <button class="row-action danger" data-door-action="delete" data-id="${door.id}" title="Delete door">${icons.trash}<span>Delete</span></button>
            </div></td>
          </tr>`;
          }).join('')}</tbody>
        </table>` : `<div class="empty-state">${icons.search}<span>No results found</span></div>`}
        ${pageCount > 1 ? `<div class="pagination">${Array.from({ length: pageCount }, (_, index) => `<button data-page="${index + 1}" class="${page === index + 1 ? 'active' : ''}">${index + 1}</button>`).join('')}</div>` : ''}
      </div>
    </section>`;
  }

  function field(label, key, type, value, info, spanTwo = false) {
    return `<label class="field ${spanTwo ? 'span-two' : ''}">
      <span class="field-label">${label}${info ? `<span class="info-icon" title="${esc(info)}">${icons.question}</span>` : ''}</span>
      <input class="mantine-input" type="${type}" step="0.1" data-field="${key}" value="${esc(value ?? '')}">
    </label>`;
  }

  function switchesMarkup() {
    const values = [
      ['state', 'Locked'], ['doors', 'Double'], ['auto', 'Automatic'],
      ['lockpick', 'Lockpick'], ['hideUi', 'Hide UI'], ['holdOpen', 'Hold open'],
    ];
    return `<div class="switch-grid">${values.map(([key, label]) => `<label class="switch-row"><span>${label}</span><input type="checkbox" data-field="${key}" ${current[key] ? 'checked' : ''}><i></i></label>`).join('')}</div>`;
  }

  function generalMarkup() {
    return `<div class="general-grid">
      ${field('Door name', 'name', 'text', current.name)}
      ${field('Passcode', 'passcode', 'text', current.passcode)}
      ${field('Autolock Interval', 'autolock', 'number', current.autolock, 'Time in seconds after which the door will be locked')}
      ${field('Interact Distance', 'maxDistance', 'number', current.maxDistance, 'Controls the distance from which the player can interact with the door')}
      ${field('Door Rate', 'doorRate', 'number', current.doorRate, 'Speed the automatic door will move at', true)}
    </div>${switchesMarkup()}`;
  }

  function rowActionButton(kind, index, type, title, content, className = '') {
    return `<button class="transparent-action ${className}" data-row-action="${type}" data-kind="${kind}" data-index="${index}" title="${title}">${content}</button>`;
  }

  function charactersMarkup() {
    return `<div class="rows">${current.characters.map((value, index) => `<div class="form-row">
      <input class="mantine-input fill" data-array="characters" data-index="${index}" placeholder="Character Id" value="${esc(value)}">
      ${rowActionButton('characters', index, 'remove', 'Delete row', icons.trash, 'danger')}
    </div>`).join('')}</div>${addRowButton('characters')}`;
  }

  function groupsMarkup() {
    return `<div class="rows">${current.groups.map((value, index) => `<div class="form-row">
      <input class="mantine-input fill" data-array="groups" data-prop="name" data-index="${index}" placeholder="Group" value="${esc(value.name)}">
      <input class="mantine-input grade" type="number" data-array="groups" data-prop="grade" data-index="${index}" placeholder="Grade" value="${esc(value.grade ?? '')}">
      ${rowActionButton('groups', index, 'remove', 'Delete row', icons.trash, 'danger')}
    </div>`).join('')}</div>${addRowButton('groups')}`;
  }

  function itemsMarkup() {
    return `<div class="rows">${current.items.map((value, index) => `<div class="form-row">
      <input class="mantine-input item-name" data-array="items" data-prop="name" data-index="${index}" placeholder="Item" value="${esc(value.name)}">
      ${rowActionButton('items', index, 'options', 'Item options', icons.settings)}
      ${rowActionButton('items', index, 'remove', 'Delete row', icons.trash, 'danger')}
    </div>`).join('')}</div>${addRowButton('items')}`;
  }

  function difficultyValue(value) {
    if (typeof value === 'object') return 'custom';
    return value || '';
  }

  function lockpickMarkup() {
    return `<div class="rows">${current.lockpickDifficulty.map((value, index) => {
      const difficulty = difficultyValue(value);
      const label = { easy: 'Easy', medium: 'Medium', hard: 'Hard', custom: 'Custom' }[difficulty] || 'Choose difficulty';
      const detail = typeof value === 'object' ? `Area ${esc(value.areaSize)} · Speed ${esc(value.speedMultiplier)}` : 'Preset option';
      return `<div class="form-row">
        <div class="option-summary item-name"><strong>${esc(label)}</strong><small>${detail}</small></div>
        ${rowActionButton('lockpickDifficulty', index, 'options', 'Edit option', icons.settings)}
        ${rowActionButton('lockpickDifficulty', index, 'remove', 'Delete option', icons.trash, 'danger')}
      </div>`;
    }).join('')}</div>${addRowButton('lockpickDifficulty')}`;
  }

  function soundMarkup() {
    const options = [''].concat(sounds.filter(Boolean));
    const choices = (key, label, selected) => `<section class="option-section">
      <span class="field-label">${label}</span>
      <div class="option-grid sound-options">${options.map((value) => `<button type="button" class="option-card ${value === selected ? 'selected' : ''}" data-choice-field="${key}" data-choice-value="${esc(value)}">${esc(value || 'None')}</button>`).join('')}</div>
    </section>`;
    return `<div class="sound-stack">${choices('lockSound', 'Lock sound', current.lockSound)}${choices('unlockSound', 'Unlock sound', current.unlockSound)}</div>`;
  }

  function addRowButton(name) {
    return `<button class="add-row" data-add="${name}" title="Create a new row">${icons.plus}</button>`;
  }

  function settingsMarkup() {
    const tabs = [
      ['back', icons.back, 'Doors'], ['general', icons.settings, 'General'],
      ['characters', icons.user, 'Characters'], ['groups', icons.briefcase, 'Groups'],
      ['items', icons.bottle, 'Items'], ['lockpick', icons.lock, 'Lockpick'], ['sound', icons.bell, 'Sound'],
    ];

    const content = tab === 'general' ? generalMarkup()
      : tab === 'characters' ? charactersMarkup()
      : tab === 'groups' ? groupsMarkup()
      : tab === 'items' ? itemsMarkup()
      : tab === 'lockpick' ? lockpickMarkup()
      : soundMarkup();

    return `<section class="settings-view">
      <nav class="vertical-tabs">${tabs.map(([value, icon, label]) => `<button class="vertical-tab ${tab === value && value !== 'back' ? 'active' : ''}" data-tab="${value}" ${value === 'lockpick' && !current.lockpick ? 'disabled' : ''}>${icon}<span>${label}</span></button>`).join('')}</nav>
      <div class="settings-content">
        <div class="settings-scroll">${content}</div>
        <div class="submit-row">
          <button class="confirm-button" data-action="confirm">Confirm door</button>
          <button class="outline-action" data-action="paste" ${clipboard ? '' : 'disabled'} title="${clipboard ? 'Apply copied settings' : 'No door settings copied'}">${icons.clipboard}</button>
          <button class="outline-action delete" data-action="delete-current" ${current.id ? '' : 'disabled'} title="Delete door">${icons.trash}</button>
        </div>
      </div>
    </section>`;
  }

  function confirmModalMarkup() {
    return `<div class="modal-card confirm-modal">
      <h3>${esc(modal.title)}</h3>
      <p>${modal.prefix || ''}<strong>${esc(modal.name || '')}</strong>${modal.suffix || ''}</p>
      <div class="modal-actions"><button data-modal="cancel">Cancel</button><button class="danger" data-modal="confirm">Confirm</button></div>
    </div>`;
  }

  function itemOptionsMarkup() {
    const item = current.items[modal.index] || { metadata: '', remove: false };
    return `<div class="modal-card small-modal">
      <h3>Item options</h3>
      <label class="field"><span class="field-label">Metadata type</span><input id="modal-metadata" class="mantine-input" value="${esc(item.metadata || '')}"></label>
      <label class="switch-row modal-switch"><span>Remove on use</span><input id="modal-remove" type="checkbox" ${item.remove ? 'checked' : ''}><i></i></label>
      <button class="modal-confirm-light" data-modal="save-item">Confirm</button>
    </div>`;
  }

  function difficultyModalMarkup() {
    const raw = current.lockpickDifficulty[modal.index];
    const selected = modal.selected ?? difficultyValue(raw);
    const custom = typeof raw === 'object' ? raw : { areaSize: '', speedMultiplier: '' };
    const options = [['easy', 'Easy'], ['medium', 'Medium'], ['hard', 'Hard'], ['custom', 'Custom']];
    return `<div class="modal-card small-modal">
      <h3>Lockpick difficulty</h3>
      <span class="field-label">Choose an option <b>*</b></span>
      <div class="option-grid difficulty-options">${options.map(([value, label]) => `<button type="button" class="option-card ${selected === value ? 'selected' : ''}" data-difficulty-choice="${value}">${label}</button>`).join('')}</div>
      <label class="field"><span class="field-label">Area size</span><span class="field-description">Skill check area size in degrees</span><input id="modal-area" class="mantine-input" type="number" max="360" value="${esc(custom.areaSize ?? '')}" ${selected !== 'custom' ? 'disabled' : ''}></label>
      <label class="field"><span class="field-label">Speed multiplier</span><span class="field-description">Number the indicator speed will be multiplied by</span><input id="modal-speed" class="mantine-input" type="number" step="0.01" value="${esc(custom.speedMultiplier ?? '')}" ${selected !== 'custom' ? 'disabled' : ''}></label>
      <button class="modal-confirm-light" data-modal="save-difficulty">Confirm</button>
    </div>`;
  }

  function modalMarkup() {
    if (!modal) return '';
    const body = modal.type === 'item' ? itemOptionsMarkup()
      : modal.type === 'difficulty' ? difficultyModalMarkup() : confirmModalMarkup();
    return `<div class="modal-overlay">${body}</div>`;
  }

  function render() {
    root.innerHTML = `<main class="app-shell ${visible ? 'visible' : ''}"><div class="ox-window">${route === 'doors' ? doorsMarkup() : settingsMarkup()}</div></main>${modalMarkup()}<div class="toast"></div>`;
    bindEvents();
  }

  function findDoor(id) { return doors.find((door) => Number(door.id) === Number(id)); }

  function confirmDelete(door) {
    modal = {
      type: 'confirm', title: 'Confirm deletion',
      prefix: 'Are you sure you want to delete ', name: door.name, suffix: '?',
      onConfirm: async () => { await post('deleteDoor', door.id); route = 'doors'; },
    };
    render();
  }

  function bindEvents() {
    document.querySelector('[data-action="new"]')?.addEventListener('click', () => {
      current = defaultDoor(); route = 'settings'; tab = 'general'; render();
    });
    document.querySelector('[data-action="close"]')?.addEventListener('click', closeUi);
    document.getElementById('search')?.addEventListener('input', (event) => {
      query = event.target.value; page = 1; render();
      const input = document.getElementById('search'); input?.focus(); input?.setSelectionRange(query.length, query.length);
    });

    document.querySelectorAll('[data-sort]').forEach((element) => element.addEventListener('click', () => {
      const key = element.dataset.sort;
      if (sortKey === key) sortDirection = sortDirection === 'asc' ? 'desc' : 'asc';
      else { sortKey = key; sortDirection = 'asc'; }
      render();
    }));
    document.querySelectorAll('[data-page]').forEach((element) => element.addEventListener('click', () => { page = Number(element.dataset.page); render(); }));
    document.querySelectorAll('[data-door-action]').forEach((element) => element.addEventListener('click', async () => {
      const action = element.dataset.doorAction;
      const door = findDoor(Number(element.dataset.id));
      if (!door) return;
      if (action === 'settings') { current = normalizeDoor(door); route = 'settings'; tab = 'general'; render(); }
      else if (action === 'copy') { clipboard = normalizeDoor(door); await post('notify', 'Settings copied'); render(); showToast('Settings copied'); }
      else if (action === 'teleport') { visible = false; render(); await post('teleportToDoor', door.id); }
      else if (action === 'delete') confirmDelete(door);
    }));

    document.querySelectorAll('[data-tab]').forEach((element) => element.addEventListener('click', () => {
      if (element.disabled) return;
      const value = element.dataset.tab;
      if (value === 'back') { route = 'doors'; tab = 'general'; }
      else tab = value;
      render();
    }));

    document.querySelectorAll('[data-field]').forEach((element) => {
      const eventType = element.type === 'checkbox' || element.tagName === 'SELECT' ? 'change' : 'input';
      element.addEventListener(eventType, () => {
        const key = element.dataset.field;
        current[key] = element.type === 'checkbox' ? element.checked
          : element.type === 'number' ? (element.value === '' ? '' : Number(element.value)) : element.value;
        if (key === 'lockpick' && !current.lockpick && tab === 'lockpick') { tab = 'general'; render(); }
      });
    });

    document.querySelectorAll('[data-choice-field]').forEach((element) => element.addEventListener('click', () => {
      current[element.dataset.choiceField] = element.dataset.choiceValue;
      render();
    }));

    document.querySelectorAll('[data-difficulty-choice]').forEach((element) => element.addEventListener('click', () => {
      modal.selected = element.dataset.difficultyChoice;
      render();
    }));

    document.querySelectorAll('[data-array]').forEach((element) => {
      const eventType = element.type === 'checkbox' || element.tagName === 'SELECT' ? 'change' : 'input';
      element.addEventListener(eventType, () => {
        const arrayName = element.dataset.array;
        const index = Number(element.dataset.index);
        const prop = element.dataset.prop;
        const value = element.type === 'checkbox' ? element.checked
          : element.type === 'number' ? (element.value === '' ? undefined : Number(element.value)) : element.value;
        if (prop) current[arrayName][index][prop] = value;
        else current[arrayName][index] = value;
      });
    });

    document.querySelectorAll('[data-add]').forEach((element) => element.addEventListener('click', () => {
      const name = element.dataset.add;
      if (name === 'characters') current.characters.push('');
      else if (name === 'groups') current.groups.push({ name: '', grade: undefined });
      else if (name === 'items') current.items.push({ name: '', metadata: '', remove: false });
      else if (name === 'lockpickDifficulty') current.lockpickDifficulty.push('');
      render();
    }));

    document.querySelectorAll('[data-row-action]').forEach((element) => element.addEventListener('click', () => {
      const kind = element.dataset.kind;
      const index = Number(element.dataset.index);
      if (element.dataset.rowAction === 'remove') {
        current[kind].splice(index, 1); render();
      } else if (kind === 'items') {
        modal = { type: 'item', index }; render();
      } else if (kind === 'lockpickDifficulty') {
        modal = { type: 'difficulty', index, selected: difficultyValue(current.lockpickDifficulty[index]) }; render();
      }
    }));

    document.querySelector('[data-action="confirm"]')?.addEventListener('click', async () => {
      visible = false; render(); await post('createDoor', serialiseDoor());
    });
    document.querySelector('[data-action="paste"]')?.addEventListener('click', async () => {
      if (!clipboard) return;
      const pasted = normalizeDoor(clipboard);
      current = { ...pasted, id: undefined, name: '' };
      await post('notify', 'Settings applied'); render(); showToast('Settings applied');
    });
    document.querySelector('[data-action="delete-current"]')?.addEventListener('click', () => current.id && confirmDelete(current));

    document.querySelector('[data-modal="cancel"]')?.addEventListener('click', () => { modal = null; render(); });
    document.querySelector('[data-modal="confirm"]')?.addEventListener('click', async () => {
      const action = modal?.onConfirm; modal = null; if (action) await action(); render();
    });
    document.querySelector('[data-modal="save-item"]')?.addEventListener('click', () => {
      const item = current.items[modal.index];
      item.metadata = document.getElementById('modal-metadata').value;
      item.remove = document.getElementById('modal-remove').checked;
      modal = null; render();
    });
    document.querySelector('[data-modal="save-difficulty"]')?.addEventListener('click', () => {
      const value = modal?.selected;
      if (!value) return;
      current.lockpickDifficulty[modal.index] = value === 'custom'
        ? { areaSize: Number(document.getElementById('modal-area').value), speedMultiplier: Number(document.getElementById('modal-speed').value) }
        : value;
      modal = null; render();
    });
  }

  async function closeUi() {
    visible = false; modal = null; render(); await post('exit');
  }

  window.addEventListener('message', (event) => {
    const message = event.data || {};
    const data = message.data;
    if (message.action === 'playSound' && data?.sound) {
      const audio = new Audio(`./sounds/${data.sound}.ogg`);
      audio.volume = Number(data.volume) || 0.3;
      audio.play().catch(() => {});
    } else if (message.action === 'setSoundFiles') {
      sounds = Array.isArray(data) ? data : [''];
    } else if (message.action === 'closeDoorEditor') {
      visible = false; modal = null; route = 'doors'; render();
    } else if (message.action === 'openDoorEditor') {
      visible = true; modal = null;
      if (data === undefined || data === null) route = 'doors';
      else {
        const door = findDoor(data);
        if (door) { current = normalizeDoor(door); route = 'settings'; tab = 'general'; }
        else route = 'doors';
      }
      render();
    } else if (message.action === 'setVisible') {
      // Legacy compatibility: a false payload is a close command, never an open command.
      if (data === false) {
        visible = false; modal = null; route = 'doors'; render();
      } else {
        visible = true; modal = null;
        if (data === undefined || data === null) route = 'doors';
        else {
          const door = findDoor(data);
          if (door) { current = normalizeDoor(door); route = 'settings'; tab = 'general'; }
          else route = 'doors';
        }
        render();
      }
    } else if (message.action === 'updateDoorData') {
      if (typeof data === 'number') doors = doors.filter((door) => Number(door.id) !== Number(data));
      else if (data && Object.prototype.hasOwnProperty.call(data, 'id')) {
        const index = doors.findIndex((door) => Number(door.id) === Number(data.id));
        if (index === -1) doors.push(data); else doors[index] = data;
      } else if (data) doors = Object.values(data);
      render();
    }
  });

  window.addEventListener('keydown', (event) => {
    if (!visible) return;
    if (event.key === 'Escape') {
      if (modal) { modal = null; render(); }
      else closeUi();
    }
  });
  render();
  requestAnimationFrame(() => post('ready'));
})();
