// Portions derived from CrystalDiskInfo (https://github.com/hiyohiyo/CrystalDiskInfo),
// Copyright (c) 2008-2023 hiyohiyo. Licensed under the MIT License.
#include "cdi_interpret.h"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace cdi {

namespace {

constexpr uint16_t Word(const uint8_t* data, size_t index) {
  return static_cast<uint16_t>(data[index * 2]) |
         static_cast<uint16_t>(data[index * 2 + 1]) << 8;
}

std::string AtaString(const uint8_t* data, size_t byteOffset, size_t chars) {
  std::string out;
  out.reserve(chars);
  for (size_t i = 0; i + 1 < chars; i += 2) {
    const char high = static_cast<char>(data[byteOffset + i + 1]);
    const char low = static_cast<char>(data[byteOffset + i]);
    if (high == 0) {
      break;
    }
    out.push_back(high);
    if (low == 0) {
      break;
    }
    out.push_back(low);
  }
  while (!out.empty() &&
         (out.back() == ' ' || static_cast<unsigned char>(out.back()) < 0x20)) {
    out.pop_back();
  }
  size_t start = 0;
  while (start < out.size() && out[start] == ' ') {
    ++start;
  }
  return out.substr(start);
}

std::string NvmeString(const uint8_t* data, size_t offset, size_t length) {
  std::string out(reinterpret_cast<const char*>(data + offset), length);
  size_t end = out.find('\0');
  if (end != std::string::npos) {
    out.resize(end);
  }
  while (!out.empty() && out.back() == ' ') {
    out.pop_back();
  }
  size_t start = 0;
  while (start < out.size() && out[start] == ' ') {
    ++start;
  }
  return out.substr(start);
}

bool Contains(const std::string& text, const char* needle) {
  return text.find(needle) != std::string::npos;
}

bool StartsWith(const std::string& text, const char* prefix) {
  return text.rfind(prefix, 0) == 0;
}

int TrailingInt(const std::string& text) {
  if (text.size() < 3) {
    return 0;
  }
  return std::atoi(text.c_str() + text.size() - 3);
}

int AtaMajorVersion(uint16_t w80) {
  if (w80 == 0x0000 || w80 == 0xFFFF) {
    return 0;
  }
  for (int bit = 14; bit > 0; --bit) {
    if ((w80 >> bit) & 0x1) {
      return bit;
    }
  }
  return 0;
}

uint32_t InferRotationRate(const std::string& upperModel) {
  // Drives that predate ATA-7 leave IDENTIFY word 217 at zero. Samsung's
  // series documentation gives the spindle speed for these families:
  // SpinPoint P (3.5") = 7200, SpinPoint V / M (2.5") = 5400.
  if (StartsWith(upperModel, "SAMSUNG SP")) {
    return 7200;
  }
  if (StartsWith(upperModel, "SAMSUNG SV") ||
      StartsWith(upperModel, "SAMSUNG MP")) {
    return 5400;
  }
  return 0;
}

std::string Upper(const std::string& text) {
  std::string out = text;
  std::transform(out.begin(), out.end(), out.begin(),
                 [](unsigned char c) { return static_cast<char>(::toupper(c)); });
  return out;
}

// Mirrors CrystalDiskInfo's GetTimeUnitType(): the unit of SMART 0x09 depends
// on model/firmware/transfer mode, not on the IDENTIFY spec.
PowerOnUnit DetectPowerOnUnit(const std::string& modelText,
                              const std::string& firmware, uint16_t w76,
                              uint16_t w80) {
  const std::string model = Upper(modelText);
  const bool sata300OrFaster = (w76 & 0x000C) != 0;
  if (StartsWith(model, "FUJITSU")) {
    return AtaMajorVersion(w80) >= 8 ? PowerOnUnit::Hours
                                     : PowerOnUnit::Seconds;
  }
  if (StartsWith(model, "HITACHI_DK")) {
    return PowerOnUnit::Minutes;
  }
  if (StartsWith(model, "MAXTOR")) {
    if (sata300OrFaster || StartsWith(model, "MAXTOR 6H") ||
        StartsWith(model, "MAXTOR 7H500") ||
        StartsWith(model, "MAXTOR 6L0") || StartsWith(model, "MAXTOR 4K")) {
      return PowerOnUnit::Hours;
    }
    return PowerOnUnit::Minutes;
  }
  if (StartsWith(model, "SAMSUNG")) {
    if (sata300OrFaster) {
      return PowerOnUnit::Hours;
    }
    const int firmwareSuffix = TrailingInt(firmware);
    if (firmwareSuffix >= -39 && firmwareSuffix <= -23) {
      return PowerOnUnit::HalfMinutes;
    }
    if (StartsWith(model, "SAMSUNG SV") || StartsWith(model, "SAMSUNG SP") ||
        StartsWith(model, "SAMSUNG HM") || StartsWith(model, "SAMSUNG MP")) {
      return PowerOnUnit::HalfMinutes;
    }
    return PowerOnUnit::Hours;
  }
  const float firmwareVersion = std::strtof(firmware.c_str(), nullptr);
  if (((StartsWith(model, "CFD_CSSD-S6TM128NMPQ") ||
        StartsWith(model, "CFD_CSSD-S6TM256NMPQ")) &&
       (StartsWith(firmware, "VM21") || StartsWith(firmware, "VN21"))) ||
      ((Contains(model, "PX-128M2P") || Contains(model, "PX-256M2P")) &&
       firmwareVersion < 1.059f) ||
      (StartsWith(model, "CORSAIR PERFORMANCE PRO") &&
       firmwareVersion < 1.059f)) {
    return PowerOnUnit::TenMinutes;
  }
  if ((StartsWith(model, "INTEL SSDSC2CW") ||
       StartsWith(model, "INTEL SSDSC2BW") ||
       StartsWith(model, "INTEL SSDSC2CT")) &&
      Contains(model, "A3")) {
    return PowerOnUnit::Milliseconds;
  }
  return PowerOnUnit::Hours;
}

void AppendFeature(std::string& features, const char* name) {
  if (!features.empty()) {
    features += "/";
  }
  features += name;
}

std::string FormFactorName(uint16_t code) {
  switch (code) {
    case 1: return "5.25\"";
    case 2: return "3.5\"";
    case 3: return "2.5\"";
    case 4: return "1.8\"";
    case 5: return "< 1.8\"";
    case 6: return "mSATA";
    case 7: return "M.2";
    case 8: return "MicroSSD";
    case 9: return "CFast";
    case 10: return "eMMC";
    default: return "";
  }
}

std::string BuildTransferMode(const uint8_t* data, std::string& interfaceName) {
  const uint16_t w63 = Word(data, 63);
  const uint16_t w76 = Word(data, 76);
  const uint16_t w77 = Word(data, 77);
  const uint16_t w88 = Word(data, 88);

  std::string current;
  std::string maximum;

  if (w76 != 0x0000 && w76 != 0xFFFF) {
    interfaceName = "Serial ATA";
    maximum = "SATA/150";
    if (w76 & 0x0010) {
      maximum = "----";
    } else if (w76 & 0x0008) {
      maximum = "SATA/600";
    } else if (w76 & 0x0004) {
      maximum = "SATA/300";
    } else if (w76 & 0x0002) {
      maximum = "SATA/150";
    }
    const uint16_t speed = static_cast<uint16_t>((w77 & 0x000E) >> 1);
    if (speed == 3) {
      current = "SATA/600";
    } else if (speed == 2) {
      current = "SATA/300";
    } else if (speed == 1) {
      current = "SATA/150";
    } else {
      current = "----";
    }
    return current + " | " + maximum;
  }

  if (w88 & 0x007F) {
    interfaceName = "Parallel ATA";
    if (w88 & 0x0040) maximum = "UDMA/133";
    else if (w88 & 0x0020) maximum = "UDMA/100";
    else if (w88 & 0x0010) maximum = "UDMA/66";
    else if (w88 & 0x0008) maximum = "UDMA/44";
    else if (w88 & 0x0004) maximum = "UDMA/33";
    else if (w88 & 0x0002) maximum = "UDMA/25";
    else if (w88 & 0x0001) maximum = "UDMA/16";

    if (w88 & 0x4000) current = "UDMA/133";
    else if (w88 & 0x2000) current = "UDMA/100";
    else if (w88 & 0x1000) current = "UDMA/66";
    else if (w88 & 0x0800) current = "UDMA/44";
    else if (w88 & 0x0400) current = "UDMA/33";
    else if (w88 & 0x0200) current = "UDMA/25";
    else if (w88 & 0x0100) current = "UDMA/16";
    if (current.empty()) {
      current = "----";
    }
    return current + " | " + maximum;
  }

  if (w63 & 0x0700) {
    interfaceName = "ATA";
    return "PIO/DMA | PIO/DMA";
  }

  interfaceName = "ATA";
  return "";
}

bool IsCriticalAttribute(uint8_t id) {
  return (id >= 0x01 && id <= 0x0D) || id == 0x16 ||
         (id >= 0xBB && id <= 0xBD) || (id >= 0xBF && id <= 0xC1) ||
         (id >= 0xC3 && id <= 0xD1) || (id >= 0xD3 && id <= 0xD4) ||
         (id >= 0xDC && id <= 0xE4) || (id >= 0xE6 && id <= 0xE7) ||
         id == 0xF0 || id == 0xFA || id == 0xFE;
}

uint16_t ThresholdFor(uint8_t id, const InterpretOptions& options) {
  switch (id) {
    case 0x05: return options.threshold05;
    case 0xC5: return options.thresholdC5;
    case 0xC6: return options.thresholdC6;
    default: return 0;
  }
}

void FillLifeFromAttributes(DiskInfo& disk) {
  const std::string upperModel = Upper(disk.model);
  int life = -1;
  disk.lifeEstimated = false;
  if (disk.isSsd) {
    for (const SmartAttribute& attr : disk.attributes) {
      switch (attr.id) {
        case 0xE7:
        case 0xE9:
        case 0xCA:
        case 0xB1:
        case 0xD1:
        case 0xBB:
        case 0xF5:
        case 0xC9:
          life = attr.current;
          break;
        case 0xAD:
          life = static_cast<int>(attr.current) - 100;
          break;
        case 0xE6:
          if (Contains(upperModel, "WDC") || Contains(upperModel, "SANDISK") ||
              Contains(upperModel, "WD ")) {
            life = 100 - attr.raw[1];
          }
          break;
        default:
          continue;
      }
      if (life >= 0) {
        break;
      }
    }
  } else {
    // Mechanical drives expose no wear-level attribute; the values some
    // vendors use in 0xBB/0xC9 are counters (often 200/253), so estimate from
    // the lowest normalized value among critical attributes instead.
    int worstCurrent = -1;
    for (const SmartAttribute& attr : disk.attributes) {
      if (!IsCriticalAttribute(attr.id) || attr.id == 0x09 || attr.id == 0x0C) {
        continue;
      }
      int value = attr.current > 100 ? 100 : attr.current;
      if (worstCurrent < 0 || value < worstCurrent) {
        worstCurrent = value;
      }
    }
    if (worstCurrent >= 0) {
      life = worstCurrent;
    }
  }
  if (life < 0 || life > 100) {
    life = -1;
  }
  // No ATA attribute reports a true wear level on rotating media, so any life
  // value shown for a mechanical drive is an estimate.
  disk.lifeEstimated = !disk.isSsd && life >= 0;
  disk.life = life;
}

Health EvaluateAtaHealth(const DiskInfo& disk, const InterpretOptions& options) {
  if (!disk.smartAvailable) {
    return Health::Unknown;
  }
  bool hasThreshold = false;
  for (const SmartAttribute& attr : disk.attributes) {
    if (attr.threshold != 0) {
      hasThreshold = true;
      break;
    }
  }
  if (!disk.isSsd && !hasThreshold) {
    return Health::Unknown;
  }

  int error = 0;
  int caution = 0;
  bool evaluated = false;

  for (size_t i = 0; i < disk.attributes.size(); ++i) {
    const SmartAttribute& attr = disk.attributes[i];
    for (size_t j = 0; j < i; ++j) {
      if (attr.id != 0 && disk.attributes[j].id == attr.id) {
        return Health::Unknown;
      }
    }

    if (disk.isSsd && attr.threshold != 0) {
      evaluated = true;
    }
    if (disk.isSsd && attr.threshold != 0 && attr.current < attr.threshold) {
      ++error;
    } else if (IsCriticalAttribute(attr.id) && attr.threshold != 0 &&
               attr.current < attr.threshold) {
      ++error;
    }

    if (attr.id == 0x05 || attr.id == 0xC5 || attr.id == 0xC6) {
      if (!disk.isSsd) {
        evaluated = true;
        const uint16_t raw = B8toB16le(attr.raw);
        const uint16_t threshold = ThresholdFor(attr.id, options);
        if (!(attr.raw[0] == 0xFF && attr.raw[1] == 0xFF) && threshold > 0 &&
            raw >= threshold) {
          caution = 1;
        }
      }
    }
  }

  if (disk.life >= 0) {
    evaluated = true;
    if (disk.life == 0) {
      error = 1;
    } else if (disk.life <= options.thresholdFF) {
      caution = 1;
    }
  }

  if (error > 0) {
    return Health::Bad;
  }
  if (!evaluated) {
    return Health::Unknown;
  }
  if (caution > 0) {
    return Health::Caution;
  }
  return Health::Good;
}

}  // namespace

