const form = document.getElementById("shorten-form");
const errorEl = document.getElementById("error");
const resultEl = document.getElementById("result");
const shortUrlEl = document.getElementById("short-url");
const copyBtn = document.getElementById("copy");
const recentBody = document.getElementById("recent-body");

function showError(message) {
  errorEl.textContent = message;
  errorEl.hidden = false;
}

function cell(content, className) {
  const td = document.createElement("td");
  if (className) td.className = className;
  if (content instanceof Node) td.appendChild(content);
  else td.textContent = content;
  return td;
}

async function loadRecent() {
  const res = await fetch("/api/links?limit=10");
  if (!res.ok) return;
  const links = await res.json();
  recentBody.replaceChildren();
  if (links.length === 0) {
    const tr = document.createElement("tr");
    const td = cell("Nothing yet.", "muted");
    td.colSpan = 3;
    tr.appendChild(td);
    recentBody.appendChild(tr);
    return;
  }
  for (const link of links) {
    const a = document.createElement("a");
    a.href = link.short_url;
    a.textContent = "/" + link.code;
    a.target = "_blank";
    a.rel = "noopener";
    const tr = document.createElement("tr");
    const dest = cell(link.target_url, "dest");
    dest.title = link.target_url;
    tr.append(cell(a), dest, cell(String(link.clicks), "num"));
    recentBody.appendChild(tr);
  }
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  errorEl.hidden = true;
  const body = { url: form.url.value.trim() };
  const custom = form.custom_code.value.trim();
  if (custom) body.custom_code = custom;

  const res = await fetch("/api/links", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const detail = Array.isArray(data.detail) ? data.detail[0]?.msg : data.detail;
    showError(detail || `Request failed (${res.status})`);
    return;
  }
  shortUrlEl.href = data.short_url;
  shortUrlEl.textContent = data.short_url;
  resultEl.hidden = false;
  copyBtn.textContent = "Copy";
  form.reset();
  loadRecent();
});

copyBtn.addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText(shortUrlEl.href);
    copyBtn.textContent = "Copied!";
  } catch {
    copyBtn.textContent = "Copy failed";
  }
});

loadRecent();
