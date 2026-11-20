--!strict

-- Istemciye bilgi gonderen tek yer: her mesaj Schema.shape'ten gecer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Schema = require(script.Schema)

local Net = {}

local function remote(channel: string): RemoteEvent
	return ReplicatedStorage:WaitForChild("NetRemotes"):WaitForChild(channel) :: RemoteEvent
end

function Net.toPlayer(player: Player, name: string, payload: { [string]: any })
	remote(Schema.channel(name)):FireClient(player, name, Schema.shape(name, payload))
end

function Net.toAll(name: string, payload: { [string]: any })
	remote(Schema.channel(name)):FireAllClients(name, Schema.shape(name, payload))
end

function Net.toUserId(userId: number, name: string, payload: { [string]: any })
	local player = Players:GetPlayerByUserId(userId)
	if player then
		Net.toPlayer(player, name, payload)
	end
end

function Net.onServerEvent(channel: string, handler: (Player, any, any) -> ())
	remote(channel).OnServerEvent:Connect(handler)
end

function Net.onClientEvent(channel: string, handler: (string, any) -> ())
	remote(channel).OnClientEvent:Connect(handler)
end

function Net.fireServer(channel: string, name: string, payload: any)
	remote(channel):FireServer(name, payload)
end

return Net
