#include "cdi_json.h"

#include <cstdio>

namespace cdi {

namespace {

const char* BusName(Bus bus) {
  switch (bus) {
    case Bus::Ata: return "ata";
    case Bus::Nvme: return "nvme";
    case Bus::Usb: return "usb";
    default: return "unknown";
  }
}

void AppendString(std::string& out, const char* key, const std::string& value,
                  bool comma = true) {
  out += "\"";
  out += key;
  out += "\":\"";
  out += JsonEscape(value);
  out += "\"";
  if (comma) {
    out += ",";
  }
}

void AppendNumber(std::string& out, const char* key, long long value,
                  bool comma = true) {
  out += "\"";
  out += key;
  out += "\":";
  out += std::to_string(value);
  if (comma) {
    out += ",";
  }
}

void AppendBool(std::string& out, const char* key, bool value,
                bool comma = true) {
  out += "\"";
  out += key;
  out += "\":";
  out += value ? "true" : "false";
  if (comma) {
    out += ",";
  }
}

}  // namespace

std::string JsonEscape(const std::string& text) {
  std::string out;
  out.reserve(text.size() + 8);
  for (unsigned char c : text) {
    switch (c) {
      case '"': out += "\\\""; break;
      case '\\': out += "\\\\"; break;
      case '\b': out += "\\b"; break;
      case '\f': out += "\\f"; break;
      case '\n': out += "\\n"; break;
      case '\r': out += "\\r"; break;
      case '\t': out += "\\t"; break;
      default:
        if (c < 0x20) {
          char buffer[8] = {0};
          std::snprintf(buffer, sizeof(buffer), "\\u%04X", c);
          out += buffer;
        } else {
          out += static_cast<char>(c);
        }
        break;
    }
  }
  return out;
}

std::string DiskToJson(const DiskInfo& disk) {
  std::string out = "{";
  AppendString(out, "node", disk.node);

  std::string numbers;
  AppendString(numbers, "model", disk.model);
  AppendString(numbers, "serial", disk.serial);
  AppendString(numbers, "firmware", disk.firmware);
  AppendString(numbers, "interface", disk.interfaceName);
  AppendString(numbers, "transferMode", disk.transferMode);
  AppendString(numbers, "formFactor", disk.formFactor);
  AppendString(numbers, "features", disk.features);
  AppendString(numbers, "smartKey", disk.smartKey);
  AppendString(numbers, "note", disk.note);
  AppendNumber(numbers, "capacityBytes",
               static_cast<long long>(disk.capacityBytes));
  AppendNumber(numbers, "rotationRate", disk.rotationRate);
  AppendBool(numbers, "rotationRateEstimated", disk.rotationRateEstimated);
  AppendNumber(numbers, "powerOnHours", disk.powerOnHours);
  AppendNumber(numbers, "powerOnMinutes", disk.powerOnMinutes);
  AppendNumber(numbers, "powerOnCount", disk.powerOnCount);
  AppendNumber(numbers, "temperature", disk.temperature);
  AppendNumber(numbers, "life", disk.life);
  AppendBool(numbers, "lifeEstimated", disk.lifeEstimated);
  AppendBool(numbers, "powerOnHoursKnown", disk.powerOnHoursKnown);
  AppendBool(numbers, "powerOnActive", disk.powerOnActive);
  AppendNumber(numbers, "health", static_cast<int>(disk.health));
  AppendString(numbers, "bus", BusName(disk.bus));
  AppendBool(numbers, "isSsd", disk.isSsd);
  AppendBool(numbers, "isNvme", disk.isNvme);
  AppendBool(numbers, "smartAvailable", disk.smartAvailable);

  out += numbers;
  out += "\"attributes\":[";
  for (size_t i = 0; i < disk.attributes.size(); ++i) {
    const SmartAttribute& attr = disk.attributes[i];
    if (i != 0) {
      out += ",";
    }
    out += "{\"id\":";
    out += std::to_string(attr.id);
    out += ",\"current\":";
    out += std::to_string(attr.current);
    out += ",\"worst\":";
    out += std::to_string(attr.worst);
    out += ",\"threshold\":";
    out += std::to_string(attr.threshold);
    out += ",\"flags\":";
    out += std::to_string(attr.flags);
    out += ",\"raw\":[";
    for (int j = 0; j < 6; ++j) {
      if (j != 0) {
        out += ",";
      }
      out += std::to_string(attr.raw[j]);
    }
    out += "]}";
  }
  out += "]}";
  return out;
}

std::string DisksToJson(const std::vector<DiskInfo>& disks,
                        const std::string& error) {
  std::string out = "{\"disks\":[";
  for (size_t i = 0; i < disks.size(); ++i) {
    if (i != 0) {
      out += ",";
    }
    out += DiskToJson(disks[i]);
  }
  out += "],\"error\":\"";
  out += JsonEscape(error);
  out += "\"}";
  return out;
}

}  // namespace cdi
