# LiteVPN

[English](README.md) | **简体中文**

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-green.svg)
![Swift](https://img.shields.io/badge/Swift-5-orange.svg)
![License GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-lightgray.svg)

极简的 **macOS OpenVPN 菜单栏客户端**. 为替代笨重的 OpenVPN Connect 而生: 点开即用, 常驻轻量, 没有账户系统, 没有推送, 没有更新弹窗.

全栈 Swift, 协议引擎使用 [TunnelKit](https://github.com/partout-io/tunnelkit) —— 纯 Swift 实现的 OpenVPN 协议, 开源客户端 Passepartout 的同款引擎.

<p align="center"><img src="docs/screenshot-zh.png" width="560" alt="LiteVPN 菜单栏面板 (连接状态)"></p>

## 功能

- **菜单栏常驻** (无 Dock 图标), 一键连接 / 断开
- **导入 .ovpn**: 拖拽进面板或文件选择器, 导入时即时解析校验, 多配置切换
- **实时状态**: 连接时长, 上下行流量
- **Clash 兼容模式**: 不接管默认路由, 与 Clash TUN / 系统代理分流共存 (见下文)
- **断线自动重连** (TunnelKit 内置), **开机启动** (可选)
- 隧道运行在独立的 Network Extension 进程中, 主应用退出后连接照常保持
- 界面双语: English / 简体中文 (跟随系统语言)
- Supabase 风格的亮色界面

刻意的减法: 仅支持证书内嵌 (`<ca>` / `<cert>` / `<key>` inline) 的标准配置, 不支持用户名密码认证.

## 与 Clash 共存

VPN 客户端与 Clash 的冲突本质是**路由权之争**. LiteVPN 的「Clash 兼容模式」打开后:

- LiteVPN 不接管默认路由, 只认领配置文件与服务器推送的具体网段 (如 `10.0.0.0/8`)
- 命中 VPN 网段的流量走 OpenVPN 隧道, 其余流量照常走 Clash (TUN 模式或系统代理均可)
- 路由表按"更具体的网段优先"自动裁决, 两张虚拟网卡互不抢地盘

建议的 Clash 侧配合:

```yaml
rules:
  - IP-CIDR,<你的VPN服务器IP>/32,DIRECT   # 避免 VPN 握手流量绕道代理
```

若需通过域名访问 VPN 内网服务, 将相关域名加入 Clash 的 `fake-ip-filter`.

## 架构

```
┌─────────────────────────┐      ┌──────────────────────────────┐
│ LiteVPN.app (菜单栏)     │      │ LiteVPNTunnel.appex          │
│ SwiftUI MenuBarExtra    │─────▶│ NEPacketTunnelProvider       │
│ NetworkExtensionVPN     │ NE   │ └─ TunnelKit OpenVPN 引擎    │
│ 配置管理 / 状态 / 流量    │◀─────│    (协议 + 数据通道)          │
└─────────────────────────┘ AppGroup └──────────────────────────┘
```

- 协议引擎与应用的接触面被刻意压到最小 (隧道子类 + 解析 + 连接管理三处), 为未来切换 WireGuard 留好接口
- TunnelKit v6.3.2 已 vendor 至 `Vendor/tunnelkit/` 并剥离 WireGuard 部分 (上游仓库已归档, 其依赖的 wireguard-apple 仓库已被删除, 远端引用不再可靠), 修改声明见 [Vendor/tunnelkit/LITEVPN-MODIFICATIONS.md](Vendor/tunnelkit/LITEVPN-MODIFICATIONS.md)
- 加密层通过 `.upToNextMinor` 锁定在 OpenSSL **3.5 LTS** 线 (维护期至 2030 年 4 月), 依赖解析只会升 3.5.x 内的 patch 版本, 不会漂移到短维护期的版本线

## 构建

依赖: Xcode (完整版), [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), 付费 Apple 开发者账号 (Network Extension 能力需要).

1. **改成你自己的签名信息** (两处):
   - `project.yml` → `DEVELOPMENT_TEAM` 改为你的 Team ID
   - `App/AppConstants.swift` → `appGroup` 的 Team ID 前缀同步修改
2. 生成工程并构建:

```bash
xcodegen generate
open LiteVPN.xcodeproj   # 在 Xcode 中直接 Run, 自动签名会生成所需描述文件
```

或命令行构建:

```bash
xcodebuild -project LiteVPN.xcodeproj -scheme LiteVPN \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
```

首次连接时 macOS 会弹出"LiteVPN 想要添加 VPN 配置"的系统确认, 允许一次即可.

> **不提供预编译包.** macOS Network Extension 应用无法以"任意 Mac 下载即用"的形式分发 (需逐机签名), 因此请用自己的开发者账号从源码构建 (约 5 分钟).

## 使用

1. 点击菜单栏盾牌图标
2. 拖入 `.ovpn` 文件 (或点「+ 导入」)
3. 点「连接」

## 致谢

- [TunnelKit](https://github.com/partout-io/tunnelkit) by Davide De Rosa —— OpenVPN 协议引擎
- [OpenSSL](https://github.com/partout-io/openssl-apple) —— 加密层 (3.5 LTS)

## 许可证

[GPL-3.0](LICENSE) (协议引擎 TunnelKit 为 GPL-3.0, 本项目随之采用).

## 作者

云中江树 · 微信公众号: 云中江树
