"use strict";
const crypto = require("crypto");

/**
 * RFC 8785 JSON Canonicalization Scheme (JCS) deterministic serializer.
 */
function canonicalize(value) {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return "[" + value.map(canonicalize).join(",") + "]";
  }
  const keys = Object.keys(value).sort();
  return "{" + keys.map((k) => JSON.stringify(k) + ":" + canonicalize(value[k])).join(",") + "}";
}

function sha256Hex(payload) {
  const str = typeof payload === "string" ? payload : canonicalize(payload);
  return crypto.createHash("sha256").update(str, "utf8").digest("hex");
}

module.exports = { canonicalize, sha256Hex };
