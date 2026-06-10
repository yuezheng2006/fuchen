# 🔒 多次授权问题分析

## 🐛 问题描述

**现象**：点击"正式清理"或"优化"时，授权对话框打开多次

---

## 🔍 原因分析

### 1. Mole CLI 的行为

Mole CLI 在清理系统级文件时，会对**每个需要权限的操作**单独请求授权：

```bash
sudo mo clean
# 可能触发：
# - 清理 /Library/Caches/ → 授权1
# - 清理 /System/Library/Caches/ → 授权2
# - 清理 /var/log/ → 授权3
# ...
```

### 2. 拂尘的授权方式

当前拂尘使用 `osascript` + `do shell script ... with administrator privileges`：

```swift
private func runElevated(mo: String, args: [String]) {
    let script = "do shell script \"\(mo) \(args.joined(separator: " "))\" with administrator privileges"
    // 执行 osascript -e script
}
```

**问题**：
- `do shell script` 只在**开始时**授权一次
- 但 Mole CLI 内部可能通过其他方式触发多次授权
- 如果 Mole 内部调用了多个 `sudo` 命令，每个都会提示

---

## 🧪 验证方法

### 测试1：直接运行 Mole CLI
```bash
# 在终端运行
sudo mo clean

# 观察：
# - 是否只授权1次？
# - 还是多次？
```

### 测试2：使用 do shell script
```bash
# 在终端运行
osascript -e 'do shell script "mo clean" with administrator privileges'

# 观察授权次数
```

---

## 💡 可能的解决方案

### 方案1：使用 sudo 缓存（临时方案）
```swift
// 在 runElevated 前先运行一次 sudo -v
let script = """
do shell script "sudo -v && mo \(args.joined(separator: " "))" 
with administrator privileges
"""
```

**优点**：可能减少授权次数  
**缺点**：不够优雅，可能不工作

---

### 方案2：安装 Privileged Helper Tool（复杂）
```swift
// 使用 SMJobBless 安装 helper tool
// helper tool 以 root 权限常驻
// 只需授权一次安装
```

**优点**：最佳用户体验，授权1次  
**缺点**：
- 实现复杂（需要 XPC 通信）
- 需要代码签名
- 用户需要安装额外组件

---

### 方案3：等待 Mole CLI 优化（推荐）
如果问题出在 Mole CLI 本身，最好的方案是：
- 向 Mole 项目报告问题
- 等待 Mole 优化授权逻辑
- 拂尘无需修改

---

### 方案4：改进授权提示（用户体验）
虽然无法减少授权次数，但可以改进提示：

```swift
let alert = NSAlert()
alert.messageText = "清理系统文件需要授权"
alert.informativeText = """
清理过程中可能需要多次授权（这是 Mole CLI 的行为）。
每次授权都是为了访问不同的系统目录。

• /Library/Caches/
• /System/Library/Caches/
• /var/log/
... 等
"""
```

---

## 🔬 深入调查

### 检查 Mole CLI 源码

查看 Mole 如何实现清理：
- 是否使用多个 `sudo` 命令？
- 是否可以优化为一次授权？

### 测试不同场景

1. **只清理用户文件**（不需要 sudo）
   ```bash
   mo clean --dry-run  # 看看哪些需要 sudo
   ```

2. **清理系统文件**（需要 sudo）
   ```bash
   sudo mo clean
   ```

---

## 📝 临时缓解措施

### 在 UI 中说明

在确认对话框中告知用户：

```swift
alert.informativeText = """
拂尘将以管理员权限运行清理命令。

⚠️ 清理系统缓存时，可能需要授权2-3次
（这是系统安全机制，确保访问不同目录时都获得授权）

缓存文件将被永久删除，但安全规则仍然生效。
"""
```

---

## 🎯 推荐行动

### 短期（立即）
1. ✅ 更新确认对话框文案，告知用户可能多次授权
2. ✅ 添加说明：这是正常行为

### 中期（v0.0.2）
1. 调查 Mole CLI 授权逻辑
2. 向 Mole 项目反馈
3. 考虑是否需要 privileged helper tool

### 长期（v0.1.0+）
1. 如果 Mole 未优化，实现 privileged helper tool
2. 或者，只清理用户级文件（不需要 sudo）

---

## 💭 结论

**多次授权可能是 Mole CLI 的行为，不是拂尘的 bug。**

**当前最佳方案**：
- 在 UI 中明确告知用户
- 说明这是系统安全机制
- 等待 Mole CLI 优化

**是否需要立即修复**：
- 如果影响用户体验 → 更新 UI 提示
- 如果是 Mole 的问题 → 无法在拂尘层面修复
