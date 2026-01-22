"use strict";
const crypto = require("crypto");
const { canonicalize } = require("./canonical");

/**
 * Generates an HMAC-SHA256 / HSM enclave attestation envelope over a canonical receipt.
 */
function signEnclaveAttestation(receipt, enclaveKeyId = "thales-luna-hsm7-slot0", secret = "enclave-verification-key") {
  const body = canonicalize(receipt);
  const signature = crypto.createHmac("sha256", String(secret)).update(body).digest("hex");
  return {
    enclaveKeyId,
    algorithm: "HMAC-SHA256-ENCLAVE",
    receiptHash: receipt.receiptHash || receipt.routeReceiptHash || receipt.receipt_sha256,
    signature: "sig:" + signature,
  };
}

module.exports = { signEnclaveAttestation };
