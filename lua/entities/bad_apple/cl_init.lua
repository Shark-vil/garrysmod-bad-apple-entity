include('shared.lua')

-- -----------------------------------------------
-- VARIABLES
-- -----------------------------------------------

--[[
	Libraries
--]]
local _json = include('json.lua')
local _bad_apple_frames = include('data.lua')

--[[
	Constants
--]]
local _max_row = 28
local _max_col = 28
local _material = 'models/debug/debugwhite'
local _model = 'models/props_c17/streetsign004e.mdl'
local _model_angle = Angle(0, 90, 0)

--[[
	Options
--]]
local _x_size = 25
local _y_size = 25
local _black_color = Color(0, 0, 0)
local _pixel_color = Color(255, 255, 255)
local _progress_load_color = Color(255, 0, 0)
local _progress_complete_color = Color(0, 255, 34)
local _music = Sound('bad_apple/music.mp3')
local _sound_progress = Sound('npc/overwatch/radiovoice/inprogress.wav')
local _sound_progress_complete = Sound('items/suitchargeok1.wav')

-- -----------------------------------------------
-- LOCAL FUNCTIONS
-- -----------------------------------------------

-- Deletes client models and clears the list
local function ClearModels(ent)
	ent.models_storage = ent.models_storage or {}

	for row = #ent.models_storage, 1, -1 do
		local models = ent.models_storage[row]
		for col = #models, 1, -1 do
			local model = models[col]
			if model and IsValid(model) then
				model:Remove()
			end
		end
	end

	ent.models_storage = {}
end

-- Create a new stack of client models
local function CreateModels(ent)
	ent.models_storage = ent.models_storage or {}

	ClearModels(ent)

	for row = 1, _max_row do
		for col = 1, _max_col do
			local model = ClientsideModel(_model)
			model:SetColor(_black_color)
			model:SetMaterial(_material)
			model:Spawn()

			ent.models_storage[row] = ent.models_storage[row] or {}
			ent.models_storage[row][col] = model
		end
	end
end

-- Positions the models in the correct order
local function SetModelsPosition(ent)
	local current_col = _max_col
	local current_row = _max_row
	local default_angle = ent:GetForward():Angle() - _model_angle
	local total_size_x = _max_col * _x_size
	local y_offset = 100
	local models_storage = ent.models_storage
	-- local total_size_y = _max_row * _y_size

	for row = 1, #models_storage do
		local models = models_storage[row]

		for col = 1, #models do
			local model = models[col]

			if model and IsValid(model) then
				local current_position = ent:GetPos() + ent:GetRight() * (_x_size * current_col)
				current_position = current_position + Vector(0, 0, 1) * (_y_size * current_row)
				current_position = current_position + ent:GetForward() * -100
				current_position = current_position - ent:GetRight() * (total_size_x / 2)
				-- current_position = current_position + ent:GetUp() * (total_size_y / 2)
				current_position = current_position + ent:GetUp() * y_offset

				model:SetPos(current_position)
				model:SetAngles(default_angle)
			end

			current_col = current_col - 1
		end

		current_col = _max_col
		current_row = current_row - 1
	end
end

local function StartRenderer(ent)
	local models_storage 		= ent.models_storage
	local frames 						= ent.frames
	local frames_count 			= #frames
	local frame_index 			= 0
	local is_play_sound 		= false
	local fps 							= 20

	timer.Create('BadApple.Renderer', 1 / fps, frames_count, function()
		if not is_play_sound then
			surface.PlaySound(_music)
			is_play_sound = true
		end

		frame_index = frame_index + 1

		local frame = frames[frame_index]

		for row = 1, _max_row do
			for col = 1, _max_col do
				local pixel = frame[row][col]
				local model = models_storage[row][col]
				model:SetColor(pixel == 1 and _black_color or _pixel_color)
			end
		end
	end)
end

local function AsyncLoadData(ent)
	ent.parse_json_bad_apple = true
	ent.progress_is_complete = false

	surface.PlaySound(_sound_progress)

	local frames = _json.parseAsync(_bad_apple_frames)

	surface.PlaySound(_sound_progress_complete)

	ent.progress_is_complete = true
	ent.frames = frames

	coroutine.wait(1.5)
end

-- -----------------------------------------------
-- ENTITY FUNCTIONS
-- -----------------------------------------------

function ENT:Initialize()
	local progress_bar = 0

	timer.Simple(0, function()
		if not IsValid(self) then return end

		hook.Add('PreDrawTranslucentRenderables', self, function()
			if not self.parse_json_bad_apple then return end

			local position = self:GetPos() + self:GetUp() * 42
			position = position + self:GetRight() * 11
			position = position - self:GetForward() * -6

			local default_angle = self:GetForward():Angle() - Angle(0, -90, -30)

			cam.Start3D2D(position , default_angle, 0.25)
				if not self.progress_is_complete then
					draw.RoundedBox(2, 0, 0, progress_bar, 20, _progress_load_color)
					progress_bar = progress_bar + 1
					if progress_bar > 100 then progress_bar = 0 end
				else
					draw.RoundedBox(2, 0, 0, 100, 20, _progress_complete_color)
				end
			cam.End3D2D()
		end)
	end)
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:OnRemove()
	ClearModels(self)
	timer.Remove('BadApple.Renderer')
	hook.Remove('Think', 'BadApple.ReadJsonData')
	RunConsoleCommand('stopsound')
end

net.Receive('net.badapple.use', function()
	local ent = net.ReadEntity()
	if not IsValid(ent) or ent.bad_apple_used then return end

	ent.bad_apple_used = true

	CreateModels(ent)
	SetModelsPosition(ent)

	local co = coroutine.create(AsyncLoadData)

	hook.Add('Think', 'BadApple.ReadJsonData', function()
		if not coroutine.resume(co, ent) then
			StartRenderer(ent)
			hook.Remove('Think', 'BadApple.ReadJsonData')
		end
	end)
end)