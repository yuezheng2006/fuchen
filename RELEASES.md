# Burrow 0.5.1 — 图标修复 + 签名流程

## 本版变更
- **修复 Dock / Finder 图标**：Release 构建现正确嵌入 `AppIcon.icns`（此前 swiftc 打包只有 xcassets 目录，系统不显示图标）
- **签名/公证脚本**：`scripts/sign-and-notarize.sh` + `docs/SIGNING.md`，配置 Developer ID 后用户无需 `xattr -cr`

## 安装（未公证构建）
若 Release 尚未公证，首次打开仍需右键 → 打开。公证版将直接双击可用。

## 系统要求
- macOS 14+
- `brew install mole`
