async function loadCatalog() {
  const res = await fetch("./catalog.json", { cache: "no-store" });
  if (!res.ok) {
    throw new Error("catalog.json not found");
  }
  return res.json();
}

function toBase64Url(input) {
  const utf8 = new TextEncoder().encode(input);
  let bin = "";
  utf8.forEach((byte) => {
    bin += String.fromCharCode(byte);
  });
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function debounce(fn, waitMs) {
  let timer = null;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), waitMs);
  };
}

const LIST_LABELS = {
  ai_all: "AI-инструменты",
  all_services: "Все сервисы",
  cloud_storage: "Облачные хранилища",
  creator_platforms: "Платформы авторов",
  developer_platforms: "Разработка",
  education: "Образование",
  finance_payment: "Финансы и платежи",
  forums_communities: "Форумы и сообщества",
  gaming: "Игры",
  messengers_calls: "Мессенджеры",
  music_streaming: "Музыка",
  news_media: "Новости и медиа",
  productivity_tools: "Продуктивность",
  social_messaging: "Соц. мессенджеры",
  social_networks: "Социальные сети",
  video_audio_streaming: "Видео и стриминг",
  vpn_privacy: "VPN и приватность",
  work_tools: "Рабочие инструменты",
};

const LIST_DESC = {
  ai_all: "ChatGPT, Claude, Gemini, Grok, Copilot",
  all_services: "Полный агрегированный список всех сервисов",
  cloud_storage: "Dropbox, OneDrive, Mega",
  creator_platforms: "Patreon, Behance, Envato, DeviantArt",
  developer_platforms: "GitHub, GitLab, Docker, npm, Cloudflare",
  education: "Coursera, Udemy, Duolingo, Khan Academy",
  finance_payment: "PayPal, Stripe, Wise, Revolut",
  forums_communities: "Reddit, Medium, Quora, Stack Overflow",
  gaming: "Steam, Epic, Battle.net, Riot, EA, Xbox, PlayStation",
  messengers_calls: "Telegram, Discord, Signal, Slack, Zoom",
  music_streaming: "Spotify, Deezer, Tidal, Apple Music",
  news_media: "BBC, CNN, Reuters, Meduza, Радио Свобода",
  productivity_tools: "Notion, Figma, Miro, Canva, Trello",
  social_messaging: "WhatsApp, Viber, Telegram, Snapchat",
  social_networks: "Instagram, Facebook, X, TikTok, Tumblr",
  video_audio_streaming: "YouTube, Twitch, Vimeo, Kick, Rumble",
  vpn_privacy: "Mullvad, NordVPN, ExpressVPN, ProtonVPN",
  work_tools: "Slack, Zoom, Skype, Notion, Figma, Miro",
};

const CATEGORY_LABELS = {
  social: "Соц. сети",
  msg: "Мессенджеры",
  video: "Видео",
  music: "Музыка",
  gaming: "Игры",
  ai: "AI",
  dev: "Разработка",
  cloud: "Облако",
  work: "Работа",
  edu: "Образование",
  finance: "Финансы",
  news: "Новости",
  creator: "Для авторов",
  vpn: "VPN",
  other: "Прочее",
};

const CATEGORY_ORDER = [
  "social",
  "msg",
  "video",
  "music",
  "gaming",
  "ai",
  "dev",
  "cloud",
  "work",
  "edu",
  "finance",
  "news",
  "creator",
  "vpn",
  "other",
];

const state = {
  lists: [],
  services: [],
  categories: [],
  openCategories: new Set(),
  selectedLists: new Set(),
  selectedServices: new Set(),
  listFilter: "",
  serviceFilter: "",
};

const refs = {};

function normalize(value) {
  return String(value || "").toLowerCase();
}

function buildToken() {
  const listVals = state.lists.filter((name) => state.selectedLists.has(name));
  const serviceVals = state.services.filter((name) => state.selectedServices.has(name));
  const payload = `L=${listVals.join(",")};S=${serviceVals.join(",")}`;
  return "PK1_" + toBase64Url(payload);
}

