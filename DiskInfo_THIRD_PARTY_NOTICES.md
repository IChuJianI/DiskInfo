# DiskInfo 第三方组件补充声明

本应用是 CrystalDiskInfo 的 HarmonyOS 移植版本，内嵌其 SMART 解析引擎。上游 CrystalDiskInfo 的许可全文（MIT）已随本应用一并分发；本文件仅补充列出实际编译进本应用的组件、内嵌资源与新增代码，不改变上游许可条款。

## 一、CrystalDiskInfo 派生组件

ATA / NVMe SMART 属性解析（entry/src/main/cpp/core/cdi_interpret.*、cdi_types.h）— MIT — Copyright (c) 2008-2023 hiyohiyo
SMART 属性名称数据（entry/src/main/resources/rawfile/smart/*.json，取自 CrystalDiskInfo 语言文件）— MIT — Copyright (c) 2008-2023 hiyohiyo

## 二、本项目新增

ArkTS 界面、设置与本地化（entry/src/main/ets）— MIT — Copyright (c) 2026 李晨
USB 大容量存储传输：BOT / SCSI / ATA 透传（entry/src/main/ets/service/UsbAtaTransport.ets、UsbDiskProbe.ets）— MIT — Copyright (c) 2026 李晨
SMART 结果序列化（entry/src/main/cpp/core/cdi_json.*）— MIT — Copyright (c) 2026 李晨
N-API 封装与构建脚本（entry/src/main/cpp/napi_init.cpp、CMakeLists.txt）— MIT — Copyright (c) 2026 李晨
应用图标与界面素材 — Copyright (c) 2026 李晨

## 三、许可全文

CrystalDiskInfo 组件与本项目新增代码均采用 MIT 许可；上游许可全文见应用内「MIT License」及随应用分发的许可文件，本项目许可全文见应用内「DiskInfo License」及仓库根目录的 LICENSE。
