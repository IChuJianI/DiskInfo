import { SmartAttribute } from '../model/DiskModels';

export function hexId(id: number): string {
  const text = id.toString(16).toUpperCase();
  return text.length < 2 ? '0' + text : text;
}

export function rawWord(raw: number[]): number {
  const lo = raw.length > 0 ? raw[0] : 0;
  const hi = raw.length > 1 ? raw[1] : 0;
  return lo | (hi << 8);
}

export function rawDword(raw: number[]): number {
  const b0 = raw.length > 0 ? raw[0] : 0;
  const b1 = raw.length > 1 ? raw[1] : 0;
  const b2 = raw.length > 2 ? raw[2] : 0;
  const b3 = raw.length > 3 ? raw[3] : 0;
  return (b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)) >>> 0;
}

export function rawQword(raw: number[]): number {
  let value = 0;
  const limit = raw.length < 6 ? raw.length : 6;
  for (let i = limit - 1; i >= 0; i--) {
    value = value * 256 + raw[i];
  }
  return value;
}

export function formatHex(raw: number[]): string {
  let text = '';
  for (let i = raw.length - 1; i >= 0; i--) {
    const byte = raw[i].toString(16).toUpperCase();
    text += byte.length < 2 ? '0' + byte : byte;
  }
  return text;
}

export function formatNumber(value: number): string {
  const text = Math.round(value).toString();
  let out = '';
  let counter = 0;
  for (let i = text.length - 1; i >= 0; i--) {
    out = text.charAt(i) + out;
    counter++;
    if (counter % 3 === 0 && i > 0) {
      out = ',' + out;
    }
  }
  return out;
}

export function formatBytes(bytes: number): string {
  if (!isFinite(bytes) || bytes <= 0) {
    return '---';
  }
  const units: string[] = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  let value = bytes;
  let unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  const digits = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
  return value.toFixed(digits) + ' ' + units[unit];
}

export function formatTemperature(celsius: number, useCelsius: boolean): string {
  if (celsius < 0) {
    return '---';
  }
  const value = useCelsius ? celsius : Math.round(celsius * 9 / 5 + 32);
  return value.toString() + (useCelsius ? ' °C' : ' °F');
}

export function isTemperatureAttribute(id: number): boolean {
  return id === 0xBE || id === 0xC2 || id === 0xF3 || (id >= 0x12 && id <= 0x19);
}

export function formatRaw(attr: SmartAttribute, smartKey: string, hexadecimal: boolean,
  useCelsius: boolean): string {
  if (smartKey === 'SmartNVMe') {
    return formatNvmeRaw(attr, hexadecimal, useCelsius);
  }
  if (hexadecimal) {
    return formatHex(attr.raw);
  }
  switch (attr.id) {
    case 0x09:
    case 0x0C:
    case 0xBE:
    case 0xC2:
    case 0xF3:
      return formatNumber(rawDword(attr.raw));
    case 0x05:
    case 0xC5:
    case 0xC6:
    case 0xE7:
    case 0xE9:
      return formatNumber(rawWord(attr.raw));
    case 0xF1:
    case 0xF2:
      return formatBytes(rawQword(attr.raw) * 512);
    default:
      return formatNumber(rawQword(attr.raw));
  }
}

function formatNvmeRaw(attr: SmartAttribute, hexadecimal: boolean, useCelsius: boolean): string {
  if (hexadecimal) {
    return formatHex(attr.raw);
  }
  switch (attr.id) {
    case 0x01:
      return '0x' + attr.raw[0].toString(16).toUpperCase().padStart(2, '0');
    case 0x02:
    case 0x12:
    case 0x13:
    case 0x14:
    case 0x15:
    case 0x16:
    case 0x17:
    case 0x18:
    case 0x19: {
      const kelvin = rawWord(attr.raw);
      if (kelvin < 200) {
        return '---';
      }
      return formatTemperature(kelvin - 273, useCelsius);
    }
    case 0x03:
    case 0x04:
    case 0x05:
      return attr.raw[0].toString() + ' %';
    case 0x06:
    case 0x07:
      return formatBytes(rawQword(attr.raw) * 1000 * 512);
    case 0x08:
    case 0x09:
    case 0x0B:
    case 0x0D:
    case 0x0E:
    case 0x0F:
      return formatNumber(rawQword(attr.raw));
    case 0x0C:
      return formatNumber(rawDword(attr.raw));
    case 0x0A:
    case 0x10:
    case 0x11:
    case 0x1C:
    case 0x1D:
      return formatNumber(rawQword(attr.raw)) + ' min';
    default:
      return formatNumber(rawQword(attr.raw));
  }
}

export function formFactorText(code: string): string {
  return code.length > 0 ? code : '---';
}
