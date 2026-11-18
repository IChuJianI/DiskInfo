// Portions derived from CrystalDiskInfo (https://github.com/hiyohiyo/CrystalDiskInfo),
// Copyright (c) 2008-2023 hiyohiyo. Licensed under the MIT License.
#ifndef DISKINFO_CDI_INTERPRET_H
#define DISKINFO_CDI_INTERPRET_H

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#include "cdi_types.h"

namespace cdi {

bool ParseAtaIdentify(const uint8_t* data, size_t len, DiskInfo& disk);
bool FillAtaSmart(DiskInfo& disk, const uint8_t* smart, size_t smartLen,
                  const uint8_t* threshold, size_t thresholdLen,
                  const InterpretOptions& options);
bool ParseNvmeIdentify(const uint8_t* data, size_t len, DiskInfo& disk);
bool FillNvmeSmart(DiskInfo& disk, const uint8_t* log, size_t len,
                   const InterpretOptions& options);

std::string FormatRawHex(const SmartAttribute& attr);
std::string FormatRawDecimal(const SmartAttribute& attr);

}  // namespace cdi

#endif
