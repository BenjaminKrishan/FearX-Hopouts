const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'fx_hopouts';

const post = (name, data) =>
    fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    }).then((r) => r.json()).catch(() => null);

const lobby = document.getElementById('lobby');
const mhud = document.getElementById('mhud');
const countEl = document.getElementById('count');
const bannerEl = document.getElementById('banner');
const oobEl = document.getElementById('oob');
const endEl = document.getElementById('end');

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const nfmt = (n) => Number(n || 0).toLocaleString('en-US');

let inQueue = false;
let queueBusy = false;
let clockTimer = null;
let clockEnds = 0;
let bannerTimer = null;
let countTimer = null;
let leaderboard = [];
let searchText = '';
let sortKey = 'rating';
let sortDir = -1;

/* ── Config ───────────────────────────────────────────────────────────────
   Everything themeable — colours, logos, which tabs exist — is pushed from
   config.lua, so nothing below hardcodes a colour or an image path. */
const CFG = {
    ui: {},
    pages: { career: true, leaderboard: true, ranks: true, store: true, loadout: true },
    ranksEnabled: true,
    ranks: [],
    storeEnabled: true,
    loadoutEnabled: true,
    credits: { label: 'Hopout Credits', short: 'Credits', win: 0, loss: 0 },
    cash: { enabled: true, win: 0 },
    leaderboard: { showGang: true, showJackpot: true, showMonthly: true },
    friends: true
};

const DEFAULT_AVATAR = () => CFG.ui.defaultAvatar || 'img/logo.png';

