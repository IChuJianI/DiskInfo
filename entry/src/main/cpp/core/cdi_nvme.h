#ifndef DISKINFO_CDI_NVME_H
#define DISKINFO_CDI_NVME_H

#include <string>
#include <vector>

#include "cdi_types.h"

namespace cdi {

std::string ProbeJson();
std::vector<DiskInfo> ScanNvmePrivileged(std::string& error,
                                         const InterpretOptions& options);

}  // namespace cdi

#endif