function createCheckbox(kind, value, checked) {
  const input = document.createElement("input");
  input.type = "checkbox";
  input.dataset.kind = kind;
  input.value = value;
  input.checked = checked;
  return input;
}

function renderLists() {
  const q = normalize(state.listFilter.trim());
  const frag = document.createDocumentFragment();
  let shown = 0;

  state.lists.forEach((name) => {
    const labelText = LIST_LABELS[name] || name;
    const descText = LIST_DESC[name] || "";
    if (
      q &&
      !normalize(name).includes(q) &&
      !normalize(labelText).includes(q) &&
      !normalize(descText).includes(q)
    ) {
      return;
    }

    shown += 1;
    const row = document.createElement("label");
    row.className = "list-item";

    const checkbox = createCheckbox("list", name, state.selectedLists.has(name));
    const textWrap = document.createElement("div");
    const nameEl = document.createElement("div");
    nameEl.className = "li-name";
    nameEl.textContent = labelText;
    textWrap.appendChild(nameEl);

    if (descText) {
      const descEl = document.createElement("div");
      descEl.className = "li-desc";
      descEl.textContent = descText;
      textWrap.appendChild(descEl);
    }

    row.appendChild(checkbox);
    row.appendChild(textWrap);
    frag.appendChild(row);
  });

  refs.listsBox.replaceChildren(frag);
  if (!shown) {
    refs.listsBox.innerHTML = '<div class="no-match">Ничего не найдено</div>';
  }
}

function renderServices() {
  const q = normalize(state.serviceFilter.trim());
  const frag = document.createDocumentFragment();
  let shownBlocks = 0;

  state.categories.forEach((cat) => {
    const allMembers = cat.services.filter((svc) => state.services.includes(svc));
    if (!allMembers.length) {
      return;
    }

    const visibleMembers = q
      ? allMembers.filter((svc) => normalize(svc).includes(q))
      : allMembers;

    if (!visibleMembers.length) {
      return;
    }

    shownBlocks += 1;
    const block = document.createElement("div");
    block.className = "cat-block";

    const head = document.createElement("div");
    head.className = "cat-head";
    head.dataset.catId = cat.id;

    const isOpen = q.length > 0 || state.openCategories.has(cat.id);
    if (isOpen) {
      head.classList.add("open");
    }

    const arrow = document.createElement("span");
    arrow.className = "arrow";
    arrow.textContent = "▶";

    const label = document.createElement("span");
    label.textContent = cat.label;

    const selectedCount = allMembers.reduce(
      (acc, svc) => acc + (state.selectedServices.has(svc) ? 1 : 0),
      0,
    );
    const sel = document.createElement("span");
    sel.className = "cat-sel";
    sel.id = `cat-sel-${cat.id}`;
    sel.textContent = selectedCount ? `(${selectedCount})` : "";

    const cnt = document.createElement("span");
    cnt.className = "cat-cnt";
    cnt.textContent = String(visibleMembers.length);

    head.appendChild(arrow);
    head.appendChild(label);
    head.appendChild(sel);
    head.appendChild(cnt);

    const body = document.createElement("div");
    body.className = "cat-body";
    body.id = `cat-body-${cat.id}`;
    if (!isOpen) {
      body.classList.add("hidden");
    }

    visibleMembers.forEach((svc) => {
      const item = document.createElement("label");
      item.className = "svc-item";

      const checkbox = createCheckbox("service", svc, state.selectedServices.has(svc));
      const text = document.createElement("span");
      text.className = "svc-label";
      text.textContent = svc;

      item.appendChild(checkbox);
      item.appendChild(text);
      body.appendChild(item);
    });

    block.appendChild(head);
    block.appendChild(body);
    frag.appendChild(block);
  });

  refs.servicesBox.replaceChildren(frag);
  if (!shownBlocks) {
    refs.servicesBox.innerHTML = '<div class="no-match">Ничего не найдено</div>';
  }
}