function hexToRgb(hex) {
    if (typeof hex !== 'string') return null;
    let h = hex.trim().replace(/^#/, '');
    if (h.length === 3) h = h.split('').map((c) => c + c).join('');
    if (h.length !== 6 || /[^0-9a-f]/i.test(h)) return null;
    return [h.slice(0, 2), h.slice(2, 4), h.slice(4, 6)].map((p) => parseInt(p, 16)).join(', ');
}

// colour key -> [solid var, rgb-triple var]
const COLOR_VARS = {
    accent: ['--accent', '--accent-rgb'],
    accentText: ['--accent-text', null],
    text: ['--text', '--text-rgb'],
    background: ['--bg', '--bg-rgb'],
    panel: ['--panel', '--panel-rgb'],
    teamRed: ['--red', '--red-rgb'],
    teamBlue: ['--blue', '--blue-rgb'],
    positive: ['--positive', '--positive-rgb'],
    credits: ['--credits', '--credits-rgb'],
    ready: ['--ready', '--ready-rgb'],
    podiumGold: ['--gold1', '--gold1-rgb'],
    podiumSilver: ['--gold2', '--gold2-rgb'],
    podiumBronze: ['--gold3', '--gold3-rgb']
};

function applyTheme(ui) {
    const root = document.documentElement;
    const colors = (ui && ui.colors) || {};
    Object.keys(COLOR_VARS).forEach((key) => {
        const value = colors[key];
        if (!value) return;
        const [solid, triple] = COLOR_VARS[key];
        root.style.setProperty(solid, value);
        if (triple) {
            const rgb = hexToRgb(value);
            if (rgb) root.style.setProperty(triple, rgb);
        }
    });
    if (ui && ui.slotBanner) root.style.setProperty('--slot-banner', `url('${ui.slotBanner}')`);
}

function applyConfig(cfg) {
    Object.assign(CFG, cfg || {});
    CFG.ui = (cfg && cfg.ui) || {};
    const ui = CFG.ui;
    applyTheme(ui);

    if (ui.logo) document.getElementById('brand-logo').src = ui.logo;
    if (ui.jackpotIcon) document.getElementById('jackpot-icon').src = ui.jackpotIcon;
    if (ui.monthlyTrophy) document.getElementById('monthly-trophy').src = ui.monthlyTrophy;
    document.getElementById('brand-title').textContent = ui.title || 'HOPOUTS';
    document.getElementById('brand-sub').textContent = ui.subtitle || '';
    document.getElementById('launch-mode').textContent = ui.modeName || 'Hop Outs';

    const creditLabel = (CFG.credits && CFG.credits.label) || 'Hopout Credits';
    document.getElementById('cs-credits-label').textContent = creditLabel;
    document.getElementById('lo-credits-label').textContent = creditLabel;
    document.getElementById('launch-credits-label').textContent = (CFG.credits && CFG.credits.short) || 'Credits';
    document.getElementById('cs-sub').textContent = `Spend ${creditLabel.toLowerCase()} earned in matches.`;

    lobby.classList.toggle('no-ranks', !CFG.ranksEnabled);
    document.getElementById('launch-elo-row').classList.toggle('hidden', !CFG.ranksEnabled);

    // Tabs the server has switched off simply do not exist.
    setTabVisible('career', CFG.pages.career !== false);
    setTabVisible('lb', CFG.pages.leaderboard !== false);
    setTabVisible('ranks', CFG.pages.ranks !== false && CFG.ranksEnabled);
    setTabVisible('store', CFG.pages.store !== false && CFG.storeEnabled);
    setTabVisible('loadout', CFG.pages.loadout !== false && CFG.loadoutEnabled !== false);

    document.getElementById('friends-panel').classList.toggle('hidden', CFG.friends === false);
    const jackpot = CFG.leaderboard.showJackpot !== false;
    const monthly = CFG.leaderboard.showMonthly !== false;
    document.getElementById('jackpot-card').classList.toggle('hidden', !jackpot);
    document.getElementById('monthly-card').classList.toggle('hidden', !monthly);
    // The info row is a fixed 3-column grid; re-lay it out when a card is off.
    document.getElementById('lb-cards').style.gridTemplateColumns =
        jackpot && monthly ? '19rem 21rem 1fr' : (jackpot || monthly ? '19rem 1fr' : '1fr');

    if (!CFG.ranksEnabled) sortKey = 'wins';
    buildLbColumns();
}

function setTabVisible(page, visible) {
    const tab = document.querySelector(`.nav-tab[data-page="${page}"]`);
    if (tab) tab.classList.toggle('hidden', !visible);
}

function pageEnabled(id) {
    if (id === 'queue') return true;
    if (id === 'career') return CFG.pages.career !== false;
    if (id === 'lb') return CFG.pages.leaderboard !== false;
    if (id === 'ranks') return CFG.pages.ranks !== false && CFG.ranksEnabled;
    if (id === 'store') return CFG.pages.store !== false && CFG.storeEnabled;
    if (id === 'loadout') return CFG.pages.loadout !== false && CFG.loadoutEnabled !== false;
    return false;
}

/* ── Pages ── */
const PAGES = ['queue', 'loadout', 'career', 'lb', 'ranks', 'store'];

function showPage(id) {
    if (!pageEnabled(id)) id = 'queue';
    lobby.setAttribute('data-page', id);
    PAGES.forEach((p) => {
        const el = document.getElementById('page-' + p);
        if (el) el.classList.toggle('hidden', p !== id);
    });
    document.querySelectorAll('.nav-tab[data-page]').forEach((tab) => {
        tab.classList.toggle('active', tab.dataset.page === id);
    });
    loadPage(id);
}

document.querySelectorAll('.nav-tab[data-page]').forEach((tab) => {
    tab.addEventListener('click', () => showPage(tab.dataset.page));
});

/* ── Queue ── */
function setQueueUi() {
    const btn = document.getElementById('btn-start');
    btn.classList.toggle('queued', inQueue);
    document.getElementById('btn-start-label').textContent = inQueue ? 'In Queue...' : 'Start';
}

async function toggleQueue() {
    if (queueBusy) return;
    queueBusy = true;
    const resp = await post('queue', { join: !inQueue });
    queueBusy = false;
    if (resp && resp.ok !== false) {
        inQueue = resp.inQueue === true;
        setQueueUi();
    }
}

document.getElementById('btn-start').addEventListener('click', toggleQueue);

document.getElementById('slots').addEventListener('click', async (e) => {
    const kick = e.target.closest('[data-kick]');
    if (kick) {
        if (partyBusy) return;
        partyBusy = true;
        const resp = await post('partyKick', { slot: parseInt(kick.dataset.kick, 10) });
        partyBusy = false;
        if (resp && resp.ok === false && resp.reason) frStatus(resp.reason);
        return;
    }
    if (!e.target.closest('.slot.plus')) return;
    const q = document.getElementById('q-sub');
    if (q) {
        q.textContent = 'Invite friends from the panel to fill your lobby!';
        setTimeout(() => { q.textContent = 'Party up to queue together!'; }, 2500);
    }
});

/* ── Friends ── */
let friendsData = { friends: [], incoming: [], outgoing: [] };
let friendsBusy = false;

function frStatus(msg, good) {
    const el = document.getElementById('fr-add-status');
    el.textContent = msg;
    el.classList.toggle('good', good === true);
    el.classList.remove('hidden');
    clearTimeout(el.__t);
    el.__t = setTimeout(() => el.classList.add('hidden'), 3000);
}

function showFrPane(id) {
    ['friends', 'requests', 'add'].forEach((p) => {
        document.getElementById('fr-pane-' + p).classList.toggle('hidden', p !== id);
    });
    document.querySelectorAll('.fr-tab').forEach((tab) => {
        tab.classList.toggle('active', tab.dataset.fr === id);
    });
}

document.querySelectorAll('.fr-tab').forEach((tab) => {
    tab.addEventListener('click', () => showFrPane(tab.dataset.fr));
});

function frEmpty(title, sub) {
    return `<div class="fr-empty"><div class="fr-empty-title">${title}</div><div class="fr-empty-sub">${sub}</div></div>`;
}

function renderFriends() {
    const frCount = document.getElementById('fr-count');
    frCount.textContent = friendsData.friends.length;
    frCount.classList.toggle('hidden', friendsData.friends.length === 0);
    const reqCount = document.getElementById('req-count');
    reqCount.textContent = friendsData.incoming.length;
    reqCount.classList.toggle('hidden', friendsData.incoming.length === 0);

    const list = document.getElementById('fr-list');
    list.innerHTML = '';
    if (!friendsData.friends.length) {
        list.innerHTML = frEmpty('NO FRIENDS YET', 'Send a request from the Add tab using their server ID.');
    } else {
        friendsData.friends.forEach((f, i) => {
            const row = document.createElement('div');
            row.className = 'fr-row' + (f.online ? ' online' : '');
            row.style.animationDelay = `${i * 0.03}s`;
            row.innerHTML =
                `<img class="fr-ava" src="${esc(DEFAULT_AVATAR())}" alt="">` +
                `<span class="fr-name-col"><span class="fr-name">${esc(f.name)}</span>` +
                `<span class="fr-status"><span class="fr-dot"></span>${f.online ? 'Online' : 'Offline'}</span></span>` +
                (f.online
                    ? `<span class="fr-act" data-invite="${esc(f.license)}"><i class="fa-solid fa-bolt"></i>Invite</span>`
                    : `<span class="fr-act ghost">Offline</span>`);
            const inviteBtn = row.querySelector('[data-invite]');
            if (inviteBtn) {
                inviteBtn.addEventListener('click', async () => {
                    if (friendsBusy) return;
                    friendsBusy = true;
                    const resp = await post('friendsInvite', { license: f.license });
                    friendsBusy = false;
                    inviteBtn.innerHTML = resp && resp.ok ? '<i class="fa-solid fa-check"></i>Sent' : 'Failed';
                    if (resp && resp.ok === false && resp.reason) frStatus(resp.reason);
                    setTimeout(() => { inviteBtn.innerHTML = '<i class="fa-solid fa-bolt"></i>Invite'; }, 2200);
                });
            }
            list.appendChild(row);
        });
    }

    const reqs = document.getElementById('req-list');
    reqs.innerHTML = '';
    if (!friendsData.incoming.length && !friendsData.outgoing.length) {
        reqs.innerHTML = frEmpty('NO REQUESTS', 'Incoming and outgoing friend requests show up here.');
        return;
    }
    friendsData.incoming.forEach((r, i) => {
        const row = document.createElement('div');
        row.className = 'fr-row online';
        row.style.animationDelay = `${i * 0.03}s`;
        row.innerHTML =
            `<img class="fr-ava" src="${esc(DEFAULT_AVATAR())}" alt="">` +
            `<span class="fr-name-col"><span class="fr-name">${esc(r.name)}</span>` +
            `<span class="fr-status">Incoming request</span></span>` +
            `<span class="fr-act" data-acc><i class="fa-solid fa-check"></i></span>` +
            `<span class="fr-act deny" data-dec><i class="fa-solid fa-xmark"></i></span>`;
        row.querySelector('[data-acc]').addEventListener('click', () => respondRequest(r.id, true));
        row.querySelector('[data-dec]').addEventListener('click', () => respondRequest(r.id, false));
        reqs.appendChild(row);
    });
    friendsData.outgoing.forEach((r, i) => {
        const row = document.createElement('div');
        row.className = 'fr-row';
        row.style.animationDelay = `${(friendsData.incoming.length + i) * 0.03}s`;
        row.innerHTML =
            `<img class="fr-ava" src="${esc(DEFAULT_AVATAR())}" alt="">` +
            `<span class="fr-name-col"><span class="fr-name">${esc(r.name)}</span>` +
            `<span class="fr-status">Request sent</span></span>` +
            `<span class="fr-act ghost">Pending</span>`;
        reqs.appendChild(row);
    });
}

async function respondRequest(id, accept) {
    if (friendsBusy) return;
    friendsBusy = true;
    const resp = await post('friendsRespond', { id, accept });
    friendsBusy = false;
    if (resp && resp.friends) {
        friendsData = resp.friends;
        renderFriends();
    }
}

document.getElementById('fr-add-btn').addEventListener('click', async () => {
    if (friendsBusy) return;
    const input = document.getElementById('fr-add-input');
    const id = parseInt(input.value, 10);
    if (!id || id < 1) { frStatus('Enter a valid player ID!'); return; }
    friendsBusy = true;
    const resp = await post('friendsAdd', { id });
    friendsBusy = false;
    if (resp && resp.ok) {
        input.value = '';
        frStatus('Request sent!', true);
        if (resp.friends) { friendsData = resp.friends; renderFriends(); }
        showFrPane('requests');
    } else {
        frStatus((resp && resp.reason) || 'Could not send the request.');
    }
});

document.getElementById('fr-add-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') document.getElementById('fr-add-btn').click();
});

