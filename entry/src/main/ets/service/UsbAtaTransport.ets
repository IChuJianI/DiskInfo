import usbManager from '@ohos.usbManager';
import { BusinessError } from '@kit.BasicServicesKit';

const BULK_TIMEOUT = 3000;
const CBW_SIGNATURE = 0x43425355;
const CSW_SIGNATURE = 0x53425355;

const SCSI_INQUIRY = 0x12;
const SCSI_REQUEST_SENSE = 0x03;
const VPD_BLOCK_CHARACTERISTICS = 0xB1;
const SENSE_LENGTH = 18;
const ATA_PASS_THROUGH_12 = 0xA1;
const ATA_PASS_THROUGH_16 = 0x85;

const ATA_IDENTIFY = 0xEC;
const ATA_SMART = 0xB0;
const SMART_READ_DATA = 0xD0;
const SMART_READ_THRESHOLDS = 0xD1;
const SMART_LBA_LOW = 0x01;
const SMART_LBA_MID = 0x4F;
const SMART_LBA_HIGH = 0xC2;

const PROTOCOL_PIO_IN = 4;
// BYT_BLOK(512) | T_DIR(device->host) | T_LENGTH(sector count)
const PIO_IN_FLAGS = 0x0E;

const SCSI_STATUS_OK = 0;
const SCSI_STATUS_CHECK_CONDITION = 1;

export class AtaVariant {
  ata16: boolean = false;
  device: number = 0x00;

  constructor(ata16: boolean, device: number) {
    this.ata16 = ata16;
    this.device = device;
  }

  label(): string {
    return (this.ata16 ? 'ATA16' : 'ATA12') + '/0x' + this.device.toString(16).toUpperCase();
  }
}

// Bridges differ in whether they accept the 12- or 16-byte SAT wrapper and
// which DEVICE register value they answer on.
export const ATA_VARIANTS: AtaVariant[] = [
  new AtaVariant(false, 0x00),
  new AtaVariant(false, 0xA0),
  new AtaVariant(true, 0x00),
  new AtaVariant(true, 0xA0)
];

export class SenseInfo {
  valid: boolean = false;
  key: number = 0;
  asc: number = 0;
  ascq: number = 0;

  hint(): string {
    if (!this.valid) {
      return '';
    }
    if (this.key === 0x05 && this.asc === 0x20) {
      return '设备不支持该 ATA 透传命令';
    }
    if (this.key === 0x05 && this.asc === 0x24) {
      return 'ATA 透传参数不被接受';
    }
    if (this.key === 0x05 && this.asc === 0x25) {
      return '该 LUN 不存在';
    }
    if (this.key === 0x02) {
      return '设备未就绪';
    }
    if (this.key === 0x0B) {
      return '硬盘拒绝了该 ATA 命令';
    }
    return '';
  }

  describe(): string {
    if (!this.valid) {
      return '';
    }
    let text = 'sense 0x' + this.key.toString(16).toUpperCase() +
      '/0x' + this.asc.toString(16).toUpperCase() +
      '/0x' + this.ascq.toString(16).toUpperCase();
    const hint = this.hint();
    if (hint.length > 0) {
      text += ' ' + hint;
    }
    return text;
  }
}

export class InquiryInfo {
  ok: boolean = false;
  deviceType: number = 0;
  vendor: string = '';
  product: string = '';
  cswStatus: number = 0;
  sense: SenseInfo = new SenseInfo();

  isDisk(): boolean {
    return this.ok && (this.deviceType === 0x00 || this.deviceType === 0x0E);
  }

  label(): string {
    const name = (this.vendor + ' ' + this.product).trim();
    return name.length > 0 ? name : 'USB 存储设备';
  }
}

export class AtaResponse {
  ok: boolean = false;
  data: Uint8Array = new Uint8Array(0);
  status: number = 0;
  sense: SenseInfo = new SenseInfo();
  message: string = '';
}

class TransferResult {
  status: number = 0;
  data: Uint8Array = new Uint8Array(0);

  constructor(status: number, data: Uint8Array) {
    this.status = status;
    this.data = data;
  }
}

function writeLe32(target: Uint8Array, offset: number, value: number): void {
  target[offset] = value & 0xFF;
  target[offset + 1] = (value >>> 8) & 0xFF;
  target[offset + 2] = (value >>> 16) & 0xFF;
  target[offset + 3] = (value >>> 24) & 0xFF;
}

