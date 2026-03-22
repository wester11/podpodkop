async function loadCatalog() {
  const res = await fetch("./catalog.json", { cache: "no-store" });
  if (!res.ok) throw new Error("catalog.json not found");
  return res.json();
}

function addCheckboxes(container, names, kind) {
  container.innerHTML = "";
  names.forEach((name) => {
    const label = document.createElement("label");
    label.className = "item";
    const cb = document.createElement("input");
    cb.type = "checkbox";
    cb.dataset.kind = kind;
    cb.value = name;
    label.appendChild(cb);
    label.append(" " + name);
    container.appendChild(label);
  });
}

function toBase64Url(input) {
  const utf8 = new TextEncoder().encode(input);
  let bin = "";
  utf8.forEach((b) => { bin += String.fromCharCode(b); });
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function buildToken() {
  const listValues = [...document.querySelectorAll("input[data-kind='list']:checked")].map((x) => x.value);
  const serviceValues = [...document.querySelectorAll("input[data-kind='service']:checked")].map((x) => x.value);
  const payload = `L=${listValues.join(",")};S=${serviceValues.join(",")}`;
  return "PK1_" + toBase64Url(payload);
}

async function main() {
  const listsBox = document.getElementById("listsBox");
  const servicesBox = document.getElementById("servicesBox");
  const tokenEl = document.getElementById("token");
  const genBtn = document.getElementById("gen");
  const copyBtn = document.getElementById("copy");

  const catalog = await loadCatalog();
  addCheckboxes(listsBox, catalog.lists || [], "list");
  addCheckboxes(servicesBox, catalog.services || [], "service");

  genBtn.addEventListener("click", () => {
    tokenEl.value = buildToken();
  });

  copyBtn.addEventListener("click", async () => {
    if (!tokenEl.value) tokenEl.value = buildToken();
    await navigator.clipboard.writeText(tokenEl.value);
  });
}

main().catch((e) => {
  console.error(e);
  alert("Не удалось загрузить catalog.json");
});
