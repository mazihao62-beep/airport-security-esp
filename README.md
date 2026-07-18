# 🛡️ 机场安全透视脚本 (Airport Security ESP)

> 基于 **WindUI** 库构建的 Roblox 机场安全类游戏透视脚本

[![WindUI](https://img.shields.io/badge/UI-WindUI-30ff6a)](https://footagesus.github.io/WindUI-Docs/docs)

## ✨ 功能特点

| 功能 | 说明 |
|------|------|
| 🎨 **WindUI 现代界面** | 精美 UI，支持10+主题切换，Mac风格按钮 |
| 👁 **ESP透视** | 穿墙方框，AlwaysOnTop |
| 🟢 **好人绿色标记** | Agent/Police/Guard → "👮 Agent" |
| 🔴 **坏人红色标记** | NPC/Terrorist/Suspect → "💀 Threat" |
| 📏 **距离显示** | 实时显示距离（米） |
| ❤️ **血量显示** | HP: 120/120 格式 |
| 📊 **实时统计** | 坏人/好人计数面板 |
| 📱 **悬浮按钮** | 手机适配 |

## 🎮 快捷键

| 按键 | 功能 |
|------|------|
| **RightShift** | 开关WindUI菜单 |
| **F4** | 开关ESP透视 |

## 📦 安装

1. 打开 Roblox 游戏
2. 注入你的执行器
3. 复制 `airport_esp.lua` 完整代码并执行

## 🔍 识别机制（三重判断）

1. **父级路径** — 检查是否在 `AgentTemplate` / `NPCTemplate` 下
2. **名称匹配** — 根据名字前缀判断
3. **Descendant扫描** — 查找模块脚本中的模板标识

## ⚙️ WindUI 配置

窗口内置10+主题，可在设置中切换：
- Dark, Light, Rose, Plant, Indigo, Sky, Violet, Amber 等

## 📁 文件结构

```
airport-security-esp/
├── airport_esp.lua   # 主脚本（WindUI版）
└── README.md         # 说明文档
```

## 🔗 相关链接

- [WindUI 文档](https://footagesus.github.io/WindUI-Docs/docs)
- [WindUI GitHub](https://github.com/Footagesus/WindUI)