function readLe32(source: Uint8Array, offset: number): number {
  return (source[offset] | (source[offset + 1] << 8) |
    (source[offset + 2] << 16) | (source[offset + 3] << 24)) >>> 0;
}

function asciiText(source: Uint8Array, offset: number, length: number): string {
  let text = '';
  const end = offset + length < source.length ? offset + length : source.length;
  for (let i = offset; i < end; i++) {
    const code = source[i];
    if (code >= 0x20 && code < 0x7F) {
      text += String.fromCharCode(code);
    }
  }
  return text.trim();
}

function errorText(error: BusinessError): string {
  if (error.message !== undefined && error.message.length > 0) {
    return error.message;
  }
  return error.code !== undefined ? 'USB error ' + error.code.toString() : 'USB error';
}

export class UsbBotSession {
  private pipe: usbManager.USBDevicePipe | null = null;
  private iface: usbManager.USBInterface | null = null;
  private epIn: usbManager.USBEndpoint | null = null;
  private epOut: usbManager.USBEndpoint | null = null;
  private tag: number = 0x5A5A0001;
  private lun: number = 0;
  private variant: AtaVariant = ATA_VARIANTS[0];

  static isMassStorageDevice(device: usbManager.USBDevice): boolean {
    for (const config of device.configs) {
      for (const iface of config.interfaces) {
        if (iface.clazz === 8) {
          return true;
        }
      }
    }
    return false;
  }

  setLun(lun: number): void {
    this.lun = lun & 0x0F;
  }

  setVariant(variant: AtaVariant): void {
    this.variant = variant;
  }

  private scoreInterface(iface: usbManager.USBInterface): number {
    let score = 0;
    if (iface.protocol === 0x50) {
      score += 4;
    } else if (iface.protocol === 0x00) {
      score += 3;
    }
    if (iface.subClass === 0x06) {
      score += 1;
    }
    return score;
  }

  async open(device: usbManager.USBDevice): Promise<void> {
    const granted = await usbManager.requestRight(device.name);
    if (!granted) {
      throw new Error('USB 访问权限被拒绝');
    }
    this.pipe = usbManager.connectDevice(device);
    let config: usbManager.USBConfiguration | null = null;
    let best = -1;
    for (const item of device.configs) {
      for (const iface of item.interfaces) {
        if (iface.clazz !== 8) {
          continue;
        }
        const score = this.scoreInterface(iface);
        if (score > best) {
          best = score;
          config = item;
          this.iface = iface;
        }
      }
    }
    if (this.iface === null || config === null) {
      throw new Error('设备不是 USB 大容量存储');
    }
    const iface = this.iface;
    let claim = usbManager.claimInterface(this.pipe, iface, true);
    if (claim !== 0) {
      try {
        usbManager.setConfiguration(this.pipe, config);
      } catch (error) {
      }
      try {
        usbManager.setInterface(this.pipe, iface);
      } catch (error) {
      }
      claim = usbManager.claimInterface(this.pipe, iface, true);
    }
    if (claim !== 0) {
      throw new Error('无法占用 USB 存储接口');
    }
    for (const endpoint of iface.endpoints) {
      const isBulk = (endpoint.attributes & 0x03) === 0x02;
      if (!isBulk) {
        continue;
      }
      if ((endpoint.address & 0x80) !== 0) {
        if (this.epIn === null) {
          this.epIn = endpoint;
        }
      } else if (this.epOut === null) {
        this.epOut = endpoint;
      }
    }
    if (this.epIn === null || this.epOut === null) {
      throw new Error('未找到 USB 批量传输端点');
    }
  }

  async close(): Promise<void> {
    if (this.pipe === null) {
      return;
    }
    try {
      if (this.iface !== null) {
        usbManager.releaseInterface(this.pipe, this.iface);
      }
    } catch (error) {
    }
    try {
      usbManager.closePipe(this.pipe);
    } catch (error) {
    }
    this.pipe = null;
    this.iface = null;
    this.epIn = null;
    this.epOut = null;
  }

