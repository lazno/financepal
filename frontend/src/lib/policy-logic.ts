import type { PolicySensitivity } from './api';

export function calculateBand(
  targetBps: number,
  sensitivity: PolicySensitivity
): [number, number] {
  const { rel_bps, floor_bps, cap_bps } = sensitivity;

  // Calculate relative half-width
  // (target * rel) / 10000
  // We use Math.round to match Gleam's integer arithmetic behavior if needed,
  // but standard JS float math is usually fine for display.
  // However, to match backend exactly:
  const relHalfBps = Math.round((targetBps * rel_bps) / 10000);

  // Clamp between floor and cap
  const halfBps = Math.max(floor_bps, Math.min(cap_bps, relHalfBps));

  // Calculate bounds
  const lowerBound = Math.max(0, targetBps - halfBps);
  const upperBound = Math.min(10000, targetBps + halfBps);

  return [lowerBound, upperBound];
}

export function bpsToPct(bps: number): number {
  return bps / 100;
}

export function pctToBps(pct: number): number {
  return Math.round(pct * 100);
}
