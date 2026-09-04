/**
 * TRES Parser & Serializer — Godot 4.x text resource format (format=3)
 */
const TresParser = (() => {
  function parse(text) {
    const lines = text.replace(/\r\n/g, "\n").split("\n");
    const result = { header: null, ext_resources: [], sub_resources: [], properties: {}, _rawText: text };
    let i = 0;

    while (i < lines.length) {
      const line = lines[i];

      if (line.startsWith("[gd_resource ")) {
        result.header = parseHeader(line);
        i++;
        while (i < lines.length && lines[i].trim() === "") i++;
      } else if (line.startsWith("[ext_resource ")) {
        const [er, next] = parseExtResource(line, i, lines);
        result.ext_resources.push(er);
        i = next;
      } else if (line.startsWith("[sub_resource ")) {
        const [sr, next] = parseSubResource(line, i, lines);
        result.sub_resources.push(sr);
        i = next;
      } else if (line.trim() === "[resource]") {
        i++;
        result.properties = parseResourceProps(i, lines);
        break;
      } else {
        i++;
      }
    }

    return result;
  }

  function parseHeader(line) {
    const h = {};
    const m = line.match(/\[gd_resource\s+(.*)\]/);
    if (m) {
      for (const part of parseArgs(m[1])) {
        const eq = part.indexOf("=");
        if (eq !== -1) {
          const key = part.slice(0, eq).trim();
          const raw = part.slice(eq + 1).trim();
          h[key] = { value: unquote(raw), raw };
        }
      }
    }
    return h;
  }

  function parseArgs(s) {
    const parts = [];
    let cur = "", depth = 0;
    for (let i = 0; i < s.length; i++) {
      const c = s[i];
      if (c === "(" || c === "[" || c === "{") depth++;
      else if (c === ")" || c === "]" || c === "}") depth--;
      if (c === " " && depth === 0 && cur) {
        parts.push(cur);
        cur = "";
      } else {
        cur += c;
      }
    }
    if (cur) parts.push(cur);
    return parts;
  }

  function parseExtResource(line, idx, lines) {
    const m = line.match(/\[ext_resource\s+(.*)\]/);
    const er = {};
    if (m) {
      for (const part of parseArgs(m[1])) {
        const eq = part.indexOf("=");
        if (eq !== -1) er[part.slice(0, eq).trim()] = unquote(part.slice(eq + 1).trim());
      }
    }
    return [er, idx + 1];
  }

  function parseSubResource(line, idx, lines) {
    const m = line.match(/\[sub_resource\s+(.*)\]/);
    const sr = { _props: {} };
    if (m) {
      for (const part of parseArgs(m[1])) {
        const eq = part.indexOf("=");
        if (eq !== -1) sr[part.slice(0, eq).trim()] = unquote(part.slice(eq + 1).trim());
      }
    }
    let i = idx + 1;
    while (i < lines.length) {
      const l = lines[i].trim();
      if (l === "" || l.startsWith("[")) break;
      const eq = l.indexOf(" = ");
      if (eq !== -1) {
        const k = l.slice(0, eq).trim();
        const rawVal = l.slice(eq + 3);
        const [v, ni] = readValue(rawVal, i, lines);
        if (typeof v === "number" || typeof v === "boolean") {
          sr._props[k + "__raw"] = rawVal;
        }
        sr._props[k] = v;
        i = ni;
      } else {
        i++;
      }
    }
    return [sr, i];
  }

  function parseResourceProps(idx, lines) {
    const props = {};
    let i = idx;
    while (i < lines.length) {
      const l = lines[i].trim();
      if (l === "" || l.startsWith("[")) break;
      const eq = l.indexOf(" = ");
      if (eq !== -1) {
        const k = l.slice(0, eq).trim();
        const rawVal = l.slice(eq + 3);
        const [v, ni] = readValue(rawVal, i, lines);
        if (typeof v === "number" || typeof v === "boolean") {
          props[k + "__raw"] = rawVal;
        }
        props[k] = v;
        i = ni;
      } else {
        i++;
      }
    }
    return props;
  }

  function readValue(s, idx, lines) {
    s = s.trim();
    if (s.startsWith('"')) {
      return readString(s, idx, lines);
    }
    if (s.startsWith("ExtResource(")) return [{ _t: "ExtResource", id: extractRefId(s), _raw: s }, idx + 1];
    if (s.startsWith("SubResource(")) return [{ _t: "SubResource", id: extractRefId(s), _raw: s }, idx + 1];
    if (s.startsWith("Array[")) return readTypedArray(s, idx, lines);
    if (s.startsWith("[") || s.startsWith("{")) return readBracket(s, idx, lines);
    if (/^-?\d+$/.test(s)) return [parseInt(s, 10), idx + 1];
    if (/^-?\d+\.\d*$/.test(s)) return [parseFloat(s), idx + 1];
    if (s === "true") return [true, idx + 1];
    if (s === "false") return [false, idx + 1];
    if (s === "null") return [null, idx + 1];
    if (/^(Color|Vector2|Vector3|Vector2i|Vector3i|Transform2D|Transform3D|Rect2|Packed\w+Array)\(/.test(s)) {
      return [{ _t: "constructor", raw: s, _raw: s }, idx + 1];
    }
    return [s, idx + 1];
  }

  function readString(s, idx, lines) {
    let full = s;
    let i = idx;
    while (!isBalancedString(full) && i < lines.length - 1) {
      i++;
      full += "\n" + lines[i];
    }
    const v = full.trim();
    return [unquote(v), i + 1];
  }

  function isBalancedString(s) {
    let count = 0;
    for (let i = 0; i < s.length; i++) {
      if (s[i] === "\\") { i++; continue; }
      if (s[i] === '"') count++;
    }
    return count % 2 === 0;
  }

  function readTypedArray(s, idx, lines) {
    const typeMatch = s.match(/^Array\[\w+\]\(/);
    if (!typeMatch) return [s, idx + 1];
    const parenStart = s.indexOf("(", typeMatch[0].length - 1);
    let full = s;
    let i = idx;
    let depth = 0;
    for (let j = parenStart; j < full.length; j++) {
      if (full[j] === "(") depth++;
      else if (full[j] === ")") { depth--; if (depth === 0) break; }
    }
    while (depth > 0 && i < lines.length - 1) {
      i++;
      full += "\n" + lines[i];
      for (let j = full.lastIndexOf("\n") + 1 - (lines[i].length + 1); j < full.length; j++) {
        if (full[j] === "(") depth++;
        else if (full[j] === ")") { depth--; if (depth === 0) break; }
      }
    }
    const inner = full.slice(parenStart + 1, full.lastIndexOf(")"));
    const items = smartSplit(inner).map(s => parseValue(s.trim()));
    return [{ _t: "typed_array", type: typeMatch[0].slice(6, -2), items, _raw: s }, i + 1];
  }

  function readBracket(s, idx, lines) {
    let full = s;
    let i = idx;
    let depth = 0;
    const startChar = s[0];
    const endChar = startChar === "[" ? "]" : "}";
    for (let j = 0; j < full.length; j++) {
      if (full[j] === startChar) depth++;
      else if (full[j] === endChar) { depth--; if (depth === 0) break; }
    }
    while (depth > 0 && i < lines.length - 1) {
      i++;
      full += "\n" + lines[i];
      for (let j = 0; j < lines[i].length; j++) {
        const c = lines[i][j];
        if (c === startChar) depth++;
        else if (c === endChar) { depth--; if (depth === 0) break; }
      }
    }
    const inner = full.slice(1, full.lastIndexOf(endChar));
    if (startChar === "[") {
      const arr = smartSplit(inner).map(s => parseValue(s.trim()));
      return [{ _t: "array", items: arr, _raw: s }, i + 1];
    }
    const entries = {};
    for (const part of smartSplit(inner)) {
      const colon = part.indexOf(":");
      if (colon !== -1) {
        const k = unquote(part.slice(0, colon).trim());
        const v = parseValue(part.slice(colon + 1).trim());
        entries[k] = v;
      }
    }
    return [{ _t: "dict", entries, _raw: s }, i + 1];
  }

  function smartSplit(s) {
    const parts = [];
    let cur = "", depth = 0, inStr = false;
    for (let i = 0; i < s.length; i++) {
      const c = s[i];
      if (inStr) {
        cur += c;
        if (c === "\\") { if (i + 1 < s.length) { cur += s[++i]; } continue; }
        if (c === '"') inStr = false;
        continue;
      }
      if (c === '"') { inStr = true; cur += c; continue; }
      if ("([{".includes(c)) depth++;
      else if (")]}".includes(c)) depth--;
      if (c === "," && depth === 0) { parts.push(cur); cur = ""; continue; }
      cur += c;
    }
    if (cur.trim()) parts.push(cur);
    return parts;
  }

  function extractRefId(s) {
    const m = s.match(/\("(.+?)"\)/);
    return m ? m[1] : s;
  }

  function parseValue(s) {
    if (!s) return s;
    if (s === "null") return null;
    if (s === "true") return true;
    if (s === "false") return false;
    if (/^-?\d+$/.test(s)) return parseInt(s, 10);
    if (/^-?\d+\.\d*$/.test(s)) return parseFloat(s);
    if (s.startsWith('"')) return unquote(s);
    if (s.startsWith("ExtResource(")) return { _t: "ExtResource", id: extractRefId(s) };
    if (s.startsWith("SubResource(")) return { _t: "SubResource", id: extractRefId(s) };
    if (/^(Color|Vector2|Vector3|Vector2i|Vector3i|Transform2D|Transform3D|Rect2|Packed\w+Array)\(/.test(s)) {
      return { _t: "constructor", raw: s };
    }
    return s;
  }

  function unquote(s) {
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      return s.slice(1, -1).replace(/\\"/g, '"').replace(/\\\\/g, "\\");
    }
    return s;
  }

  function quote(s) {
    return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
  }

  function escapeRegex(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }

  // ── Serializer ──
  // Uses _raw fields to preserve original text for unedited values.

  function serialize(parsed, editedKeys) {
    const edited = editedKeys || new Set();
    const result = [];
    const h = parsed.header || {};

    const headerAttrs = Object.entries(h)
      .map(([k, v]) => `${k}=${v.raw}`)
      .join(" ");
    result.push(`[gd_resource ${headerAttrs}]`);
    result.push("");

    for (const er of parsed.ext_resources) {
      const attrs = Object.entries(er)
        .filter(([k]) => !k.startsWith("_"))
        .map(([k, val]) => `${k}=${quote(val)}`)
        .join(" ");
      result.push(`[ext_resource ${attrs}]`);
    }
    if (parsed.ext_resources.length > 0) result.push("");

    for (const sr of parsed.sub_resources) {
      const attrs = Object.entries(sr)
        .filter(([k]) => !k.startsWith("_"))
        .map(([k, val]) => `${k}=${quote(val)}`)
        .join(" ");
      result.push(`[sub_resource ${attrs}]`);
      for (const [k, v] of Object.entries(sr._props || {})) {
        if (k.endsWith("__raw")) continue;
        const rawKey = k + "__raw";
        const raw = sr._props[rawKey];
        const objRaw = (v && typeof v === "object" && v._raw) ? v._raw : undefined;
        if (raw !== undefined || objRaw !== undefined) {
          result.push(`${k} = ${raw || objRaw}`);
        } else {
          result.push(`${k} = ${serializeValue(v)}`);
        }
      }
      result.push("");
    }

    result.push("[resource]");
    for (const [k, v] of Object.entries(parsed.properties)) {
      if (k.endsWith("__raw")) continue;
      const rawKey = k + "__raw";
      const raw = parsed.properties[rawKey];
      const objRaw = (v && typeof v === "object" && v._raw) ? v._raw : undefined;
      if (!edited.has(k) && (raw !== undefined || objRaw !== undefined)) {
        result.push(`${k} = ${raw || objRaw}`);
      } else {
        result.push(`${k} = ${serializeValue(v)}`);
      }
    }
    const out = result.join("\n") + "\n";
    if (parsed._rawText && parsed._rawText.endsWith("\n\n")) return out + "\n";
    return out;
  }

  function serializeValue(v) {
    if (v === null) return "null";
    if (typeof v === "boolean") return v ? "true" : "false";
    if (typeof v === "number") {
      if (Number.isInteger(v)) return String(v);
      const s = String(v);
      const dot = s.indexOf(".");
      return dot !== -1 ? s : v.toFixed(1);
    }
    if (typeof v === "string") return quote(v);
    if (v && v._t === "ExtResource") return `ExtResource("${v.id}")`;
    if (v && v._t === "SubResource") return `SubResource("${v.id}")`;
    if (v && v._t === "constructor") return v.raw;
    if (v && v._t === "typed_array") {
      return `Array[${v.type}]([${v.items.map(serializeValue).join(", ")}])`;
    }
    if (v && v._t === "array") {
      return `[${v.items.map(serializeValue).join(", ")}]`;
    }
    if (v && v._t === "dict") {
      const entries = Object.entries(v.entries).map(([k, val]) => `${quote(k)}: ${serializeValue(val)}`);
      return `{\n${entries.join(",\n")}\n}`;
    }
    if (Array.isArray(v)) return `[${v.map(serializeValue).join(", ")}]`;
    if (typeof v === "object") {
      const entries = Object.entries(v).filter(([k]) => !k.startsWith("_")).map(([k, val]) => `${quote(k)}: ${serializeValue(val)}`);
      return `{\n${entries.join(",\n")}\n}`;
    }
    return String(v);
  }

  return { parse, serialize };
})();

if (typeof module !== "undefined") module.exports = TresParser;