function renderTags() {
  const total = state.selectedLists.size + state.selectedServices.size;
  refs.selTotal.textContent = String(total);
  refs.listsCnt.textContent = String(state.selectedLists.size);
  refs.svcCnt.textContent = String(state.selectedServices.size);

  if (!total) {
    refs.tagsRow.innerHTML = '<span class="empty-hint">Ничего не выбрано</span>';
    return;
  }

  const frag = document.createDocumentFragment();
  state.lists.forEach((name) => {
    if (!state.selectedLists.has(name)) {
      return;
    }
    const tag = document.createElement("span");
    tag.className = "tag tag-list";
    const txt = document.createElement("span");
    txt.textContent = LIST_LABELS[name] || name;
    const rm = document.createElement("i");
    rm.className = "rm";
    rm.dataset.kind = "list";
    rm.dataset.val = name;
    rm.textContent = "✕";
    tag.appendChild(txt);
    tag.appendChild(rm);
    frag.appendChild(tag);
  });

  state.services.forEach((name) => {
    if (!state.selectedServices.has(name)) {
      return;
    }
    const tag = document.createElement("span");
    tag.className = "tag";
    const txt = document.createElement("span");
    txt.textContent = name;
    const rm = document.createElement("i");
    rm.className = "rm";
    rm.dataset.kind = "service";
    rm.dataset.val = name;
    rm.textContent = "✕";
    tag.appendChild(txt);
    tag.appendChild(rm);
    frag.appendChild(tag);
  });

  refs.tagsRow.replaceChildren(frag);
}

function renderAll() {
  renderLists();
  renderServices();
  renderTags();
}

function toggleSelection(kind, value, checked) {
  const targetSet = kind === "list" ? state.selectedLists : state.selectedServices;
  if (checked) {
    targetSet.add(value);
  } else {
    targetSet.delete(value);
  }
  renderTags();
}

function setAll(kind, checked) {
  if (kind === "list") {
    if (checked) {
      state.lists.forEach((name) => state.selectedLists.add(name));
    } else {
      state.selectedLists.clear();
    }
    renderLists();
    renderTags();
    return;
  }

  if (checked) {
    state.services.forEach((name) => state.selectedServices.add(name));
  } else {
    state.selectedServices.clear();
  }
  renderServices();
  renderTags();
}

function buildCategories(catalog) {
  const byId = new Map();
  const inputCategories = catalog.categories || {};

  Object.entries(inputCategories).forEach(([id, members]) => {
    byId.set(id, {
      id,
      label: CATEGORY_LABELS[id] || id,
      services: Array.isArray(members) ? [...new Set(members)] : [],
    });
  });

  const knownServices = new Set(catalog.services || []);
  const categorized = new Set();
  byId.forEach((cat) => {
    cat.services = cat.services.filter((svc) => knownServices.has(svc));
    cat.services.forEach((svc) => categorized.add(svc));
  });

  const uncategorized = [...knownServices].filter((svc) => !categorized.has(svc)).sort();
  if (!byId.has("other")) {
    byId.set("other", { id: "other", label: CATEGORY_LABELS.other, services: uncategorized });
  } else {
    const other = byId.get("other");
    other.services = [...new Set([...other.services, ...uncategorized])];
  }

  const ordered = [];
  CATEGORY_ORDER.forEach((id) => {
    if (byId.has(id) && byId.get(id).services.length) {
      ordered.push(byId.get(id));
      byId.delete(id);
    }
  });

  [...byId.values()]
    .filter((cat) => cat.services.length)
    .sort((a, b) => a.id.localeCompare(b.id))
    .forEach((cat) => ordered.push(cat));

  return ordered;
}

async function copyToken(token) {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    await navigator.clipboard.writeText(token);
    return;
  }

  refs.token.select();
  const copied = document.execCommand("copy");
  if (!copied) {
    throw new Error("Clipboard API unavailable");
  }
}

