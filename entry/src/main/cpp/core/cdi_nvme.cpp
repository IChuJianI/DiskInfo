#include "cdi_nvme.h"

#include <fcntl.h>
#include <linux/nvme_ioctl.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cerrno>
#include <cstdio>
#include <cstring>
#include <vector>

#include "cdi_interpret.h"
#include "cdi_json.h"

namespace cdi {

namespace {

constexpr int kIdentifySize = 4096;
constexpr int kSmartLogSize = 512;

std::string ReadSelinuxContext() {
  const int fd = open("/proc/self/attr/current", O_RDONLY | O_CLOEXEC);
  if (fd < 0) {
    return "";
  }
  char buffer[256] = {0};
  const ssize_t count = read(fd, buffer, sizeof(buffer) - 1);
  close(fd);
  if (count <= 0) {
    return "";
  }
  std::string out(buffer, static_cast<size_t>(count));
  while (!out.empty() && (out.back() == '\0' || out.back() == '\n')) {
    out.pop_back();
  }
  return out;
}

bool Readable(const char* path) {
  const int fd = open(path, O_RDONLY | O_CLOEXEC);
  if (fd < 0) {
    return false;
  }
  close(fd);
  return true;
}

bool NvmeAdmin(int fd, nvme_passthru_cmd& command) {
  return ioctl(fd, NVME_IOCTL_ADMIN_CMD, &command) == 0;
}

bool IdentifyController(int fd, std::vector<uint8_t>& buffer) {
  buffer.assign(kIdentifySize, 0);
  nvme_passthru_cmd command{};
  command.opcode = 0x06;
  command.nsid = 0;
  command.addr = reinterpret_cast<__u64>(buffer.data());
  command.data_len = kIdentifySize;
  command.cdw10 = 1;
  command.timeout_ms = 5000;
  return NvmeAdmin(fd, command);
}

bool IdentifyNamespace(int fd, uint32_t nsid, std::vector<uint8_t>& buffer) {
  buffer.assign(kIdentifySize, 0);
  nvme_passthru_cmd command{};
  command.opcode = 0x06;
  command.nsid = nsid;
  command.addr = reinterpret_cast<__u64>(buffer.data());
  command.data_len = kIdentifySize;
  command.cdw10 = 0;
  command.timeout_ms = 5000;
  return NvmeAdmin(fd, command);
}

bool ReadSmartLog(int fd, std::vector<uint8_t>& buffer) {
  buffer.assign(kSmartLogSize, 0);
  nvme_passthru_cmd command{};
  command.opcode = 0x02;
  command.nsid = 0xFFFFFFFFu;
  command.addr = reinterpret_cast<__u64>(buffer.data());
  command.data_len = kSmartLogSize;
  command.cdw10 = (127u << 16) | 0x02u;
  command.timeout_ms = 5000;
  return NvmeAdmin(fd, command);
}

uint64_t NamespaceCapacity(const std::vector<uint8_t>& ns) {
  if (ns.size() < 132) {
    return 0;
  }
  uint64_t nsze = 0;
  for (int i = 7; i >= 0; --i) {
    nsze = (nsze << 8) | ns[static_cast<size_t>(i)];
  }
  const uint8_t lbads = ns[130];
  if (lbads < 9 || lbads > 16) {
    return 0;
  }
  return nsze << lbads;
}

}  // namespace

std::string ProbeJson() {
  std::string out = "{";
  out += "\"uid\":" + std::to_string(static_cast<long long>(getuid())) + ",";
  out += "\"euid\":" + std::to_string(static_cast<long long>(geteuid())) + ",";
  out += "\"selinux\":\"" + JsonEscape(ReadSelinuxContext()) + "\",";
  out += "\"procPartitions\":" +
         std::string(Readable("/proc/partitions") ? "true" : "false") + ",";
  out += "\"sysClassNvme\":" +
         std::string(Readable("/sys/class/nvme") ? "true" : "false") + ",";
  out += "\"nodes\":[";

  bool first = true;
  for (int index = 0; index < 16; ++index) {
    char node[32] = {0};
    std::snprintf(node, sizeof(node), "/dev/nvme%d", index);
    struct stat info {};
    const int statResult = stat(node, &info);
    if (statResult != 0 && errno == ENOENT) {
      continue;
    }
    const int fd = open(node, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    const int openError = fd < 0 ? errno : 0;
    if (fd >= 0) {
      close(fd);
    }
    if (!first) {
      out += ",";
    }
    first = false;
    out += "{\"path\":\"" + std::string(node) + "\",\"present\":true,";
    out += "\"open\":" + std::string(openError == 0 ? "true" : "false") + ",";
    out += "\"errno\":" + std::to_string(openError) + ",";
    out += "\"error\":\"" +
           JsonEscape(openError == 0 ? "" : std::strerror(openError)) + "\"}";
  }
  out += "],\"detail\":\"";
  out += JsonEscape(
      "App sandbox: block devices are guarded by SELinux; privileged NVMe "
      "passthrough only works when the process domain allows it.");
  out += "\"}";
  return out;
}

std::vector<DiskInfo> ScanNvmePrivileged(std::string& error,
                                         const InterpretOptions& options) {
  std::vector<DiskInfo> disks;
  std::string errors;

  for (int index = 0; index < 16; ++index) {
    char node[32] = {0};
    std::snprintf(node, sizeof(node), "/dev/nvme%d", index);
    const int fd = open(node, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if (fd < 0) {
      if (errno != ENOENT) {
        if (!errors.empty()) {
          errors += "; ";
        }
        errors += std::string(node) + ": " + std::strerror(errno);
      }
      continue;
    }

    std::vector<uint8_t> identify;
    if (!IdentifyController(fd, identify)) {
      if (!errors.empty()) {
        errors += "; ";
      }
      errors += std::string(node) + ": NVMe Identify Controller failed";
      close(fd);
      continue;
    }

    DiskInfo disk;
    disk.node = node;
    ParseNvmeIdentify(identify.data(), identify.size(), disk);
    disk.note = "NVMe admin passthrough";

    std::vector<uint8_t> namespaceData;
    if (IdentifyNamespace(fd, 1, namespaceData) && disk.capacityBytes == 0) {
      disk.capacityBytes = NamespaceCapacity(namespaceData);
    }

    std::vector<uint8_t> smart;
    if (ReadSmartLog(fd, smart)) {
      FillNvmeSmart(disk, smart.data(), smart.size(), options);
    } else {
      disk.smartAvailable = false;
      disk.note += "; SMART/Health log unavailable";
    }
    close(fd);
    disks.push_back(disk);
  }

  error = errors;
  return disks;
}

}  // namespace cdi