/* ── Leaderboard ──────────────────────────────────────────────────────────
   Columns are built from config: no gang column when the server has no gangs,
   no ELO column when ranks are switched off. */
function fmtPlaytime(seconds) {
    const h = Math.floor((seconds || 0) / 3600);
    const m = Math.floor(((seconds || 0) % 3600) / 60);
    return h > 0 ? `${h}h ${m}m` : `${m}m`;
}

const kdOf = (r) => (r.deaths > 0 ? r.kills / r.deaths : r.kills || 0);
const hsOf = (r) => (r.kills > 0 ? (r.headshots || 0) / r.kills : 0);

const LB_COLUMNS = [
    { k: 'rank', label: 'Rank', w: '4.75rem', sortAsc: true },
    { k: 'name', label: 'Name', w: '1fr', sortAsc: true },
    { k: 'gang', label: 'Gang', w: '7rem', sortAsc: true, when: () => CFG.leaderboard.showGang !== false },
    { k: 'kills', label: 'Kills', w: '4.5rem' },
    { k: 'deaths', label: 'Deaths', w: '4.75rem' },
    { k: 'kd', label: 'K/D', w: '4.25rem' },
    { k: 'wins', label: 'Wins', w: '4.25rem' },
    { k: 'losses', label: 'Losses', w: '4.75rem' },
    { k: 'hs', label: 'HS%', w: '4.25rem' },
    { k: 'playtime', label: 'Playtime', w: '6rem' },
    { k: 'rating', label: 'ELO', w: '4.5rem', when: () => CFG.ranksEnabled }
];

const LB_CELLS = {
    rank: (r) => {
        const podium = [CFG.ui.trophyGold, CFG.ui.trophySilver, CFG.ui.trophyBronze];
        const trophy = r.rank <= 3 && podium[r.rank - 1]
            ? `<img class="rank-trophy" src="${esc(podium[r.rank - 1])}" alt="">` : '';
        return `<span class="r-rank">${trophy}#${r.rank}</span>`;
    },
    name: (r) => `<span class="r-namecell"><img class="r-ava" src="${esc(r.avatar || DEFAULT_AVATAR())}" ` +
        `onerror="this.src='${esc(DEFAULT_AVATAR())}'" alt=""><span class="r-name">${esc(r.name || 'Unknown')}</span></span>`,
    gang: (r) => `<span><span class="r-gang-pill">${esc(r.gang || '—')}</span></span>`,
    kills: (r) => `<span class="r-dim">${nfmt(r.kills)}</span>`,
    deaths: (r) => `<span class="r-dim">${nfmt(r.deaths)}</span>`,
    kd: (r) => `<span class="r-kd">${kdOf(r).toFixed(2)}</span>`,
    wins: (r) => `<span class="r-dim">${nfmt(r.wins)}</span>`,
    losses: (r) => `<span class="r-dim">${nfmt(r.losses)}</span>`,
    hs: (r) => `<span class="r-dim">${Math.round(hsOf(r) * 100)}%</span>`,
    playtime: (r) => `<span class="r-dim">${fmtPlaytime(r.playtime)}</span>`,
    rating: (r) => `<span class="r-elo">${nfmt(r.rating)}</span>`
};

function activeColumns() {
    return LB_COLUMNS.filter((c) => !c.when || c.when());
}

function buildLbColumns() {
    const cols = activeColumns();
    document.getElementById('t-hopouts').style.setProperty('--lb-cols', cols.map((c) => c.w).join(' '));
    document.getElementById('t-cols').innerHTML = cols
        .map((c) => `<span data-k="${c.k}">${esc(c.label)}</span>`).join('');
    document.querySelectorAll('#t-cols span').forEach((col) => {
        col.addEventListener('click', () => {
            const k = col.dataset.k;
            const meta = LB_COLUMNS.find((c) => c.k === k);
            if (sortKey === k) sortDir = -sortDir;
            else { sortKey = k; sortDir = meta && meta.sortAsc ? 1 : -1; }
            renderTable();
        });
    });
}

function sortValue(row) {
    if (sortKey === 'name') return String(row.name || '').toLowerCase();
    if (sortKey === 'gang') return String(row.gang || '').toLowerCase();
    if (sortKey === 'kd') return kdOf(row);
    if (sortKey === 'hs') return hsOf(row);
    if (sortKey === 'rank') return row.rank;
    return row[sortKey] || 0;
}

function renderTable() {
    const rows = document.getElementById('t-rows');
    rows.innerHTML = '';
    document.querySelectorAll('#t-cols span').forEach((c) => c.classList.toggle('sorted', c.dataset.k === sortKey));
    const q = searchText.toLowerCase();
    let list = leaderboard.filter((r) => !q || String(r.name || '').toLowerCase().includes(q) || String(r.gang || '').toLowerCase().includes(q));
    list = list.slice().sort((a, b) => {
        const va = sortValue(a), vb = sortValue(b);
        if (typeof va === 'string') return sortDir * va.localeCompare(vb);
        return sortDir * (va - vb);
    });
    if (!list.length) {
        rows.innerHTML = '<div class="t-empty">No players found.</div>';
        return;
    }
    const cols = activeColumns();
    list.forEach((row, i) => {
        const el = document.createElement('div');
        el.className = 't-row' + (row.rank <= 3 ? ` r${row.rank}` : '') + (row.you ? ' you' : '');
        el.style.animationDelay = `${Math.min(i * 0.02, 0.35)}s`;
        el.innerHTML = cols.map((c) => LB_CELLS[c.k](row)).join('');
        rows.appendChild(el);
    });
}

/* ── Team slots ── */
const SLOT_FILL_ORDER = [1, 2, 4, 3, 5];   // must match server/main.lua
const SLOT_DISPLAY_ORDER = [3, 2, 1, 4, 5];
let youMeta = { name: '', rating: '' };
let lastTeam = { size: 1, slots: {}, avatars: {}, yourSlot: 1, leaderSlot: 1 };

