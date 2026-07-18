# 机场安全透视脚本 ✈️

**作者: b站英吉利超入_**

用于 Roblox 机场安全游戏的透视（ESP）脚本，自动识别好人与坏人并高亮标记。

---

## 🚀 使用方式

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/mazihao62-beep/airport-security-esp/main/airport_esp.lua"))()
```

---

## 🎮 首次使用流程

1. 执行脚本 → Popup弹窗显示功能说明
2. 点击 **「确认加载」**
3. 按 **RightShift** 打开菜单（或手机点悬浮按钮 👁）
4. 在「UI设置」中：选择主题、开启粒子背景、设置毛玻璃
5. 在「功能设置」中绑定快捷键
6. 在「主控面板」开启透视

---

## ✨ v11.0 新功能

| 功能 | 说明 |
|------|------|
| 🎨 **16种内置主题** | Dark/Light/Rose/Plant/Red/Indigo/Sky/Violet/Amber/Emerald/Midnight/Crimson/Monokai Pro/Cotton Candy/Mellowsi/Rainbow |
| 🌀 **浮动粒子背景** | 35个动态粒子，呼吸动画，可开关 |
| 🔄 **透明背景增强毛玻璃** | Acrylic + Transparent 叠加，毛玻璃效果更明显 |
| 🎚 **透明度可调** | `WindUI.TransparencyValue = 0.22` 让毛玻璃更通透 |

### 完整UI结构

```
┌─ 主控面板 ─┬─ 功能设置 ─┬─ UI设置 ────────┬─ 信息统计 ─┬─ 配置管理 ─┬─ 关于 ─┐
│ 透视开关     │ 透视快捷键   │ 窗口快捷键       │ 统计/扫描    │ 保存配置    │ 版本   │
│ 仅显示坏人   │ 仅坏人快捷键  │ 悬浮按钮         │ 调试日志     │ 加载配置    │ 作者   │
│ 距离/血量    │            │ 🌀粒子背景开关     │             │ 删除配置    │ 说明   │
│ 探测距离滑块  │            │ ✨毛玻璃开关       │             │ 下拉选择    │       │
│              │            │ 🔄透明背景开关     │             │           │       │
│              │            │ 🎨主题下拉选择     │             │           │       │
└──────────────┴────────────┴──────────────────┴────────────┴───────────┴───────┘
```

---

## 🏷 NPC识别方法

| 优先级 | 方法 | 关键词/检测 |
|:-----:|------|------------|
| 1️⃣ | 属性检测 | NPCType/Type/Team/Faction/Role/Class |
| 2️⃣ | 中文名 | 警察/保安/警卫/守卫/士兵/恐怖/匪徒 |
| 3️⃣ | 英文名 | Police/Guard/Agent/Terrorist/Enemy |
| 4️⃣ | 部件颜色 | 蓝绿系=好人，红黑系=坏人 |
| 5️⃣ | 父级容器 | NPC所在文件夹名称 |
| 6️⃣ | 工具检测 | Arrest/Taser/Knife/Bomb |
| 7️⃣ | 路径检测 | AgentTemplate/NPCTemplate |

---

## 📜 版本历史

| 版本 | 内容 |
|------|------|
| **v11.0** | ✅ 16种内置主题下拉选择 + 浮动粒子背景(35个呼吸粒子) + Acrylic+Transparent增强毛玻璃 + 所有效果可开关 |
| v10.0 | ✅ 全面重写分类器 + 调试面板 |
| v9.0 | ✅ 配置保存系统 + 毛玻璃 + 透明背景 + Solar图标 |
| v8.0 | 对照官方文档重写API |
| v6.8 | 弹窗详细化 |
| v6.7 | Phone适配 + WindUI重构 |
| v6.5 | 修复加载URL + Popup/Notify API |
| v6.4 | 所有功能默认关闭 |
