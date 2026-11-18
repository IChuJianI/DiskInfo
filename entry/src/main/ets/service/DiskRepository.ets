import native from 'libdiskinfo.so';
import { DiskScanOutcome } from '../model/DiskModels';
import { AppSettings } from './SettingsService';
import { UsbDiskProbe } from './UsbDiskProbe';

export class DiskRepository {
  static async scan(settings: AppSettings): Promise<DiskScanOutcome> {
    const outcome = new DiskScanOutcome();
    const usb = await UsbDiskProbe.scan(settings);
    for (const message of usb.messages) {
      outcome.messages.push(message);
    }
    for (const disk of usb.disks) {
      outcome.disks.push(disk);
    }
    return outcome;
  }

  static version(): string {
    try {
      return native.version();
    } catch (error) {
      return '';
    }
  }
}