function initRefs() {
  refs.listsBox = document.getElementById("listsBox");
  refs.servicesBox = document.getElementById("servicesBox");
  refs.tagsRow = document.getElementById("tagsRow");
  refs.selTotal = document.getElementById("selTotal");
  refs.listsCnt = document.getElementById("listsCnt");
  refs.svcCnt = document.getElementById("svcCnt");
  refs.listsSearch = document.getElementById("listsSearch");
  refs.svcSearch = document.getElementById("svcSearch");
  refs.token = document.getElementById("token");
  refs.copyBtn = document.getElementById("copy");
}

function bindEvents() {
  refs.listsBox.addEventListener("change", (event) => {
    const target = event.target;
    if (!target || target.dataset.kind !== "list") {
      return;
    }
    toggleSelection("list", target.value, target.checked);
  });

  refs.servicesBox.addEventListener("change", (event) => {
    const target = event.target;
    if (!target || target.dataset.kind !== "service") {
      return;
    }
    toggleSelection("service", target.value, target.checked);
  });

  refs.servicesBox.addEventListener("click", (event) => {
    const head = event.target.closest(".cat-head");
    if (!head || state.serviceFilter.trim()) {
      return;
    }
    const catId = head.dataset.catId;
    if (!catId) {
      return;
    }
    if (state.openCategories.has(catId)) {
      state.openCategories.delete(catId);
    } else {
      state.openCategories.add(catId);
    }
    renderServices();
  });

  refs.tagsRow.addEventListener("click", (event) => {
    const target = event.target;
    if (!target.classList.contains("rm")) {
      return;
    }
    const { kind, val } = target.dataset;
    if (!kind || !val) {
      return;
    }
    if (kind === "list") {
      state.selectedLists.delete(val);
      renderLists();
    } else if (kind === "service") {
      state.selectedServices.delete(val);
      renderServices();
    }
    renderTags();
  });

  const onListSearch = debounce((value) => {
    state.listFilter = value;
    renderLists();
  }, 80);
  refs.listsSearch.addEventListener("input", (event) => {
    onListSearch(event.target.value);
  });

  const onServiceSearch = debounce((value) => {
    state.serviceFilter = value;
    renderServices();
  }, 80);
  refs.svcSearch.addEventListener("input", (event) => {
    onServiceSearch(event.target.value);
  });

  document.getElementById("listsSelAll").addEventListener("click", () => setAll("list", true));
  document.getElementById("listsClearBtn").addEventListener("click", () => setAll("list", false));
  document.getElementById("svcSelAll").addEventListener("click", () => setAll("service", true));
  document.getElementById("svcClearBtn").addEventListener("click", () => setAll("service", false));

  document.getElementById("gen").addEventListener("click", () => {
    refs.token.value = buildToken();
  });

  refs.copyBtn.addEventListener("click", async () => {
    if (!refs.token.value) {
      refs.token.value = buildToken();
    }
    try {
      await copyToken(refs.token.value);
      refs.copyBtn.textContent = "✓ Скопировано";
      refs.copyBtn.classList.add("copied");
      setTimeout(() => {
        refs.copyBtn.textContent = "📋 Копировать";
        refs.copyBtn.classList.remove("copied");
      }, 1600);
    } catch (err) {
      alert("Не удалось скопировать ключ. Скопируйте вручную из поля ниже.");
    }
  });

  document.getElementById("resetAll").addEventListener("click", () => {
    state.selectedLists.clear();
    state.selectedServices.clear();
    refs.token.value = "";
    renderAll();
  });
}

async function main() {
  initRefs();
  const catalog = await loadCatalog();

  state.lists = Array.isArray(catalog.lists) ? [...catalog.lists].sort() : [];
  state.services = Array.isArray(catalog.services) ? [...catalog.services].sort() : [];
  state.categories = buildCategories(catalog);

  bindEvents();
  renderAll();
}

main().catch((error) => {
  console.error(error);
  alert("Не удалось загрузить catalog.json: " + error.message);
});
