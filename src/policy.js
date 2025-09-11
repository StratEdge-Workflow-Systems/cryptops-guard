"use strict";

/**
 * Deterministic policy normalization and fail-closed rule validator.
 */
function validatePolicyEnvelope(policy) {
  if (!policy || typeof policy !== "object") {
    return { valid: false, reason: "missing_policy_envelope" };
  }
  const version = String(policy.version || "2.4.0");
  const mode = policy.failOpen === true ? "INVALID_FAIL_OPEN" : "FAIL_CLOSED";
  return {
    valid: mode === "FAIL_CLOSED",
    version,
    mode,
    maxVelocityUsd: Number(policy.maxVelocityUsd || 250000),
  };
}

module.exports = { validatePolicyEnvelope };
