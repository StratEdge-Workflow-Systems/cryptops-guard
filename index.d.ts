export interface EvmTxPayload {
  chainId?: number;
  to: string;
  value?: string | number;
  data?: string;
  operation?: 0 | 1;
}
export interface FirewallPolicy {
  allowlistedTargets?: string[];
}
export function inspectPreBroadcastTx(tx: EvmTxPayload, policy?: FirewallPolicy): Record<string, unknown>;
