import { BusinessError } from '@kit.BasicServicesKit';
import usbManager from '@ohos.usbManager';
import native from 'libdiskinfo.so';
import { NativeDisk } from '../model/DiskModels';
import { AppSettings } from './SettingsService';
import { ATA_VARIANTS, AtaVariant, InquiryInfo, UsbBotSession } from './UsbAtaTransport';

export class UsbScanResult {
  disks: NativeDisk[] = [];
  messages: string[] = [];
}

class ProbeTarget {
  lun: number = 0;
  inquiry: InquiryInfo = new InquiryInfo();
}

class VariantOutcome {
  disk: NativeDisk | null = null;
  failure: string = '';
}

function toBuffer(bytes: Uint8Array): ArrayBuffer {
  const buffer = new ArrayBuffer(bytes.length);
  new Uint8Array(buffer).set(bytes);
  return buffer;
}

function errorText(error: BusinessError): string {
  if (error.message !== undefined && error.message.length > 0) {
    return error.message;
  }
  return error.code !== undefined ? 'USB error ' + error.code.toString() : 'USB 读取失败';
}

export class UsbDiskProbe {
  static signature(): string {
    try {
      const devices = usbManager.getDevices();
      if (devices === undefined) {
        return '';
      }
      const keys: string[] = [];
      for (const device of devices) {
        if (UsbBotSession.isMassStorageDevice(device)) {
          keys.push(device.busNum.toString() + ':' + device.devAddress.toString());
        }
      }
      keys.sort();
      return keys.join('|');
    } catch (error) {
      return '';
    }
  }

  static async scan(settings: AppSettings): Promise<UsbScanResult> {
    const result = new UsbScanResult();
    let devices: usbManager.USBDevice[] | undefined = [];
    try {
      devices = usbManager.getDevices();
    } catch (error) {
      result.messages.push('USB 服务不可用');
      return result;
    }
    if (devices === undefined) {
      return result;
    }
    for (const device of devices) {
      if (!UsbBotSession.isMassStorageDevice(device)) {
        continue;
      }
      const label = 'USB ' + device.name;
      let targets: ProbeTarget[] = [];
      try {
        targets = await UsbDiskProbe.probeTargets(device);
      } catch (error) {
        result.messages.push(label + ': ' + errorText(error as BusinessError));
        continue;
      }
      const failures: string[] = [];
      let mounted = false;
      for (const target of targets) {
        for (const variant of ATA_VARIANTS) {
          const outcome = await UsbDiskProbe.tryVariant(device, target.lun, variant, settings);
          if (outcome.disk !== null) {
            const disk = outcome.disk;
            disk.node = 'usb:' + device.busNum.toString() + ':' +
              device.devAddress.toString() + ':' + target.lun.toString();
            disk.bus = 'usb';
            disk.note = target.inquiry.label();
            result.disks.push(disk);
            mounted = true;
            break;
          }
          if (failures.length < 4) {
            failures.push('LUN' + target.lun.toString() + ' ' + variant.label() +
              ': ' + outcome.failure);
          }
        }
        if (mounted) {
          break;
        }
      }
      if (!mounted) {
        result.messages.push(label + ': ' + UsbDiskProbe.describeFailure(targets, failures));
      }
    }
    return result;
  }

  private static describeFailure(targets: ProbeTarget[], failures: string[]): string {
    let bridge = '';
    let sensed = '';
    for (const target of targets) {
      if (target.inquiry.ok) {
        if (bridge.length === 0) {
          bridge = target.inquiry.label();
        }
      } else if (sensed.length === 0) {
        const sense = target.inquiry.sense.describe();
        sensed = 'INQUIRY 失败 (CSW ' + target.inquiry.cswStatus.toString() +
          (sense.length > 0 ? ', ' + sense : '') + ')';
      }
    }
    let detail = '';
    for (const failure of failures) {
      if (detail.length > 0) {
        detail += '; ';
      }
      detail += failure;
    }
    if (detail.length === 0) {
      detail = sensed.length > 0 ? sensed : '未能读取 ATA 信息';
    }
    return (bridge.length > 0 ? '[' + bridge + '] ' : '') + detail;
  }

  private static async probeTargets(device: usbManager.USBDevice): Promise<ProbeTarget[]> {
    const found: ProbeTarget[] = [];
    const session = new UsbBotSession();
    try {
      await session.open(device);
      for (let lun = 0; lun < 2; lun++) {
        session.setLun(lun);
        const target = new ProbeTarget();
        target.lun = lun;
        target.inquiry = await session.inquiry();
        found.push(target);
      }
    } finally {
      await session.close();
    }
    const ordered: ProbeTarget[] = [];
    for (const target of found) {
      if (target.inquiry.isDisk()) {
        ordered.push(target);
      }
    }
    for (const target of found) {
      if (!target.inquiry.isDisk() && target.inquiry.ok) {
        ordered.push(target);
      }
    }
    for (const target of found) {
      if (!target.inquiry.ok) {
        ordered.push(target);
      }
    }
    return ordered;
  }

  private static async tryVariant(device: usbManager.USBDevice, lun: number,
    variant: AtaVariant, settings: AppSettings): Promise<VariantOutcome> {
    const outcome = new VariantOutcome();
    const session = new UsbBotSession();
    try {
      await session.open(device);
      session.setLun(lun);
      session.setVariant(variant);
      const identify = await session.identify();
      if (!identify.ok) {
        outcome.failure = identify.message;
        return outcome;
      }
      const smart = await session.smartReadData();
      if (!smart.ok) {
        outcome.failure = smart.message;
        return outcome;
      }
      const threshold = await session.smartReadThresholds();
      const disk = UsbDiskProbe.interpret(identify.data, smart.data,
        threshold.ok ? threshold.data : null, settings);
      if (!disk.isSsd && (disk.rotationRate === 0 || disk.rotationRateEstimated)) {
        const rate = await session.mediaRotationRate();
        if (rate > 0) {
          disk.rotationRate = rate;
          disk.rotationRateEstimated = false;
        }
      }
      outcome.disk = disk;
      return outcome;
    } catch (error) {
      outcome.failure = errorText(error as BusinessError);
      return outcome;
    } finally {
      await session.close();
    }
  }

  private static interpret(identify: Uint8Array, smart: Uint8Array,
    threshold: Uint8Array | null, settings: AppSettings): NativeDisk {
    const json = native.interpretAta(toBuffer(identify), toBuffer(smart),
      threshold === null ? null : toBuffer(threshold),
      settings.threshold05, settings.thresholdC5, settings.thresholdC6,
      settings.thresholdFF);
    return JSON.parse(json) as NativeDisk;
  }
}

