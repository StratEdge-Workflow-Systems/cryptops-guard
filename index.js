#!/usr/bin/env node
"use strict";

const { canonicalize, sha256Hex } = require("./src/canonical");
const { ENCLAVE_METADATA } = require("./src/enclave");

const SELECTORS = {
  "0xa9059cbb": "ERC20.transfer",
  "0x095ea7b3": "ERC20.approve",
  "0x3659cfe6": "Proxy.upgradeTo",
  "0x6a761202": "Safe.execTransaction"
};

function inspectPreBroadcastTx(tx, policy = {}) {
  if (!tx || typeof tx !== "object") {
    throw new TypeError("tx object is required");
  }
  const reasons = [];
  let disposition = "ALLOW";

  const data = String(tx.data || "0x").toLowerCase();
  const selector = data.length >= 10 ? data.slice(0, 10) : "0x";
  const operation = Number(tx.operation || 0);

  if (operation === 1) {
    disposition = "BLOCK";
    reasons.push("delegatecall_operation_prohibited");
  }
  if (selector === "0x3659cfe6") {
    disposition = "BLOCK";
    reasons.push("unauthorized_proxy_upgrade_selector");
  }
  if (selector === "0x095ea7b3" && data.includes("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")) {
    disposition = "BLOCK";
    reasons.push("unbounded_uint256_max_approval");
  }
  if (Array.isArray(policy.allowlistedTargets) && !policy.allowlistedTargets.map((a) => a.toLowerCase()).includes(String(tx.to || "").toLowerCase())) {
    disposition = "BLOCK";
    reasons.push("destination_not_allowlisted");
  }

  const payload = {
    chainId: Number(tx.chainId || 8453),
    decodedMethod: SELECTORS[selector] || "raw_call",
    disposition,
    operation,
    reasons,
    selector,
    to: String(tx.to || ""),
    value: String(tx.value || "0")
  };
  const receiptHash = "sha256:" + sha256Hex(canonicalize(payload));
  return { ...payload, receiptHash };
}

module.exports = { inspectPreBroadcastTx, SELECTORS, canonicalize, ENCLAVE_METADATA };
