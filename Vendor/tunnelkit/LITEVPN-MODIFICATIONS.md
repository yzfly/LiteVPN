# LiteVPN 对 TunnelKit 的修改声明

本目录是 [TunnelKit](https://github.com/partout-io/tunnelkit) v6.3.2
(commit `f2c0fb079e2a318a4717d5fb8daa8f149174dadd`) 的本地副本,
原作者 Davide De Rosa, 许可证 GPL-3.0 (见本目录 LICENSE).

依照 GPL-3.0 第 5 条, 声明 LiteVPN 所做的修改 (2026-06-12):

1. 重写 `Package.swift`: 移除 WireGuard 相关 products 与 targets,
   并移除对 `wireguard-apple` 仓库的依赖 (该仓库已被上游删除, 无法解析);
   `openssl-apple` 依赖地址更新为迁移后的 `partout-io/openssl-apple`.
2. 删除 `Sources/TunnelKitWireGuard*` 目录 (LiteVPN 仅使用 OpenVPN).
3. 删除 `Package.resolved`.

除上述外, 其余源代码与上游 v6.3.2 完全一致.