uint16_t B8toB16le(const uint8_t* b) {
  return static_cast<uint16_t>(b[0]) | static_cast<uint16_t>(b[1]) << 8;
}

uint32_t B8toB32le(const uint8_t* b) {
  return static_cast<uint32_t>(b[0]) | static_cast<uint32_t>(b[1]) << 8 |
         static_cast<uint32_t>(b[2]) << 16 | static_cast<uint32_t>(b[3]) << 24;
}

uint64_t B8toB64le(const uint8_t* b) {
  uint64_t value = 0;
  for (int i = 5; i >= 0; --i) {
    value = (value << 8) | b[i];
  }
  return value;
}

int32_t B8toINTle(const uint8_t* b) {
  return static_cast<int32_t>(B8toB32le(b));
}

bool ParseAtaIdentify(const uint8_t* data, size_t len, DiskInfo& disk) {
  if (data == nullptr || len < 512) {
    return false;
  }
  disk.bus = Bus::Ata;
  disk.isNvme = false;
  disk.model = AtaString(data, 27 * 2, 40);
  disk.serial = AtaString(data, 10 * 2, 20);
  disk.firmware = AtaString(data, 23 * 2, 8);
  disk.interfaceName = "ATA";
  disk.transferMode = BuildTransferMode(data, disk.interfaceName);
  disk.powerOnUnit =
      DetectPowerOnUnit(disk.model, disk.firmware, Word(data, 76), Word(data, 80));

  const uint16_t w106 = Word(data, 106);
  uint32_t logicalSectorSize = 512;
  if ((w106 & 0xC000) == 0x4000) {
    if ((w106 & 0x000F) == 0x3) {
      // 512e: 512-byte logical sectors, 4096-byte physical sectors.
      logicalSectorSize = 512;
    } else if ((w106 & 0x1000) != 0) {
      const uint32_t words = (static_cast<uint32_t>(Word(data, 118)) << 16) |
                             Word(data, 117);
      if (words != 0 && words != 256 && words != 0xFFFF) {
        logicalSectorSize = words * 2;
      }
    }
  }

  const bool lba48 = (Word(data, 83) & 0x0400) != 0;
  uint64_t sectors = lba48 ? (static_cast<uint64_t>(Word(data, 103)) << 48 |
                              static_cast<uint64_t>(Word(data, 102)) << 32 |
                              static_cast<uint64_t>(Word(data, 101)) << 16 |
                              Word(data, 100))
                           : (static_cast<uint32_t>(Word(data, 61)) << 16 |
                              Word(data, 60));
  if (sectors == 0) {
    sectors = static_cast<uint32_t>(Word(data, 61)) << 16 | Word(data, 60);
  }
  disk.capacityBytes = sectors * logicalSectorSize;

  disk.rotationRate = Word(data, 217);
  if (disk.rotationRate == 0xFFFF) {
    disk.rotationRate = 0;
  }
  const std::string upperModel = Upper(disk.model);
  disk.isSsd = disk.rotationRate == 1 ||
               (disk.rotationRate == 0 &&
                (Contains(upperModel, "SSD") || Contains(upperModel, "SOLID STATE")));
  if (!disk.isSsd && disk.rotationRate == 0) {
    const uint32_t inferred = InferRotationRate(upperModel);
    if (inferred > 0) {
      disk.rotationRate = inferred;
      disk.rotationRateEstimated = true;
    }
  }
  disk.formFactor = FormFactorName(Word(data, 168));

  const uint16_t w82 = Word(data, 82);
  const uint16_t w83 = Word(data, 83);
  const uint16_t w84 = Word(data, 84);
  const uint16_t w76 = Word(data, 76);
  const uint16_t w78 = Word(data, 78);
  const uint16_t w169 = Word(data, 169);
  if (w83 & 0x0008) AppendFeature(disk.features, "APM");
  if (w83 & 0x0200) AppendFeature(disk.features, "AAM");
  if (w76 & 0x0100) AppendFeature(disk.features, "NCQ");
  if (w169 & 0x0001) AppendFeature(disk.features, "TRIM");
  if (w78 & 0x0080) AppendFeature(disk.features, "DevSleep");
  if (w84 & 0x0010) AppendFeature(disk.features, "Streaming");
  if (w84 & 0x0020) AppendFeature(disk.features, "GPL");
  if (w82 & 0x0020) AppendFeature(disk.features, "VolatileWriteCache");

  disk.smartKey = disk.isSsd ? "SmartSsd" : "Smart";
  return !disk.model.empty();
}

