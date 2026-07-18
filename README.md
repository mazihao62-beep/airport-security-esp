# 🛡️ 机场安全透视脚本 (Airport Security ESP)

> 基于 **WindUI** 库构建的 Roblox 机场安全类游戏透视脚本

[![WindUI](https://img.shields.io/badge/UI-WindUI-30ff6a)](https://footagesus.github.io/WindUI-Docs/docs)

## ✨ 功能特点

| 功能 | 说明 |
|------|------|
| 🎨 **WindUI 现代界面** | 精美UI，10+主题切换，Mac/Default风格按钮 |
| 👁 **ESP透视** | 穿墙高亮 + 头顶名称标签，AlwaysOnTop |
| 🟢 **好人绿色标记** | Agent/Police/Guard → "👮 Agent" |
| 🔴 **坏人红色标记** | NPC/Terrorist/Suspect → "💀 Threat" |
| 📏 **距离显示** | 实时显示距离（米） |
| ❤️ **血量显示** | HP: 120/120 格式 |
| 📊 **实时统计** | 坏人/好人计数面板 + 调试信息 |
| 🔑 **自定义快捷键** | 所有快捷键可自由设置 |

## 🚀 使用方法

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/mazihao62-beep/airport-security-esp/main/airport_esp.lua"))()
```

### 首次使用流程

```
1️⃣ 执行脚本 → Popup弹窗确认
2️⃣ 点击「确认加载」
3️⃣ 点击绿色悬浮按钮打开菜单
4️⃣ 在「UI设置」中绑定窗口快捷键
5️⃣ 在「功能设置」中绑定透视快捷键
6️⃣ NPC自动识别 + 高亮显示 ✅
```

> ⚠️ **注意**: v5.0 起**无默认快捷键**，请务必在UI中自行设置！

## 🔍 识别机制

1. **路径检测** — 检查是否在 `AgentTemplate` / `NPCTemplate` 下
2. **名称匹配** — 根据名字前缀判断（坏人优先，避免误判）
3. **Descendant扫描** — 查找模块脚本中的模板标识

## 🖥️ UI 结构

| Tab | 内容 |
|-----|------|
| **主控面板** | 透视开关 / 仅显示坏人 / 距离血量选项 / 探测距离滑块 |
| **功能设置** | 透视快捷键 / 仅坏人快捷键 / 使用说明 |
| **UI设置** | 窗口开关快捷键 / 悬浮按钮开关 |
| **信息统计** | 好人/坏人/未知/总计计数 + 调试信息 |
| **关于** | 版本信息 / 使用说明 |

## 🎨 WindUI 主题

内置主题：Dark, Light, Rose, Plant, Indigo, Sky, Violet, Amber, Emerald, Midnight, Crimson, Monokai Pro, Cotton Candy

## 📁 文件结构

```
airport-security-esp/
├── airport_esp.lua   # 主脚本（WindUI版）
└── README.md         # 说明文档
```

## 🔗 相关链接

- [WindUI 文档](https://footagesus.github.io/WindUI-Docs/docs)
- [WindUI GitHub](https://github.com/Footagesus/WindUI)
