util.AddNetworkString('net.badapple.use')
--
AddCSLuaFile('cl_init.lua')
AddCSLuaFile('shared.lua')
AddCSLuaFile('json.lua')
AddCSLuaFile('data.lua')
include('shared.lua')
--

function ENT:Initialize()
	self:SetModel('models/props_combine/combine_interface001.mdl')
	self:SetSolid(SOLID_BBOX)
	self:PhysicsInit(SOLID_BBOX)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetUseType(SIMPLE_USE)
	self:DropToFloor()
end

function ENT:Use(activator, caller, use_type, value)
	if use_type == USE_ON and activator:IsPlayer() then
		net.Start('net.badapple.use')
		net.WriteEntity(self)
		net.Send(activator)
	end
end