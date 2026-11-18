export interface NativeAttribute {
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
  powerOnHours: number;
  powerOnCount: number;
  temperature: number;
  life: number;
  health: number;
  bus: string;
  isSsd: boolean;
  isNvme: boolean;
  smartAvailable: boolean;
  attributes: NativeAttribute[];
}

export const interpretAta: (identify: ArrayBuffer, smart: ArrayBuffer,
  threshold: ArrayBuffer | null, threshold05: number, thresholdC5: number,
  thresholdC6: number, thresholdFF: number) => string;

export const version: () => string;
