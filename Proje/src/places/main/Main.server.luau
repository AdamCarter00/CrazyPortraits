--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Terms = require(ReplicatedStorage:WaitForChild("Shared").Config.Terms)

print(Terms.GameName .. " sunucu basladi")