function renderTeam(d) {
    if (d) {
        lastTeam = {
            size: Math.max(1, d.size || 1),
            slots: d.slots || {},
            avatars: d.avatars || {},
            yourSlot: d.yourSlot || 1,
            leaderSlot: d.leaderSlot || 1
        };
    }
    const t = lastTeam;
    const max = CFG.maxParty || 5;
    document.getElementById('q-count').textContent = `${t.size}/${max}`;
    document.getElementById('launch-squad').textContent = t.size > 1 ? `${t.size} players` : 'Solo';
    document.getElementById('btn-party-leave').classList.toggle('hidden', t.size < 2);
    let html = '';
    // Slots fill in the order 1,2,4,3,5 but are drawn left-to-right as 3,2,1,4,5,
    // so a smaller party keeps the leader centred.
    const usable = SLOT_FILL_ORDER.slice(0, max);
    SLOT_DISPLAY_ORDER.filter((s) => usable.includes(s)).forEach((slotNo) => {
        const name = t.slots[String(slotNo)];
        const crown = slotNo === t.leaderSlot ? '<i class="fa-solid fa-crown slot-crown"></i>' : '';
        const ava = t.avatars[String(slotNo)] || null;
        const avaHtml = (src) => src
            ? `<div class="slot-ava"><img src="${esc(src)}" onerror="this.replaceWith(Object.assign(document.createElement('i'),{className:'fa-solid fa-user'}))" alt=""></div>`
            : '<div class="slot-ava"><i class="fa-solid fa-user"></i></div>';

        if (slotNo === t.yourSlot) {
            html +=
                `<div class="slot you" id="slot-you">${crown}<div class="slot-banner"></div><div class="slot-inner">` +
                avaHtml(ava || youMeta.avatar) +
                `<div class="slot-meta"><span id="slot-name" class="slot-name">${esc(youMeta.name)}</span>` +
                `<span id="slot-rating" class="slot-rating">${esc(youMeta.rating)}</span></div>` +
                '<i class="fa-solid fa-microphone slot-mic"></i></div></div>';
        } else if (name) {
            const kick = t.yourSlot === t.leaderSlot
                ? `<div class="slot-kick" data-kick="${slotNo}" title="Kick from party"><i class="fa-solid fa-xmark"></i></div>`
                : '';
            html +=
                `<div class="slot filled">${crown}${kick}<div class="slot-inner">` +
                avaHtml(ava) +
                `<div class="slot-meta"><span class="slot-name">${esc(name)}</span>` +
                '<span class="slot-rating">In your party</span></div></div></div>';
        } else {
            html += '<div class="slot plus"></div>';
        }
    });
    document.getElementById('slots').innerHTML = html;
}

/* ── Match loadout HUD ── */
let loEquipment = [];

function fillLoCard(card, entry) {
    const img = card.querySelector('[data-lo-img]');
    const name = card.querySelector('[data-lo-name]');
    const kind = card.querySelector('[data-lo-kind]');
    if (!entry) {
        img.classList.add('hidden');
        img.removeAttribute('src');
        name.textContent = 'None';
        kind.textContent = '';
        card.classList.add('empty');
        return;
    }
    card.classList.remove('empty');
    img.classList.remove('hidden');
    img.src = entry.img || '';
    name.textContent = entry.label || '';
    kind.textContent = entry.kind || '';
}

function renderLoadout(d) {
    loEquipment = d.equipment || [];
    const root = document.getElementById('loadout');
    fillLoCard(root.querySelector('[data-lo="primary"]'), d.primary);
    fillLoCard(root.querySelector('[data-lo="secondary"]'), d.secondary);
    fillLoCard(root.querySelector('[data-lo="equipment"]'), loEquipment[0]);
    root.querySelectorAll('.lo-card').forEach((c) => c.classList.remove('active'));
    root.classList.remove('hidden');
}

function selectLoadout(d) {
    const root = document.getElementById('loadout');
    root.querySelectorAll('.lo-card').forEach((c) => c.classList.toggle('active', c.dataset.lo === d.role));
    if (d.role === 'equipment' && d.label) {
        const entry = loEquipment.find((e) => e && e.label === d.label);
        if (entry) fillLoCard(root.querySelector('[data-lo="equipment"]'), entry);
    }
}

/* ── Party ── */
let partyBusy = false;

function showPartyInvite(name) {
    document.getElementById('pi-name').textContent = name || 'A friend';
    document.getElementById('party-invite').classList.remove('hidden');
    showFrPane('friends');
}

function hidePartyInvite() {
    document.getElementById('party-invite').classList.add('hidden');
}

async function partyRespond(accept) {
    if (partyBusy) return;
    partyBusy = true;
    const resp = await post('partyRespond', { accept });
    partyBusy = false;
    hidePartyInvite();
    if (resp && resp.ok === false && resp.reason) frStatus(resp.reason);
}

document.getElementById('pi-accept').addEventListener('click', () => partyRespond(true));
document.getElementById('pi-decline').addEventListener('click', () => partyRespond(false));
document.getElementById('btn-party-leave').addEventListener('click', async () => {
    if (partyBusy) return;
    partyBusy = true;
    await post('partyLeave');
    partyBusy = false;
});

/* ── Ranks ── */
function renderRanks(rating) {
    const grid = document.getElementById('ranks-grid');
    const list = CFG.ranks || [];
    grid.style.setProperty('--rank-count', String(Math.max(1, list.length)));
    const cur = list.findIndex((r) => rating >= r.min && (r.max == null || rating < r.max));
    const badge = CFG.ui.rankBadge || 'img/rank-%s.png';
    grid.innerHTML = list.map((r, i) => {
        const mine = i === cur;
        const done = cur > i;
        const range = r.max != null ? `${r.min} – ${r.max}` : `${r.min}+`;
        let prog = '';
        if (mine) {
            if (r.max != null) {
                const pct = Math.max(4, Math.min(100, Math.round(((rating - r.min) / (r.max - r.min)) * 100)));
                const next = list[i + 1];
                prog = `<div class="rank-prog"><div class="rp-rail"><div class="rp-fill" style="width:${pct}%"></div></div><div class="rp-text">${rating} ELO · ${r.max - rating} to ${esc(next ? next.label : '')}</div></div>`;
            } else {
                prog = `<div class="rank-prog"><div class="rp-text">${rating} ELO · Peak rank</div></div>`;
            }
        }
        return `<div class="rank-card${mine ? ' mine' : ''}${done ? ' done' : ''}" style="--rc:${esc(r.color || '#fff')}">` +
            `<img class="rank-badge" src="${esc(badge.replace('%s', r.name || 'bronze'))}" onerror="this.style.visibility='hidden'" alt="">` +
            `<div class="rank-name">${esc(r.label || '')}</div>` +
            `<div class="rank-range">${range} ELO</div>` +
            `<div class="rank-pts"><span class="gain">+${r.win} win</span><span class="lose">−${r.loss} loss</span></div>` +
            prog +
            (mine ? '<div class="rank-you">YOU</div>' : '') +
            '</div>';
    }).join('');
}

