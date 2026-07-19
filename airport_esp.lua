--[[
    机场安全透视 v15.0
    功能: NPC透视+行李箱检测+自动工作系统
    作者: b站英吉利超入_
]]
local P=game:GetService("Players");local U=game:GetService("UserInputService");local W=game:GetService("Workspace");local C=game:GetService("CoreGui");local RS=game:GetService("ReplicatedStorage")
pcall(function()LP=P.LocalPlayer end)
IM=U.TouchEnabled and not U.KeyboardEnabled
if not IM then pcall(function()IM=U.TouchEnabled and not U.MouseEnabled end)end