bool FillAtaSmart(DiskInfo& disk, const uint8_t* smart, size_t smartLen,
                  const uint8_t* threshold, size_t thresholdLen,
                  const InterpretOptions& options) {
  if (smart == nullptr || smartLen < 512) {
    return false;
  }
  disk.attributes.clear();
  disk.temperature = -1;

  for (int i = 0; i < MAX_ATTRIBUTE; ++i) {
    const uint8_t* entry = smart + 2 + i * 12;
    if (entry[0] == 0) {
      continue;
    }
    SmartAttribute attr;
    attr.id = entry[0];
    attr.flags = entry[1];
    attr.current = entry[3];
    attr.worst = entry[4];
    std::memcpy(attr.raw, entry + 5, 6);
    if (threshold != nullptr && thresholdLen >= 512) {
      for (int j = 0; j < MAX_ATTRIBUTE; ++j) {
        const uint8_t* th = threshold + 2 + j * 12;
        if (th[0] == attr.id) {
          attr.threshold = th[1];
          break;
        }
      }
    }
    disk.attributes.push_back(attr);

    switch (attr.id) {
      case 0x09: {
        const uint32_t raw = B8toB32le(attr.raw);
        if (raw != 0xFFFFFFFF) {
          uint64_t minutes = 0;
          switch (disk.powerOnUnit) {
            case PowerOnUnit::Minutes: minutes = raw; break;
            case PowerOnUnit::HalfMinutes: minutes = raw / 2; break;
            case PowerOnUnit::Seconds: minutes = raw / 60; break;
            case PowerOnUnit::TenMinutes:
              minutes = static_cast<uint64_t>(raw) * 10;
              break;
            case PowerOnUnit::Milliseconds:
              minutes = static_cast<uint64_t>(raw) * 60;
              break;
            case PowerOnUnit::Hours:
            default:
              minutes = static_cast<uint64_t>(raw) * 60;
              break;
          }
          const uint64_t hours = minutes / 60;
          disk.powerOnHours = hours > 0xFFFFFFFFull
                                  ? 0xFFFFFFFFu
                                  : static_cast<uint32_t>(hours);
          disk.powerOnMinutes =
              static_cast<uint32_t>(minutes < 60 ? minutes : 60);
          disk.powerOnActive = raw > 0;
          disk.powerOnHoursKnown = true;
        }
        break;
      }
      case 0x0C:
        disk.powerOnCount = B8toB32le(attr.raw);
        break;
      case 0xBE:
        if (attr.raw[0] > 0 && attr.raw[0] < 100) {
          disk.temperature = attr.raw[0];
        }
        break;
      case 0xC2:
        if (attr.raw[0] > 0 && attr.raw[0] < 100) {
          disk.temperature = attr.raw[0];
        }
        break;
      case 0xF3:
        if (attr.raw[0] > 0 && attr.raw[0] < 100) {
          disk.temperature = attr.raw[0];
        }
        break;
      default:
        break;
    }
  }

  disk.smartAvailable = !disk.attributes.empty();
  FillLifeFromAttributes(disk);
  disk.health = EvaluateAtaHealth(disk, options);
  return disk.smartAvailable;
}