/* ── Lobby fill ── */
function fillLobby(data) {
    const credits = Math.floor(data.credits || 0);
    document.getElementById('launch-credits').textContent = nfmt(credits);
    document.getElementById('cs-credits').textContent = nfmt(credits);
    document.getElementById('lo-credits').textContent = nfmt(credits);

    youMeta = {
        name: data.playerName || '',
        avatar: data.avatar || null,
        rating: CFG.ranksEnabled
            ? `${data.rating} ELO · Rank #${data.myRank || '—'}`
            : `Rank #${data.myRank || '—'} · ${nfmt(data.wins)}W`
    };
    renderTeam(null);
    document.getElementById('launch-elo').textContent = data.rating;

    document.getElementById('total-players').textContent = nfmt(data.totalPlayers);

    const jackpot = data.jackpot || {};
    document.getElementById('jackpot-label').textContent = jackpot.label || 'Jackpot';
    document.getElementById('jackpot-amount').textContent = typeof jackpot.amount === 'number'
        ? '$' + jackpot.amount.toLocaleString('en-US')
        : `$ ${jackpot.amount || 'TBA'}`;
    document.getElementById('jackpot-desc').textContent = jackpot.desc || '';

    const monthly = data.monthly || {};
    document.getElementById('monthly-title').textContent = (monthly.title || 'Compete Monthly').toUpperCase();
    document.getElementById('monthly-desc').textContent = monthly.desc || '';

    const kd = data.deaths > 0 ? data.kills / data.deaths : data.kills;
    const pills = [`<span class="ms-pill">Rank <b>#${data.myRank || '—'}</b></span>`];
    if (CFG.ranksEnabled) pills.push(`<span class="ms-pill">ELO <b>${nfmt(data.rating)}</b></span>`);
    pills.push(`<span class="ms-pill">W/L <b>${nfmt(data.wins)}/${nfmt(data.losses)}</b></span>`);
    pills.push(`<span class="ms-pill">K/D <b>${kd.toFixed(2)}</b></span>`);
    if (CFG.credits && CFG.credits.win > 0) {
        pills.push(`<span class="ms-pill">Win pays <b>${nfmt(CFG.credits.win)} ${esc(CFG.credits.short || 'credits')}</b></span>`);
    }
    if (data.cash && data.cash.enabled && data.cash.win > 0) {
        pills.push(`<span class="ms-pill">Win pays <b>$${nfmt(data.cash.win)}</b></span>`);
    }
    document.getElementById('my-strip').innerHTML = pills.join('');

    renderRanks(data.rating || 0);

    friendsData = data.friends || { friends: [], incoming: [], outgoing: [] };
    renderFriends();
    showFrPane(friendsData.incoming.length ? 'requests' : 'friends');
    if (data.partyInvite) showPartyInvite(data.partyInvite.name);
    else hidePartyInvite();

    leaderboard = (data.leaderboard || []).map((row, i) => ({ ...row, rank: i + 1 }));
    searchText = '';
    document.getElementById('search').value = '';
    sortKey = CFG.ranksEnabled ? 'rating' : 'wins';
    sortDir = -1;
    renderTable();

    inQueue = data.inQueue === true;
    setQueueUi();
}

document.getElementById('btn-close').addEventListener('click', () => post('close'));

document.getElementById('search').addEventListener('input', (e) => {
    searchText = e.target.value.trim();
    renderTable();
});

window.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || lobby.classList.contains('hidden')) return;
    post('close');
});

/* ── Match HUD ── */
function setScore(score) {
    document.getElementById('score-1').textContent = score ? score[1] || score['1'] || 0 : 0;
    document.getElementById('score-2').textContent = score ? score[2] || score['2'] || 0 : 0;
}