  async inquiry(): Promise<InquiryInfo> {
    const info = new InquiryInfo();
    const cdb: number[] = [SCSI_INQUIRY, 0x00, 0x00, 0x00, 36, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
    const result = await this.transfer(cdb, true, 36);
    info.cswStatus = result.status;
    if (result.status === SCSI_STATUS_CHECK_CONDITION) {
      info.sense = await this.requestSense();
    }
    if (result.status !== SCSI_STATUS_OK || result.data.length < 36) {
      return info;
    }
    info.ok = true;
    info.deviceType = result.data[0] & 0x1F;
    info.vendor = asciiText(result.data, 8, 8);
    info.product = asciiText(result.data, 16, 16);
    return info;
  }

  // SCSI VPD page B1 mirrors the media rotation rate for bridges that zero
  // out ATA IDENTIFY word 217. Returns 0 when the value is not reported.
  async mediaRotationRate(): Promise<number> {
    const cdb: number[] = [SCSI_INQUIRY, 0x01, VPD_BLOCK_CHARACTERISTICS, 0x00, 64,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
    const result = await this.transfer(cdb, true, 64);
    if (result.status !== SCSI_STATUS_OK || result.data.length < 6) {
      return 0;
    }
    if (result.data[1] !== VPD_BLOCK_CHARACTERISTICS) {
      return 0;
    }
    const rate = (result.data[4] << 8) | result.data[5];
    if (rate <= 1 || rate === 0xFFFF) {
      return 0;
    }
    return rate;
  }

  async identify(): Promise<AtaResponse> {
    return this.ataRead(ATA_IDENTIFY, 0x00);
  }

  async smartReadData(): Promise<AtaResponse> {
    return this.ataRead(ATA_SMART, SMART_READ_DATA);
  }

  async smartReadThresholds(): Promise<AtaResponse> {
    return this.ataRead(ATA_SMART, SMART_READ_THRESHOLDS);
  }

  private buildReadCdb(command: number, features: number): number[] {
    // Only SMART commands carry the 4F:C2 signature; IDENTIFY wants LBA cleared.
    const smart = command === ATA_SMART;
    const lbaLow = smart ? SMART_LBA_LOW : 0x00;
    const lbaMid = smart ? SMART_LBA_MID : 0x00;
    const lbaHigh = smart ? SMART_LBA_HIGH : 0x00;
    if (this.variant.ata16) {
      return [
        ATA_PASS_THROUGH_16,
        PROTOCOL_PIO_IN << 1,
        PIO_IN_FLAGS,
        0x00, features,
        0x00, 0x01,
        lbaLow, 0x00,
        lbaMid, 0x00,
        lbaHigh, 0x00,
        this.variant.device,
        command,
        0x00
      ];
    }
    return [
      ATA_PASS_THROUGH_12,
      PROTOCOL_PIO_IN << 1,
      PIO_IN_FLAGS,
      features,
      0x01,
      lbaLow,
      lbaMid,
      lbaHigh,
      this.variant.device,
      command,
      0x00,
      0x00
    ];
  }

  private async ataRead(command: number, features: number): Promise<AtaResponse> {
    const response = new AtaResponse();
    const cdb = this.buildReadCdb(command, features);
    let result = await this.transfer(cdb, true, 512);
    if (result.status === SCSI_STATUS_CHECK_CONDITION) {
      response.sense = await this.requestSense();
    }
    if (result.status < 0) {
      // A halted IN pipe truncates the data phase; recover and retry once.
      await this.clearHalt(true);
      result = await this.transfer(cdb, true, 512);
      if (result.status === SCSI_STATUS_CHECK_CONDITION) {
        response.sense = await this.requestSense();
      } else {
        response.sense = new SenseInfo();
      }
    }
    response.status = result.status;
    response.data = result.data;
    let allZero = result.data.length >= 512;
    if (allZero) {
      for (let i = 0; i < 512; i++) {
        if (result.data[i] !== 0) {
          allZero = false;
          break;
        }
      }
    }
    response.ok = result.status === SCSI_STATUS_OK && result.data.length >= 512 && !allZero;
    if (!response.ok) {
      let text = 'ATA 命令 0x' + command.toString(16).toUpperCase() +
        ' 失败 (CSW ' + result.status.toString();
      const sense = response.sense.describe();
      if (sense.length > 0) {
        text += ', ' + sense;
      }
      response.message = text + ')';
      if (result.status < 0) {
        await this.clearHalt(false);
      }
    }
    return response;
  }

  private async requestSense(): Promise<SenseInfo> {
    const sense = new SenseInfo();
    const cdb: number[] = [SCSI_REQUEST_SENSE, 0x00, 0x00, 0x00, SENSE_LENGTH, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
    const result = await this.transfer(cdb, true, SENSE_LENGTH);
    if (result.status !== SCSI_STATUS_OK || result.data.length < 4) {
      return sense;
    }
    const code = result.data[0] & 0x7F;
    if (code === 0x70 || code === 0x71) {
      if (result.data.length < 14) {
        return sense;
      }
      sense.valid = true;
      sense.key = result.data[2] & 0x0F;
      sense.asc = result.data[12];
      sense.ascq = result.data[13];
    } else if (code === 0x72 || code === 0x73) {
      sense.valid = true;
      sense.key = result.data[1] & 0x0F;
      sense.asc = result.data[2];
      sense.ascq = result.data[3];
    }
    return sense;
  }

  private async transfer(cdb: number[], dataIn: boolean, dataLength: number): Promise<TransferResult> {
    if (this.pipe === null || this.epIn === null || this.epOut === null) {
      throw new Error('USB 管道未就绪');
    }
    const tag = this.nextTag();
    const cbw = new Uint8Array(31);
    writeLe32(cbw, 0, CBW_SIGNATURE);
    writeLe32(cbw, 4, tag);
    writeLe32(cbw, 8, dataLength);
    cbw[12] = dataIn ? 0x80 : 0x00;
    cbw[13] = this.lun;
    cbw[14] = cdb.length;
    for (let i = 0; i < cdb.length && i < 16; i++) {
      cbw[15 + i] = cdb[i];
    }

    try {
      await usbManager.bulkTransfer(this.pipe, this.epOut, cbw, BULK_TIMEOUT);
    } catch (error) {
      throw new Error('USB 命令写入失败: ' + errorText(error as BusinessError));
    }

    let data = new Uint8Array(0);
    if (dataIn && dataLength > 0) {
      data = await this.readData(this.epIn, dataLength);
      // Some bridges return the CSW inside a short data packet instead of
      // stalling the pipe. Split it off and treat it as the status phase.
      if (this.looksLikeCsw(data, tag)) {
        const base = data.length - 13;
        return new TransferResult(data[base + 12], data.subarray(0, base));
      }
    }

    let csw = await this.readData(this.epIn, 13);
    if (csw.length < 13) {
      await this.clearHalt(true);
      csw = await this.readData(this.epIn, 13);
    }
    if (csw.length < 13) {
      return new TransferResult(-1, data);
    }
    if (readLe32(csw, 0) !== CSW_SIGNATURE || readLe32(csw, 4) !== tag) {
      return new TransferResult(-2, data);
    }
    return new TransferResult(csw[12], data);
  }

  private looksLikeCsw(data: Uint8Array, tag: number): boolean {
    if (data.length < 13) {
      return false;
    }
    const base = data.length - 13;
    return readLe32(data, base) === CSW_SIGNATURE && readLe32(data, base + 4) === tag;
  }

  private async readData(endpoint: usbManager.USBEndpoint, length: number): Promise<Uint8Array> {
    if (this.pipe === null) {
      return new Uint8Array(0);
    }
    const output = new Uint8Array(length);
    const packet = endpoint.maxPacketSize > 0 ? endpoint.maxPacketSize : 512;
    let offset = 0;
    while (offset < length) {
      const chunk = new Uint8Array(length - offset);
      let received = 0;
      try {
        received = await usbManager.bulkTransfer(this.pipe, endpoint, chunk, BULK_TIMEOUT);
      } catch (error) {
        break;
      }
      if (received <= 0) {
        break;
      }
      output.set(chunk.subarray(0, received), offset);
      offset += received;
      if (received < packet && offset < length) {
        break;
      }
    }
    return output.subarray(0, offset);
  }

  private async clearHalt(input: boolean): Promise<void> {
    if (this.pipe === null) {
      return;
    }
    const endpoint = input ? this.epIn : this.epOut;
    if (endpoint === null) {
      return;
    }
    const request: usbManager.USBDeviceRequestParams = {
      bmRequestType: 0x02,
      bRequest: 0x01,
      wValue: 0x0000,
      wIndex: endpoint.address,
      wLength: 0,
      data: new Uint8Array(0)
    };
    try {
      await usbManager.usbControlTransfer(this.pipe, request, BULK_TIMEOUT);
    } catch (error) {
    }
  }

  private nextTag(): number {
    this.tag = (this.tag + 1) >>> 0;
    if (this.tag === 0) {
      this.tag = 1;
    }
    return this.tag;
  }
}