bool ParseNvmeIdentify(const uint8_t* data, size_t len, DiskInfo& disk) {
  if (data == nullptr || len < 72) {
    return false;
  }
  disk.bus = Bus::Nvme;
  disk.isNvme = true;
  disk.isSsd = true;
  disk.rotationRate = 0;
  disk.serial = NvmeString(data, 4, 20);
  disk.model = NvmeString(data, 24, 40);
  disk.firmware = NvmeString(data, 64, 8);
  disk.interfaceName = "NVMe";
  disk.smartKey = "SmartNVMe";

  if (len >= 312) {
    uint64_t total = 0;
    for (int i = 7; i >= 0; --i) {
      const uint8_t* field = data + 280 + i * 2;
      total = (total << 16) | B8toB16le(field);
    }
    if (total > 0) {
      disk.capacityBytes = total;
    }
  }
  return !disk.model.empty();
}

bool FillNvmeSmart(DiskInfo& disk, const uint8_t* log, size_t len,
                   const InterpretOptions& options) {
  if (log == nullptr || len < 200) {
    return false;
  }
  disk.attributes.clear();

  auto add = [&disk](uint8_t id, uint8_t current, uint8_t worst,
                     const uint8_t* raw, size_t rawLen) {
    SmartAttribute attr;
    attr.id = id;
    attr.current = current;
    attr.worst = worst;
    std::memcpy(attr.raw, raw, std::min<size_t>(rawLen, 6));
    disk.attributes.push_back(attr);
  };

  add(0x01, 0, 0, log + 0, 1);
  add(0x02, 0, 0, log + 1, 2);
  add(0x03, 0, 0, log + 3, 1);
  add(0x04, 0, 0, log + 4, 1);
  add(0x05, 0, 0, log + 5, 1);
  add(0x06, 0, 0, log + 32, 6);
  add(0x07, 0, 0, log + 48, 6);
  add(0x08, 0, 0, log + 64, 6);
  add(0x09, 0, 0, log + 80, 6);
  add(0x0A, 0, 0, log + 96, 6);
  add(0x0B, 0, 0, log + 112, 6);
  add(0x0C, 0, 0, log + 128, 6);
  add(0x0D, 0, 0, log + 144, 6);
  add(0x0E, 0, 0, log + 160, 6);
  add(0x0F, 0, 0, log + 176, 6);

  for (int i = 0; i < 8; ++i) {
    const uint8_t* sensor = log + 200 + i * 2;
    if (sensor[0] != 0 || sensor[1] != 0) {
      add(static_cast<uint8_t>(0x12 + i), 0, 0, sensor, 2);
    }
  }
  if (len >= 220) {
    for (int i = 0; i < 4; ++i) {
      add(static_cast<uint8_t>(0x1A + i), 0, 0, log + 216 + i * 4, 4);
    }
  }

  const uint16_t compositeKelvin = B8toB16le(log + 1);
  disk.temperature = compositeKelvin >= 273
                         ? static_cast<int32_t>(compositeKelvin) - 273
                         : -1;
  disk.life = log[5] <= 100 ? 100 - log[5] : -1;
  disk.powerOnHours = static_cast<uint32_t>(B8toB32le(log + 128));
  disk.powerOnCount = static_cast<uint32_t>(B8toB32le(log + 112));
  disk.smartAvailable = true;

  const int criticalWarning = log[0];
  const int spare = log[3];
  const int spareThreshold = log[4];
  if (criticalWarning > 0) {
    disk.health = Health::Bad;
  } else if (spareThreshold != 0 && spareThreshold <= 100 &&
             spare < spareThreshold) {
    disk.health = Health::Bad;
  } else if (spareThreshold != 0 && spareThreshold <= 100 &&
             spare == spareThreshold && spareThreshold != 100) {
    disk.health = Health::Caution;
  } else if (disk.life >= 0) {
    disk.health = disk.life > options.thresholdFF ? Health::Good
                                                  : Health::Caution;
  } else {
    disk.health = Health::Unknown;
  }
  return true;
}

std::string FormatRawHex(const SmartAttribute& attr) {
  char buffer[16] = {0};
  std::snprintf(buffer, sizeof(buffer), "%02X%02X%02X%02X%02X%02X",
                attr.raw[5], attr.raw[4], attr.raw[3], attr.raw[2],
                attr.raw[1], attr.raw[0]);
  return buffer;
}

std::string FormatRawDecimal(const SmartAttribute& attr) {
  return std::to_string(B8toB64le(attr.raw));
}

}  // namespace cdi
