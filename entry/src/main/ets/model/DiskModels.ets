export interface SmartAttribute {
  id: number;
  current: number;
  worst: number;
  threshold: number;
  flags: number;
  raw: number[];
}

export interface NativeDisk {
  node: string;
  model: string;
  serial: string;
  firmware: string;
  interface: string;
  transferMode: string;
  formFactor: string;
  features: string;
  smartKey: string;
  note: string;
  capacityBytes: number;
  rotationRate: number;
  rotationRateEstimated: boolean;
  powerOnHours: number;
  powerOnMinutes: number;
  powerOnCount: number;
  temperature: number;
  life: number;
  lifeEstimated: boolean;
  powerOnHoursKnown: boolean;
  powerOnActive: boolean;
  health: number;
  bus: string;
  isSsd: boolean;
  isNvme: boolean;
  smartAvailable: boolean;
  attributes: SmartAttribute[];
}

export class DiskScanOutcome {
  disks: NativeDisk[] = [];
  messages: string[] = [];
}

export const HEALTH_UNKNOWN = 0;
export const HEALTH_GOOD = 1;
export const HEALTH_CAUTION = 2;
export const HEALTH_BAD = 3;