function fmtClock(ms) {
    const s = Math.max(0, Math.ceil(ms / 1000));
    return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

function startClock(ms) {
    clearInterval(clockTimer);
    clockEnds = Date.now() + ms;
    const el = document.getElementById('mid-timer');
    el.textContent = fmtClock(ms);
    clockTimer = setInterval(() => {
        const left = clockEnds - Date.now();
        el.textContent = fmtClock(left);
        if (left <= 0) clearInterval(clockTimer);
    }, 250);
}

function showBanner(text, lost) {
    clearTimeout(bannerTimer);
    bannerEl.textContent = text;
    bannerEl.classList.toggle('lost', lost === true);
    bannerEl.classList.remove('hidden');
    bannerTimer = setTimeout(() => bannerEl.classList.add('hidden'), 2600);
}

function runCountdown(ms, round) {
    clearInterval(countTimer);
    document.getElementById('mid-round').textContent = `ROUND ${round}`;
    document.getElementById('mid-timer').textContent = fmtClock(ms);
    let left = Math.ceil(ms / 1000);
    countEl.classList.remove('hidden');
    countEl.textContent = left;
    countTimer = setInterval(() => {
        left -= 1;
        if (left <= 0) {
            countEl.textContent = 'GO';
            setTimeout(() => countEl.classList.add('hidden'), 600);
            clearInterval(countTimer);
        } else {
            countEl.textContent = left;
        }
    }, 1000);
}

window.addEventListener('message', (event) => {
    if (!event.data || typeof event.data.action !== 'string') return;
    const { action, data } = event.data;

    if (action === 'config') {
        applyConfig(data || {});
    } else if (action === 'lobbyOpen') {
        fillLobby(data || {});
        showPage('queue');
        lobby.classList.remove('closing');
        lobby.classList.remove('hidden');
    } else if (action === 'lobbyClose') {
        if (!lobby.classList.contains('hidden')) {
            lobby.classList.add('closing');
            setTimeout(() => { lobby.classList.add('hidden'); lobby.classList.remove('closing'); }, 240);
        }
    } else if (action === 'matchStart') {
        lobby.classList.add('hidden');
        setScore(null);
        document.getElementById('mid-round').textContent = 'ROUND 1';
        document.getElementById('mid-timer').textContent = '—';
        mhud.classList.remove('hidden');
        const vsText = data.map ? `${data.map} · VS ${data.opponent || ''}` : `VS ${data.opponent || ''}`;
        showBanner(vsText.toUpperCase());
    } else if (action === 'countdown') {
        setScore(data.score);
        oobEl.classList.add('hidden');
        endEl.classList.add('hidden');
        runCountdown(data.ms || 3000, data.round || 1);
    } else if (action === 'live') {
        startClock(data.roundTime || 300000);
    } else if (action === 'roundEnd') {
        clearInterval(clockTimer);
        setScore(data.score);
        oobEl.classList.add('hidden');
        if (data.draw) showBanner('ROUND DRAW — RERUN');
        else if (data.won) showBanner('ROUND WON');
        else showBanner('ROUND LOST', true);
    } else if (action === 'matchEnd') {
        clearInterval(clockTimer);
        setScore(data.score);
        oobEl.classList.add('hidden');
        bannerEl.classList.add('hidden');
        endEl.classList.toggle('defeat', !data.won);
        document.getElementById('end-title').textContent = data.won ? 'VICTORY' : 'DEFEAT';
        const s = data.score || {};
        document.getElementById('end-score').textContent = `${s[1] || s['1'] || 0} — ${s[2] || s['2'] || 0}`;
        const delta = data.ratingDelta || 0;
        document.getElementById('end-rating').textContent = CFG.ranksEnabled
            ? `ELO ${nfmt(data.rating)} (${delta >= 0 ? '+' : ''}${delta})`
            : (data.won ? 'Match won' : 'Match lost');
        const reward = data.reward || {};
        const bits = [];
        if (reward.cash) bits.push(`+$${nfmt(reward.cash)}`);
        if (reward.credits) bits.push(`+${nfmt(reward.credits)} ${(CFG.credits && CFG.credits.short) || 'credits'}`);
        document.getElementById('end-reward').textContent = bits.join(' · ');
        endEl.classList.remove('hidden');
    } else if (action === 'matchHide') {
        clearInterval(clockTimer);
        clearInterval(countTimer);
        mhud.classList.add('hidden');
        countEl.classList.add('hidden');
        bannerEl.classList.add('hidden');
        oobEl.classList.add('hidden');
        endEl.classList.add('hidden');
        document.getElementById('loadout').classList.add('hidden');
        document.getElementById('squad').classList.add('hidden');
    } else if (action === 'loadout') {
        renderLoadout(data || {});
    } else if (action === 'loadoutSel') {
        selectLoadout(data || {});
    } else if (action === 'storm') {
        document.getElementById('oob-sub').textContent = "You're taking storm damage — get back inside the zone!";
        oobEl.classList.remove('hidden');
    } else if (action === 'stormClear') {
        oobEl.classList.add('hidden');
    } else if (action === 'teamUpdate') {
        renderTeam(data || {});
    } else if (action === 'queueState') {
        inQueue = !!(data && data.inQueue);
        setQueueUi();
    } else if (action === 'partyInvite') {
        showPartyInvite(data && data.name);
    } else if (action === 'friendsUpdate') {
        friendsData = data || { friends: [], incoming: [], outgoing: [] };
        renderFriends();
    } else if (action === 'readyCheck') {
        showReady(data);
    } else if (action === 'readyDone') {
        hideReady();
    } else if (action === 'squad') {
        renderSquad(data);
    } else if (action === 'squadHide') {
        document.getElementById('squad').classList.add('hidden');
    }
});

/* ── Career ─────────────────────────────────────────────────────────────── */
const HEAD_STATS = [
    { key: 'playedHours', label: 'Played', icon: 'fa-stopwatch', suffix: ' Hrs' },
    { key: 'wins', label: 'Wins', icon: 'fa-trophy' },
    { key: 'losses', label: 'Losses', icon: 'fa-circle-minus' }
];

const CAREER_TILES = [
    { key: 'matches', label: 'Matches', icon: 'fa-flag-checkered', sub: (d) => nfmt(d.wins) + 'W / ' + nfmt(d.losses) + 'L' },
    { key: 'winRate', label: 'Win Rate', icon: 'fa-percent', suffix: '%', sub: (d) => 'across ' + nfmt(d.matches) + ' matches' },
    { key: 'wl', label: 'W/L', icon: 'fa-scale-balanced', sub: (d) => nfmt(d.wins) + ' / ' + nfmt(d.losses) },
    { key: 'kills', label: 'Eliminations', icon: 'fa-crosshairs', sub: (d) => nfmt(d.kd) + ' K/D' },
    { key: 'deaths', label: 'Deaths', icon: 'fa-skull', sub: () => 'in hopouts matches' },
    { key: 'kd', label: 'K/D', icon: 'fa-chart-line', sub: (d) => nfmt(d.kills) + ' / ' + nfmt(d.deaths) },
    { key: 'headshots', label: 'Headshots', icon: 'fa-bullseye', sub: (d) => nfmt(d.hsRate) + '% of kills' },
    { key: 'streak', label: 'Win Streak', icon: 'fa-fire', sub: (d) => 'best: ' + nfmt(d.bestStreak) },
    { key: 'bestStreak', label: 'Best Streak', icon: 'fa-medal', sub: () => 'personal record' },
    { key: 'playedHours', label: 'Played', icon: 'fa-stopwatch', suffix: ' Hrs', sub: () => 'time in matches' },
    {
        key: 'rating', label: 'Rating', icon: 'fa-chart-simple', when: () => CFG.ranksEnabled,
        sub: (d) => d.rankLabel || 'unranked'
    },
    {
        key: 'rank', label: 'Global Rank', icon: 'fa-ranking-star', prefix: '#', when: () => !CFG.ranksEnabled,
        sub: () => 'by wins'
    },
    { key: 'credits', label: 'Credits', icon: 'fa-coins', sub: () => 'spendable in the store', creditLabel: true }
];

async function loadCareer() {
    const d = await post('career');
    if (!d || !d.name) return;

    document.getElementById('c-name').textContent = d.name;
    document.getElementById('c-rating').textContent = nfmt(d.rating);
    document.getElementById('c-rank').textContent = d.rank > 0 ? '#' + nfmt(d.rank) + ' global' : 'unranked';
    document.getElementById('c-elo-part').classList.toggle('hidden', !CFG.ranksEnabled);

    const pfp = document.getElementById('c-avatar');
    pfp.innerHTML = d.avatar
        ? '<img src="' + esc(d.avatar) + '" onerror="this.remove()">'
        : '<i class="fa-solid fa-user"></i>';

    // Progress through the current rank tier, or through the win count when
    // ranks are off.
    let pct = 0;
    if (CFG.ranksEnabled) {
        const tier = (CFG.ranks || []).find((r) => d.rating >= r.min && (r.max == null || d.rating < r.max));
        if (tier) {
            pct = tier.max != null
                ? Math.round(((d.rating - tier.min) / (tier.max - tier.min)) * 100)
                : 100;
        }
    } else {
        pct = Math.min(100, (d.winRate || 0));
    }
    pct = Math.max(0, Math.min(100, pct));
    requestAnimationFrame(() => { document.getElementById('c-fill').style.width = pct + '%'; });

    document.getElementById('c-head').innerHTML = HEAD_STATS.map((h) =>
        '<div class="hstat"><div class="hstat-ico"><i class="fa-solid ' + h.icon + '"></i></div>' +
        '<div><div class="hstat-val">' + esc(nfmt(d[h.key]) + (h.suffix || '')) + '</div>' +
        '<div class="hstat-lbl">' + esc(h.label) + '</div></div></div>').join('');

    const tiles = CAREER_TILES.filter((t) => !t.when || t.when());
    document.getElementById('c-tiles').innerHTML = tiles.map((t, i) => {
        const label = t.creditLabel ? ((CFG.credits && CFG.credits.short) || 'Credits') : t.label;
        const value = (t.prefix || '') + nfmt(d[t.key]) + (t.suffix || '');
        return '<div class="c-tile" style="animation-delay:' + (i * 0.04) + 's">' +
            '<div class="c-tile-head"><div class="c-tile-ico"><i class="fa-solid ' + t.icon + '"></i></div>' +
            '<div class="c-tile-name">' + esc(label) + '</div></div>' +
            '<div class="c-tile-val">' + esc(value) + '</div>' +
            '<div class="c-tile-sub">' + esc(t.sub(d)) + '</div></div>';
    }).join('');
}

/* ── Store ──────────────────────────────────────────────────────────────── */
const RARITY_RGB = {
    exotic: '186,250,37', rare: '49,90,197', epic: '255,79,195', mythic: '255,79,195',
    legendary: '255,219,15', onepercent: '197,49,49', neutral: '239,239,239'
};

const store = { items: [], category: null, credits: 0, busy: false };
const loadout = { items: [], owned: {}, equipped: {}, category: null, credits: 0, busy: false };

function setCredits(value) {
    store.credits = Math.max(0, Math.floor(value || 0));
    loadout.credits = store.credits;
    document.getElementById('cs-credits').textContent = nfmt(store.credits);
    document.getElementById('lo-credits').textContent = nfmt(store.credits);
    document.getElementById('launch-credits').textContent = nfmt(store.credits);
}

function renderStore() {
    const grid = document.getElementById('cs-grid');
    const empty = document.getElementById('cs-empty');
    const cats = [];
    store.items.forEach((i) => { if (!cats.includes(i.category)) cats.push(i.category); });

    if (!store.items.length) {
        document.getElementById('cs-cats').innerHTML = '';
        grid.innerHTML = '';
        empty.classList.remove('hidden');
        return;
    }
    empty.classList.add('hidden');
    if (!store.category || !cats.includes(store.category)) store.category = cats[0];

    document.getElementById('cs-cats').innerHTML = cats.map((c) =>
        `<div class="pg${c === store.category ? ' active' : ''}" data-c="${esc(c)}">${esc(c)}</div>`).join('');
    document.querySelectorAll('#cs-cats .pg').forEach((p) => {
        p.addEventListener('click', () => { store.category = p.dataset.c; renderStore(); });
    });

    grid.innerHTML = store.items.filter((i) => i.category === store.category).map((it, i) => {
        const tier = RARITY_RGB[it.rarity] || RARITY_RGB.neutral;
        const art = it.image
            ? `<img src="${esc(it.image)}" onerror="this.replaceWith(Object.assign(document.createElement('i'),{className:'fa-solid ${esc(it.icon || 'fa-gift')}'}))">`
            : `<i class="fa-solid ${esc(it.icon || 'fa-gift')}"></i>`;
        const affordable = store.credits >= it.price;
        return `<div class="pick shop${affordable ? '' : ' broke'}" data-id="${esc(it.id)}" ` +
            `style="--tier:${tier};animation-delay:${i * 0.03}s">` +
            '<div class="pick-top"><span class="pick-gem"></span>' +
            (it.featured ? '<span class="pick-tag gold">Featured</span>' : '') +
            (it.count > 1 ? `<span class="pick-tag">x${nfmt(it.count)}</span>` : '') + '</div>' +
            `<div class="pick-art">${art}</div>` +
            `<div class="pick-name">${esc(it.label)}</div>` +
            '<div class="pick-foot">' +
            `<span class="pick-price"><i class="fa-solid fa-coins"></i>${nfmt(it.price)}</span>` +
            `<span class="pick-kind"><span class="pick-rar">${esc(it.rarity || '')}</span>` +
            '<span class="pick-tick"></span></span></div></div>';
    }).join('');

    document.querySelectorAll('#cs-grid .pick').forEach((card) => {
        card.addEventListener('click', async () => {
            if (store.busy) return;
            store.busy = true;
            card.classList.add('buying');
            const resp = await post('storeBuy', { id: card.dataset.id });
            store.busy = false;
            card.classList.remove('buying');
            if (resp && typeof resp.credits === 'number') setCredits(resp.credits);
            card.classList.add(resp && resp.ok ? 'bought' : 'failed');
            setTimeout(() => {
                card.classList.remove('bought', 'failed');
                renderStore();
            }, 900);
        });
    });
}

async function loadStore() {
    const res = await post('storeGet');
    store.items = (res && res.items) || [];
    setCredits(res && res.credits);
    renderStore();
}

function loadPage(id) {
    if (id === 'career') loadCareer();
    else if (id === 'store') loadStore();
    else if (id === 'loadout') loadLoadout();
}

/* ── Loadout ────────────────────────────────────────────────────────────── */
const ROLE_LABEL = { primary: 'Primary', secondary: 'Secondary', equipment: 'Equipment' };

function ownedSet(list) {
    const map = {};
    (list || []).forEach((id) => { map[id] = true; });
    return map;
}

function applyLoadoutData(res) {
    loadout.items = (res && res.items) || [];
    loadout.owned = ownedSet(res && res.owned);
    loadout.equipped = (res && res.equipped) || {};
    if (typeof (res && res.credits) === 'number') setCredits(res.credits);
}

function renderLoadoutPage() {
    const kit = document.getElementById('lo-kit');
    const grid = document.getElementById('lo-grid');
    const empty = document.getElementById('lo-empty');
    const cats = [];
    loadout.items.forEach((i) => { if (!cats.includes(i.category)) cats.push(i.category); });

    kit.innerHTML = ['primary', 'secondary', 'equipment'].map((role) => {
        const id = loadout.equipped[role];
        const it = loadout.items.find((x) => x.id === id);
        const art = it && it.image
            ? `<img src="${esc(it.image)}" onerror="this.replaceWith(Object.assign(document.createElement('i'),{className:'fa-solid fa-gun'}))">`
            : '<i class="fa-solid fa-gun"></i>';
        return `<div class="lo-slot">` +
            `<div class="lo-slot-role">${esc(ROLE_LABEL[role] || role)}</div>` +
            `<div class="lo-slot-art">${art}</div>` +
            `<div class="lo-slot-name">${esc((it && it.label) || 'None')}</div>` +
            `<div class="lo-slot-kind">${esc((it && it.kind) || '')}</div></div>`;
    }).join('');

    if (!loadout.items.length) {
        document.getElementById('lo-cats').innerHTML = '';
        grid.innerHTML = '';
        empty.classList.remove('hidden');
        return;
    }
    empty.classList.add('hidden');
    if (!loadout.category || !cats.includes(loadout.category)) loadout.category = cats[0];

    document.getElementById('lo-cats').innerHTML = cats.map((c) =>
        `<div class="pg${c === loadout.category ? ' active' : ''}" data-c="${esc(c)}">${esc(c)}</div>`).join('');
    document.querySelectorAll('#lo-cats .pg').forEach((p) => {
        p.addEventListener('click', () => { loadout.category = p.dataset.c; renderLoadoutPage(); });
    });

    const rows = loadout.items.filter((i) => i.category === loadout.category);
    if (!rows.length) {
        grid.innerHTML = '';
        empty.classList.remove('hidden');
        return;
    }

    grid.innerHTML = rows.map((it, i) => {
        const tier = RARITY_RGB[it.rarity] || RARITY_RGB.neutral;
        const owned = !!loadout.owned[it.id] || it.starter || it.price <= 0;
        const equipped = loadout.equipped[it.role] === it.id;
        const affordable = loadout.credits >= it.price;
        const art = it.image
            ? `<img src="${esc(it.image)}" onerror="this.replaceWith(Object.assign(document.createElement('i'),{className:'fa-solid fa-gun'}))">`
            : '<i class="fa-solid fa-gun"></i>';
        const foot = equipped
            ? '<span class="pick-price">Equipped</span>'
            : (owned
                ? '<span class="pick-price">Equip</span>'
                : `<span class="pick-price"><i class="fa-solid fa-coins"></i>${nfmt(it.price)}</span>`);
        return `<div class="pick shop${owned ? '' : (affordable ? '' : ' broke')}${equipped ? ' equipped' : ''}" data-id="${esc(it.id)}" ` +
            `style="--tier:${tier};animation-delay:${i * 0.03}s">` +
            '<div class="pick-top"><span class="pick-gem"></span>' +
            (equipped ? '<span class="pick-tag gold">Equipped</span>' : (owned ? '<span class="pick-tag">Owned</span>' : '')) +
            '</div>' +
            `<div class="pick-art">${art}</div>` +
            `<div class="pick-name">${esc(it.label)}</div>` +
            '<div class="pick-foot">' + foot +
            `<span class="pick-kind"><span class="pick-rar">${esc(it.rarity || '')}</span>` +
            '<span class="pick-tick"></span></span></div></div>';
    }).join('');

    document.querySelectorAll('#lo-grid .pick').forEach((card) => {
        card.addEventListener('click', async () => {
            if (loadout.busy) return;
            const id = card.dataset.id;
            const it = loadout.items.find((x) => x.id === id);
            if (!it) return;
            const owned = !!loadout.owned[it.id] || it.starter || it.price <= 0;
            if (owned && loadout.equipped[it.role] === it.id) return;
            loadout.busy = true;
            card.classList.add('buying');
            const resp = owned
                ? await post('loadoutEquip', { id })
                : await post('loadoutBuy', { id });
            loadout.busy = false;
            card.classList.remove('buying');
            if (resp && resp.ok) {
                applyLoadoutData(resp);
                renderLoadoutPage();
            } else {
                if (resp && typeof resp.credits === 'number') setCredits(resp.credits);
                card.classList.add('failed');
                setTimeout(() => card.classList.remove('failed'), 900);
            }
        });
    });
}

async function loadLoadout() {
    const res = await post('loadoutGet');
    applyLoadoutData(res);
    renderLoadoutPage();
}

function renderSquad(data) {
    const root = document.getElementById('squad');
    const list = document.getElementById('sq-list');
    const members = (data && data.members) || [];
    if (!members.length) {
        root.classList.add('hidden');
        return;
    }
    list.innerHTML = members.map((m) => {
        const ini = esc((m.name || '?').trim().charAt(0).toUpperCase() || '?');
        const img = m.avatar
            ? `<img src="${esc(m.avatar)}" alt="" onerror="this.remove()">`
            : '';
        const hp = Math.max(0, Math.min(100, Math.round((((m.health || 0) - 100) / 100) * 100)));
        const armor = Math.max(0, Math.min(100, Math.round((m.armor || 0))));
        return `<div class="sq-p${m.you ? ' you' : ''}${m.talking ? ' talking' : ''}${m.alive === false ? ' down' : ''}">` +
            `<div class="sq-pfp"><span class="ini">${ini}</span>${img}` +
            (m.talking ? '<span class="sq-mic"><i class="fa-solid fa-microphone"></i></span>' : '') +
            '</div>' +
            `<div class="sq-meta"><span class="sq-name">${esc(m.name || 'Unknown')}</span>` +
            `<div class="sq-bars"><div class="sq-hp" style="width:${m.alive === false ? 0 : hp}%"></div>` +
            `<div class="sq-ar" style="width:${m.alive === false ? 0 : armor}%"></div></div></div></div>`;
    }).join('');
    root.classList.remove('hidden');
}

/* ── Ready check ─────────────────────────────────────────────────────────
   Both rosters, avatars go green as people accept. The server owns the state
   and re-pushes it every second, so this only renders what it is told. */
const rdyEl = document.getElementById('ready');
const rdyMine = document.getElementById('rdy-mine');
const rdyTheirs = document.getElementById('rdy-theirs');
const rdyAccept = document.getElementById('rdy-accept');
const rdyDecline = document.getElementById('rdy-decline');
const rdyFill = document.getElementById('rdy-fill');
const rdyMode = document.getElementById('rdy-mode');

let rdyBusy = false;
let rdyAccepted = false;

function rdyCard(p) {
    const ini = esc((p.name || '?').trim().charAt(0).toUpperCase() || '?');
    const img = p.avatar ? '<img src="' + esc(p.avatar) + '" alt="" onerror="this.remove()">' : '';
    return '<div class="rdy-p' + (p.ready ? ' ready' : '') + '">'
        + '<div class="rdy-pfp"><span class="ini">' + ini + '</span>' + img
        + '<span class="rdy-tick"><i class="fa-solid fa-check"></i></span></div>'
        + '<span class="rdy-name">' + esc(p.name) + '</span>'
        + '<span class="rdy-state">' + (p.ready ? 'Ready' : 'Waiting') + '</span>'
        + '</div>';
}

function showReady(d) {
    if (!d) return;
    const mine = d.mine || [];
    const theirs = d.theirs || [];

    rdyMine.innerHTML = mine.map(rdyCard).join('');
    rdyTheirs.innerHTML = theirs.map(rdyCard).join('');
    rdyMode.textContent = (d.size || mine.length) + 'v' + (d.size || theirs.length);

    const secs = Math.max(0, Number(d.seconds) || 0);
    const total = Math.max(1, Number(d.total) || 25);
    rdyFill.style.width = Math.max(0, Math.min(100, (secs / total) * 100)) + '%';
    rdyFill.classList.toggle('low', secs <= 5);

    // The label is rebuilt on accept, so the timer span may be gone.
    const t = document.getElementById('rdy-timer');
    if (t) t.textContent = secs;

    rdyEl.classList.remove('hidden');
}

function hideReady() {
    rdyEl.classList.add('hidden');
    rdyMine.innerHTML = '';
    rdyTheirs.innerHTML = '';
    rdyBusy = false;
    rdyAccepted = false;
    rdyAccept.disabled = false;
    rdyAccept.innerHTML = 'Accept <span id="rdy-timer">25</span>';
}

rdyAccept.addEventListener('click', async () => {
    if (rdyBusy || rdyAccepted) return;
    rdyBusy = true;
    rdyAccepted = true;
    rdyAccept.disabled = true;
    rdyAccept.textContent = 'Waiting for others...';
    await post('ready', { accept: true });
    rdyBusy = false;
});

rdyDecline.addEventListener('click', async () => {
    if (rdyBusy) return;
    rdyBusy = true;
    await post('ready', { accept: false });
    rdyBusy = false;
    hideReady();
});

/* Ask the client for the theme + page config as soon as the NUI is alive, so
   nothing ever renders with the wrong colours. */
buildLbColumns();
post('uiReady');
