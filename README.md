# 🛡️ 机场安全透视脚本 v6.0

> 基于 **WindUI** 库构建的 Roblox 机场安全类游戏透视脚本
> **作者: b站英吉利超入_**

[![WindUI](https://img.shields.io/badge/UI-WindUI-30ff6a)](https://footagesus.github.io/WindUI-Docs/docs)

## ✨ 功能特点

| 功能 | 说明 |
|------|------|
| 🎨 **WindUI 现代界面** | 精美UI，5个功能Tab |
| 👁 **ESP透视** | 穿墙高亮 + 头顶中文标签 |
| 🟢 **好人绿色标记** | 👮 好人 |
| 🔴 **坏人红色标记** | 💀 坏人 |
| 📏 **距离显示** | 实时显示距离（米） |
| ❤️ **血量显示** | HP: 120/120 格式 |
| 📊 **实时统计** | 好人/坏人计数面板 |
| 🔑 **自定义快捷键** | 所有快捷键可自由设置 |
| 📱 **手机适配** | 悬浮按钮 + 自适应布局 |

## 🚀 使用方法

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/mazihao62-beep/airport-security-esp/main/airport_esp.lua"))()
```

### 首次使用流程

```
1️⃣ 执行脚本 → Popup弹窗确认
2️⃣ 点击「确认加载」
3️⃣ 按 RightShift 打开菜单
4️⃣ 在「功能设置」中绑定透视快捷键
5️⃣ NPC自动识别 + 高亮显示 ✅
```

> ⚠️ **v6.0** 起窗口快捷键默认 RightShift，其他快捷键无默认值

## 🔍 NPC分类机制 (v6.0 修复)

| 优先级 | 检测方式 | 示例 |
|--------|---------|------|
| 第1层 | **中文名字** | "警察""保安" → 好人 / "恐怖""匪徒" → 坏人 |
| 第2层 | **英文名字** | "Police""Guard" → 好人 / "Terrorist""Enemy" → 坏人 |
| 第3层 | **NPCType 属性** | Agent → 好人 / Enemy → 坏人 (源码NPCSetup.lua) |
| 第4层 | **路径检测** | AgentTemplate → 好人 / NPCTemplate → 坏人 |
| 保底 | **默认坏人** | 无法判断时宁可错杀 |

## 🖥️ UI 结构

| Tab | 内容 |
|-----|------|
| **主控面板** | 透视开关 / 仅显示坏人 / 距离血量 / 探测距离滑块 |
| **功能设置** | 透视快捷键 / 仅坏人快捷键 / 使用说明 |
| **UI设置** | 窗口快捷键 / 悬浮按钮开关 |
| **信息统计** | 好人/坏人/总计 + 调试信息 |
| **关于** | 作者信息 / 使用说明 |

## 📁 文件结构

```
airport-security-esp/
├── airport_esp.lua   # 主脚本
└── README.md         # 说明文档
```

## 🔗 相关链接

- [WindUI 文档](https://footagesus.github.io/WindUI-Docs/docs)
- [WindUI GitHub](https://github.com/Footagesus/WindUI)
