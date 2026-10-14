"use strict";
const assert = require("assert");
const { inspectPreBroadcastTx } = require("./index");

const r1 = inspectPreBroadcastTx(
  { chainId: 8453, to: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", data: "0xa9059cbb00000000", operation: 0 },
  { allowlistedTargets: ["0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"] }
);
assert.strictEqual(r1.disposition, "ALLOW");

const r2 = inspectPreBroadcastTx({ chainId: 8453, to: "0x1111111111111111111111111111111111111111", data: "0x", operation: 1 });
assert.strictEqual(r2.disposition, "BLOCK");
assert.ok(r2.reasons.includes("delegatecall_operation_prohibited"));
console.log("cryptops-guard: all EVM pre-broadcast firewall tests passed.");
