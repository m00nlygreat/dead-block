document.addEventListener("DOMContentLoaded", () => {
  const $ = (s) => document.querySelector(s);
  const $$ = (s) => document.querySelectorAll(s);

  // ── State ──
  let resources = [];
  let dirHandle = null;
  let sortCol = null;
  let sortAsc = true;
  let edits = new Map();

  const DISPLAY_ORDER = [
    "id", "display_name", "item_type", "rarity", "weight", "max_stack", "description",
    "damage", "reach", "arc_deg", "max_targets", "durability", "attack_cooldown",
    "knockback", "stagger_time", "is_ranged", "headshot_chance", "projectile_speed",
    "hunger_restore", "thirst_restore", "heal_amount", "consume_time",
    "max_level", "cost", "effect_id", "values",
    "entries", "roll_count_min", "roll_count_max",
  ];

  const TYPE_MAP = {
    "0": "WEAPON", "1": "FOOD", "2": "MEDICAL", "3": "MATERIAL", "4": "KEY", "5": "VALUABLE",
    "WEAPON": "WEAPON", "FOOD": "FOOD", "MEDICAL": "MEDICAL", "MATERIAL": "MATERIAL",
    "KEY": "KEY", "VALUABLE": "VALUABLE",
  };

  const RARITY_MAP = {
    "0": "COMMON", "1": "UNCOMMON", "2": "RARE", "3": "EPIC", "4": "LEGENDARY",
    "COMMON": "COMMON", "UNCOMMON": "UNCOMMON", "RARE": "RARE", "EPIC": "EPIC", "LEGENDARY": "LEGENDARY",
  };

  const COLOR_CLASS = { WEAPON: "type-weapon", FOOD: "type-food", MEDICAL: "type-medical",
    MATERIAL: "type-material", KEY: "type-key", VALUABLE: "type-valuable" };

  // ── Init ──
  initDragDrop();
  applyURLParams();

  // ── Drag & Drop ──
  function initDragDrop() {
    const dz = $("#drop-zone");
    dz.addEventListener("dragover", (e) => { e.preventDefault(); dz.classList.add("dragover"); });
    dz.addEventListener("dragleave", () => dz.classList.remove("dragover"));
    dz.addEventListener("drop", async (e) => {
      e.preventDefault();
      dz.classList.remove("dragover");
      const items = e.dataTransfer.items;
      if (!items) return;
      const files = [];
      for (const item of items) {
        if (item.getAsFileSystemHandle) {
          const handle = await item.getAsFileSystemHandle();
          if (handle.kind === "directory") {
            if (!dirHandle) dirHandle = handle;
            await scanDirHandle(handle, files);
          } else if (handle.kind === "file") {
            const f = await handle.getFile();
            if (f.name.endsWith(".tres")) files.push({ path: f.name, text: await f.text() });
          }
        } else if (item.webkitGetAsEntry) {
          const entry = item.webkitGetAsEntry();
          if (entry) await scanWebkitEntry(entry, "", files);
        } else {
          const f = item.getAsFile();
          if (f && f.name.endsWith(".tres")) files.push({ path: f.name, text: await f.text() });
        }
      }
      loadFiles(files);
    });
  }

  async function scanDirHandle(handle, files) {
    for await (const [name, child] of handle) {
      if (child.kind === "directory") await scanDirHandle(child, files);
      else if (name.endsWith(".tres")) {
        const f = await child.getFile();
        files.push({ path: name, text: await f.text() });
      }
    }
  }

  function scanWebkitEntry(entry, prefix, files) {
    return new Promise((resolve) => {
      if (entry.isFile) {
        entry.file((f) => {
          if (f.name.endsWith(".tres")) {
            const reader = new FileReader();
            reader.onload = () => { files.push({ path: prefix + f.name, text: reader.result }); resolve(); };
            reader.readAsText(f);
          } else { resolve(); }
        });
      } else if (entry.isDirectory) {
        const reader = entry.createReader();
        const all = [];
        const readBatch = () => reader.readEntries(async (batch) => {
          if (batch.length === 0) {
            for (const child of all) await scanWebkitEntry(child, prefix + entry.name + "/", files);
            resolve();
          } else {
            all.push(...batch);
            readBatch();
          }
        });
        readBatch();
      } else { resolve(); }
    });
  }

  // ── Folder Picker (Chromium) ──
  window.openFolder = async function () {
    if (!("showDirectoryPicker" in window)) {
      alert("이 브라우저는 폴더 열기를 지원하지 않습니다.\nChrome/Edge를 사용하거나 파일을 드래그하세요.");
      return;
    }
    try {
      dirHandle = await window.showDirectoryPicker({ mode: "readwrite" });
      const files = [];
      await scanDirHandle(dirHandle, files);
      loadFiles(files);
    } catch (e) {
      if (e.name !== "AbortError") console.error(e);
    }
  };

  // ── Load Files ──
  function loadFiles(files) {
    resources = [];
    edits.clear();
    for (const file of files) {
      try {
        const parsed = TresParser.parse(file.text);
        resources.push({
          path: file.path, parsed, props: parsed.properties,
          _class: parsed.header?.script_class || "",
        });
      } catch (e) {
        console.warn("파싱 실패:", file.path, e);
      }
    }
    buildTypeFilter();
    renderTable();
    updateStatus();
  }

  // ── Table Rendering ──
  function getAllKeys() {
    const keySet = new Set();
    for (const r of resources) Object.keys(r.props).forEach((k) => { if (!k.endsWith("__raw")) keySet.add(k); });
    const ordered = DISPLAY_ORDER.filter((k) => keySet.has(k));
    for (const k of keySet) if (!ordered.includes(k)) ordered.push(k);
    return ordered;
  }

  function renderTable() {
    const keys = getAllKeys();
    const filtered = getFilteredSorted();

    const thead = $("#thead");
    const tbody = $("#tbody");
    thead.innerHTML = "";
    tbody.innerHTML = "";

    const hr = document.createElement("tr");
    hr.innerHTML = `<th class="row-num">#</th><th class="col-path">파일</th><th class="col-class">클래스</th>`;
    for (const k of keys) {
      const th = document.createElement("th");
      th.className = "col-key";
      th.dataset.key = k;
      const label = k.replace(/_/g, " ");
      th.innerHTML = `${label} <span class="sort-arrow"></span>`;
      th.onclick = () => toggleSort(k);
      if (k === sortCol) th.classList.add("sort-active");
      hr.appendChild(th);
    }
    thead.appendChild(hr);

    let idx = 0;
    for (const r of filtered) {
      const tr = document.createElement("tr");
      if (edits.has(r.path)) tr.classList.add("modified");
      const typeId = String(r.props.item_type ?? "");
      const typeLabel = TYPE_MAP[typeId] || typeId;
      tr.innerHTML = `<td class="row-num">${++idx}</td>
        <td class="col-path" title="${r.path}">${r.path}</td>
        <td class="col-class"><span class="class-badge">${r._class}</span></td>`;
      for (const k of keys) {
        const td = document.createElement("td");
        td.className = "col-val";
        const v = r.props[k];
        td.innerHTML = renderCell(r, k, v);
        if (k === "item_type" && v !== undefined) {
          const inner = td.querySelector(".val-inner");
          if (inner) inner.classList.add("type-badge", COLOR_CLASS[typeLabel] || "");
        }
        if (k === "rarity" && v !== undefined) {
          const inner = td.querySelector(".val-inner");
          const rl = RARITY_MAP[String(v)] || String(v);
          if (inner) inner.classList.add("rarity-badge", "rarity-" + rl.toLowerCase());
        }
        if (isEditable(k, r)) {
          td.classList.add("editable");
          td.onclick = () => startEdit(td, r, k);
        }
        tr.appendChild(td);
      }
      tbody.appendChild(tr);
    }

    $$(".sort-arrow").forEach((a) => a.textContent = "");
    if (sortCol) {
      const th = thead.querySelector(`[data-key="${sortCol}"]`);
      if (th) th.querySelector(".sort-arrow").textContent = sortAsc ? " ▲" : " ▼";
    }
  }

  function renderCell(res, key, value) {
    if (value === undefined || value === null) return '<span class="val-null">\u2014</span>';
    if (typeof value === "object" && value._t === "ExtResource") return `<span class="val-ref">Ext("${value.id}")</span>`;
    if (typeof value === "object" && value._t === "SubResource") return `<span class="val-ref">Sub("${value.id}")</span>`;
    if (typeof value === "object" && value._t === "constructor") return `<span class="val-ctor">${escHtml(value.raw)}</span>`;
    if (typeof value === "object" && value._t === "typed_array") {
      return `<span class="val-arr">${value.items.map(formatShort).join(", ")}</span>`;
    }
    if (typeof value === "object" && value._t === "array") {
      return `<span class="val-arr">[${value.items.map(formatShort).join(", ")}]</span>`;
    }
    if (typeof value === "object" && value._t === "dict") {
      const entries = Object.entries(value.entries || {});
      return `<span class="val-dict">{${entries.length} keys}</span>`;
    }
    if (Array.isArray(value)) return `<span class="val-arr">[${value.map(formatShort).join(", ")}]</span>`;
    if (typeof value === "object") return `<span class="val-dict">{${Object.keys(value).length} keys}</span>`;
    return `<span class="val-inner">${escHtml(formatShort(value))}</span>`;
  }

  function formatShort(v) {
    if (typeof v === "string") return `"${v.length > 30 ? v.slice(0, 27) + "…" : v}"`;
    if (typeof v === "object" && v._t) return v.id || v.raw || "?";
    return String(v);
  }

  function escHtml(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function isEditable(key, res) {
    if (key === "script") return false;
    const v = res.props[key];
    if (typeof v === "object" && v && (v._t === "ExtResource" || v._t === "SubResource")) return false;
    return true;
  }

  // ── Inline Editing ──
  function startEdit(td, res, key) {
    if (td.querySelector(".edit-input")) return;
    const v = res.props[key];
    let raw = "";
    if (v === null || v === undefined) raw = "";
    else if (typeof v === "object" && v._t === "typed_array") raw = `Array[${v.type}](${JSON.stringify(v.items)})`;
    else if (typeof v === "object" && v._t === "array") raw = JSON.stringify(v.items);
    else if (typeof v === "object" && v._t === "dict") raw = JSON.stringify(v.entries);
    else if (typeof v === "object" && v._t === "constructor") raw = v.raw;
    else if (Array.isArray(v)) raw = JSON.stringify(v);
    else if (typeof v === "object") raw = JSON.stringify(v);
    else raw = String(v);

    td.classList.add("editing");
    const input = document.createElement("input");
    input.type = "text";
    input.className = "edit-input";
    input.value = raw;
    td.innerHTML = "";
    td.appendChild(input);
    input.focus();
    input.select();

    const commit = () => {
      const newVal = parseInput(input.value, v);
      res.props[key] = newVal;
      if (!edits.has(res.path)) edits.set(res.path, new Set());
      edits.get(res.path).add(key);
      td.classList.remove("editing");
      td.innerHTML = renderCell(res, key, newVal);
      if (key === "item_type") {
        const inner = td.querySelector(".val-inner");
        const typeLabel = TYPE_MAP[String(newVal)] || String(newVal);
        if (inner) inner.classList.add("type-badge", COLOR_CLASS[typeLabel] || "");
      }
      if (key === "rarity") {
        const inner = td.querySelector(".val-inner");
        const rl = RARITY_MAP[String(newVal)] || String(newVal);
        if (inner) inner.classList.add("rarity-badge", "rarity-" + rl.toLowerCase());
      }
      if (isEditable(key, res)) {
        td.classList.add("editable");
        td.onclick = () => startEdit(td, res, key);
      }
      updateStatus();
    };

    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") commit();
      if (e.key === "Escape") {
        td.classList.remove("editing");
        td.innerHTML = renderCell(res, key, v);
        if (isEditable(key, res)) { td.classList.add("editable"); td.onclick = () => startEdit(td, res, key); }
      }
    });
    input.addEventListener("blur", commit);
  }

  function parseInput(raw, original) {
    raw = raw.trim();
    if (raw === "") return null;
    if (raw === "null") return null;
    if (raw === "true") return true;
    if (raw === "false") return false;
    if (/^-?\d+$/.test(raw)) return parseInt(raw, 10);
    if (/^-?\d+\.\d+$/.test(raw)) return parseFloat(raw);
    if (/^(Color|Vector2|Vector3|Vector2i|Vector3i|Transform2D|Transform3D|Rect2)\(/.test(raw)) {
      return { _t: "constructor", raw };
    }
    if (raw.startsWith("Array[")) {
      const m = raw.match(/^Array\[(\w+)\]\((.*)\)$/);
      if (m) {
        try {
          const items = JSON.parse("[" + m[2] + "]");
          return { _t: "typed_array", type: m[1], items };
        } catch {}
      }
    }
    if (raw.startsWith("[")) {
      try {
        const items = JSON.parse(raw);
        if (original && original._t === "array") return { _t: "array", items };
        return items;
      } catch {}
    }
    if (raw.startsWith("{")) {
      try {
        const entries = JSON.parse(raw);
        if (original && original._t === "dict") return { _t: "dict", entries };
        return entries;
      } catch {}
    }
    return raw;
  }

  // ── Sort ──
  function toggleSort(key) {
    if (sortCol === key) { sortAsc = !sortAsc; }
    else { sortCol = key; sortAsc = true; }
    renderTable();
  }

  function sortCompare(a, b, key) {
    const va = a.props[key], vb = b.props[key];
    if (va === undefined && vb === undefined) return 0;
    if (va === undefined) return 1;
    if (vb === undefined) return -1;
    if (typeof va === "number" && typeof vb === "number") return va - vb;
    return String(va).localeCompare(String(vb), "ko");
  }

  // ── Filter ──
  function getFilteredSorted() {
    let list = [...resources];
    const search = ($("#search")?.value || "").toLowerCase().trim();
    const typeFilter = $("#filter-type")?.value || "";
    const classFilter = $("#filter-class")?.value || "";

    if (search) {
      list = list.filter((r) => {
        for (const [k, v] of Object.entries(r.props)) {
          if (k.endsWith("__raw")) continue;
          if (v !== null && v !== undefined && String(v).toLowerCase().includes(search)) return true;
        }
        return r.path.toLowerCase().includes(search);
      });
    }
    if (typeFilter) {
      list = list.filter((r) => {
        const t = String(r.props.item_type ?? "");
        return TYPE_MAP[t] === typeFilter || t === typeFilter;
      });
    }
    if (classFilter) {
      list = list.filter((r) => r._class === classFilter);
    }
    if (sortCol) list.sort((a, b) => sortCompare(a, b, sortCol) * (sortAsc ? 1 : -1));
    return list;
  }

  function buildTypeFilter() {
    const types = new Set();
    const classes = new Set();
    for (const r of resources) {
      if (r.props.item_type !== undefined) {
        const t = TYPE_MAP[String(r.props.item_type)] || String(r.props.item_type);
        types.add(t);
      }
      if (r._class) classes.add(r._class);
    }
    const sel = $("#filter-type");
    sel.innerHTML = '<option value="">전체 타입</option>';
    for (const t of [...types].sort()) {
      sel.innerHTML += `<option value="${t}">${t}</option>`;
    }
    const cls = $("#filter-class");
    cls.innerHTML = '<option value="">전체 클래스</option>';
    for (const c of [...classes].sort()) {
      cls.innerHTML += `<option value="${c}">${c}</option>`;
    }
  }

  // ── Save ──
  window.saveAll = async function () {
    if (edits.size === 0) { alert("수정된 파일이 없습니다."); return; }
    const useFSA = "showSaveFilePicker" in window && dirHandle;

    for (const [path, changedKeys] of edits) {
      const res = resources.find((r) => r.path === path);
      if (!res) continue;
      const output = TresParser.serialize(res.parsed, edits.get(res.path) || new Set());

      if (useFSA && dirHandle) {
        try {
          const fh = await dirHandle.getFileHandle(path, { create: true });
          const writable = await fh.createWritable();
          await writable.write(output);
          await writable.close();
        } catch (e) {
          console.warn("FSA 저장 실패, 다운로드로 전환:", path, e);
          downloadFile(path, output);
        }
      } else {
        downloadFile(path, output);
      }
    }
    edits.clear();
    renderTable();
    updateStatus();
  };

  function downloadFile(path, content) {
    const blob = new Blob([content], { type: "text/plain;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = path.split("/").pop();
    a.click();
    URL.revokeObjectURL(url);
  }

  // ── Status Bar ──
  function updateStatus() {
    const total = resources.length;
    const modified = edits.size;
    const classes = new Set(resources.map((r) => r._class).filter(Boolean));
    let html = `<span>${total} 파일</span>`;
    if (classes.size) html += `<span class="sep">|</span><span>${[...classes].join(", ")}</span>`;
    if (modified) html += `<span class="sep">|</span><span class="modified-count">${modified} 수정됨</span>`;
    if (!dirHandle && "showDirectoryPicker" in window) html += `<span class="sep">|</span><span class="hint">💡 "폴더 열기"로 저장 지원</span>`;
    $("#status").innerHTML = html;
  }

  // ── URL Params ──
  function applyURLParams() {
    const p = new URLSearchParams(window.location.search);
    if (p.get("search")) setTimeout(() => { const s = $("#search"); if (s) s.value = p.get("search"); }, 0);
    if (p.get("type")) setTimeout(() => { const s = $("#filter-type"); if (s) s.value = p.get("type"); }, 0);
    if (p.get("sort")) { sortCol = p.get("sort"); sortAsc = p.get("dir") !== "desc"; }
  }

  window.updateURL = function () {
    const p = new URLSearchParams();
    const s = $("#search")?.value; if (s) p.set("search", s);
    const t = $("#filter-type")?.value; if (t) p.set("type", t);
    if (sortCol) { p.set("sort", sortCol); p.set("dir", sortAsc ? "asc" : "desc"); }
    const qs = p.toString();
    history.replaceState(null, "", qs ? "?" + qs : window.location.pathname);
  };
});
