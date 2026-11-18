#ifndef DISKINFO_CDI_JSON_H
#define DISKINFO_CDI_JSON_H

#include <string>
#include <vector>

#include "cdi_types.h"

namespace cdi {

std::string JsonEscape(const std::string& text);
std::string DiskToJson(const DiskInfo& disk);
std::string DisksToJson(const std::vector<DiskInfo>& disks, const std::string& error);

}  // namespace cdi

#endif
