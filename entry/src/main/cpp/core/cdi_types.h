// Portions derived from CrystalDiskInfo (https://github.com/hiyohiyo/CrystalDiskInfo),
// Copyright (c) 2008-2023 hiyohiyo. Licensed under the MIT License.
#ifndef DISKINFO_CDI_TYPES_H
#define DISKINFO_CDI_TYPES_H

#include <cstdint>
#include <string>
#include <vector>

namespace cdi {

constexpr int MAX_ATTRIBUTE = 30;

enum class Health : int {
  Unknown = 0,
  Good = 1,
  Caution = 2,
  Bad = 3,
};

enum class Bus : int {
  Unknown = 0,
  Ata = 1,
  Nvme = 2,
  Usb = 3,
};

// CrystalDiskInfo's POWER_ON_HOURS_UNIT: the unit a drive uses for SMART
// attribute 0x09. Most drives count hours, but several model families count
// minutes or half-minutes.
enum class PowerOnUnit : int {
  Hours = 0,
  Minutes = 1,
  HalfMinutes = 2,
  Seconds = 3,
  TenMinutes = 4,
  Milliseconds = 5,
};

struct SmartAttribute {
  uint8_t id = 0;
  uint8_t current = 0;
  uint8_t worst = 0;
  uint8_t threshold = 0;
  uint8_t raw[6] = {0, 0, 0, 0, 0, 0};
  uint8_t flags = 0;
};

struct DiskInfo {
  std::string node;
  std::string model;
  std::string serial;
  std::string firmware;
  std::string interfaceName;
  std::string transferMode;
  std::string formFactor;
  std::string features;
  std::string smartKey = "Smart";
  std::string note;

  uint64_t capacityBytes = 0;
  uint32_t rotationRate = 0;
  bool rotationRateEstimated = false;
  uint32_t powerOnHours = 0;
  // Minutes of power-on time when the total is under one hour, so the UI can
  // show sub-hour precision instead of a misleading rounded hour.
  uint32_t powerOnMinutes = 0;
  uint32_t powerOnCount = 0;
  uint32_t nvmeSensors = 0;
  PowerOnUnit powerOnUnit = PowerOnUnit::Hours;
  int32_t temperature = -1;
  int32_t life = -1;
  bool lifeEstimated = false;
  bool powerOnHoursKnown = false;
  bool powerOnActive = false;

  Health health = Health::Unknown;
  Bus bus = Bus::Unknown;
  bool isSsd = false;
  bool isNvme = false;
  bool smartAvailable = false;

  std::vector<SmartAttribute> attributes;
};

struct InterpretOptions {
  uint16_t threshold05 = 1;
  uint16_t thresholdC5 = 1;
  uint16_t thresholdC6 = 1;
  uint16_t thresholdFF = 10;
};

uint32_t B8toB32le(const uint8_t* b);
uint64_t B8toB64le(const uint8_t* b);
uint16_t B8toB16le(const uint8_t* b);
int32_t B8toINTle(const uint8_t* b);

}  // namespace cdi

#endif
