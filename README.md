# 🛡️ 机场安全透视脚本 (Airport Security ESP)

> 适用于 Roblox 机场安全类游戏

## ✨ 功能特点

| 功能 | 说明 |
|------|------|
| 👁 **透视ESP** | 穿墙看到所有角色位置 |
| ✅ **好人绿色标记** | Agent = 警察/安保人员，显示绿色 |
| ❌ **坏人红色标记** | NPC Template = 恐怖分子，显示红色 |
| 📏 **距离显示** | 显示距离和血量信息 |
| 🎨 **彩虹边框UI** | 悬浮窗可拖拽 |

## 🎮 热键控制

| 按键 | 功能 |
|------|------|
| **F4** | 开关ESP透视 |
| **F5** | 切换仅显示坏人模式 |

## 🔍 识别机制

脚本通过以下方式区分好人与坏人：

1. **路径检测** — 检查父级是否包含 `AgentTemplate` 或 `NPCTemplate`
2. **名称识别** — 根据名字前缀判断（Agent/Police/Guard = 好人, NPC/Terrorist/Suspect = 坏人）
3. **模块检测** — 检查Descendant中是否存在模板标识

## 🚀 使用方法

1. 打开 Roblox 游戏
2. 注入你的执行器
3. 复制 `airport_esp.lua` 完整代码并执行

## 📁 文件结构

```
airport-security-esp/
├── airport_esp.lua   # 主脚本
└── README.md         # 说明文档
```
