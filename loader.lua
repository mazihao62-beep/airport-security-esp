-- 机场透视加载器 v1.0（绕过GitHub缓存问题）
local ok, data = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/mazihao62-beep/airport-security-esp/main/airport_esp.lua", true)
end)
if not ok or not data or data == "" then
    local m = Instance.new("Message")
    m.Text = "⚠️ 加载失败，请检查网络"
    m.Parent = workspace
    task.delay(3, function() m:Destroy() end)
    return
end
local fn, err = loadstring(data)
if not fn then
    local m = Instance.new("Message")
    m.Text = "⚠️ 脚本语法错误: " .. tostring(err):sub(1, 50)
    m.Parent = workspace
    task.delay(5, function() m:Destroy() end)
    return
end
fn()