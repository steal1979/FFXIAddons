--[[

Copyright © 2017, Sammeh of Quetzalcoatl
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of sleeper nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Sammeh BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

]]

_addon.name = 'sleeper'
_addon.author = 'Sammeh'
_addon.version = '1.0.0.1'
_addon.command = 'sleeper'


texts = require('texts')
res = require 'resources'
packets = require('packets')

debuff_txt = {}
debuff_txt.pos = {}
debuff_txt.pos.x = -180
debuff_txt.pos.y = 185
debuff_txt.text = {}
debuff_txt.text.font = 'Arial'
debuff_txt.text.size = 10
debuff_txt.flags = {}
debuff_txt.flags.right = true

debuff_box = texts.new('${value}', debuff_txt)

local troubMeritGain = 0

local monster_list = {}
local boxvisible = false

function reset_list()
	for i,v in pairs(monster_list) do
		monster_list[i] = nil
	end
end

function new_sleep(target, duration)
	local mob = windower.ffxi.get_mob_by_id(target)
	monster_list[target] = {start=os.clock(),debuff_duration=duration,x=mob.x,y=mob.y,z=mob.z}
end

function count_monster_list()
	local num = 0
		for i,v in pairs(monster_list) do
			num = num +1
		end
	return num
end


windower.register_event('prerender', function()
	local t = windower.ffxi.get_mob_by_index(windower.ffxi.get_player().target_index or 0)
	local mob_id,value
	if monster_list and count_monster_list() > 0 then 
		local debuff_txtbox = 'Target List: '..count_monster_list()
		for mob_id,value in pairs(monster_list) do
			local mob = windower.ffxi.get_mob_by_id(mob_id)
			
			if mob then 
			
			if mob.x and value.x then 
				x_delta = mob.x - value.x
			else
				x_delta = 0
			end
			if mob.y and value.y then 
				y_delta = mob.y - value.y
			else
				y_delta = 0
			end
			
			
			if x_delta > 5 or x_delta < -5 or y_delta > 5 or y_delta < -5 then 
				monster_list[mob_id].debuff_duration = 0
			end
			
			local start_time = monster_list[mob_id].start
			local duration = monster_list[mob_id].debuff_duration
			local now = os.clock()	
			local remaining_time = string.format("%.1f", duration - (now - start_time))
			
			if mob.status == 1 or mob.status == 0 then 
				if t then
					if t.id == mob_id then 
						-- Print the txt in Green!
						if duration - (now - start_time) < 0 then 
							debuff_txtbox = debuff_txtbox.."\n\\cs(0,255,0)Mob: "..mob.name.." Awake!\\cs(255,255,255)" 
						else
							debuff_txtbox = debuff_txtbox.."\n\\cs(0,255,0)Mob: "..mob.name.." Is Asleep! Remaining:"..remaining_time.."\\cs(255,255,255)"
						end
					else
						if duration - (now - start_time) < 0 then 
							debuff_txtbox = debuff_txtbox.."\nMob: "..mob.name.." Awake!" 
						else
							debuff_txtbox = debuff_txtbox.."\nMob: "..mob.name.." Is Asleep! Remaining:"..remaining_time	
						end
					end
				else
					if duration - (now - start_time) < 0 then 
						debuff_txtbox = debuff_txtbox.."\nMob: "..mob.name.." Awake!" 
					else
						debuff_txtbox = debuff_txtbox.."\nMob: "..mob.name.." Is Asleep! Remaining:"..remaining_time	
					end
				end
			else
				monster_list[mob_id] = nil
			end
			end
		end
		debuff_box.value = debuff_txtbox
		if boxvisible then
			debuff_box:visible(true)
		else 
			debuff_box:visible(false)
		end
	else
		debuff_box:visible(false)
	end
end)

last_spell = ''
lullaby_spell_ids = S{376, 377, 463, 471}

windower.register_event('incoming chunk', function(id,original,modified,injected,blocked)
	local self = windower.ffxi.get_player()
    if id == 0x028 then
		local packet = packets.parse('incoming', original)
		local now = os.clock()
		
		if packet['Category'] == 8 and packet.Actor == self.id then 
			last_spell = packet['Target 1 Action 1 Param']
		end
		
		if packet['Category'] == 4 and packet.Actor == self.id and lullaby_spell_ids:contains(last_spell) then
			local numtargets = packet['Target Count']
			local count = 0
			
			if packet.Actor == self.id then
				while count < numtargets do
					count = count + 1
					local target_id = packet['Target '..count..' ID']
					local spell_duration = calculate_duration_raw(last_spell)
					local message = packet['Target '..count..' Action 1 Message']
					if message == 270 or message == 236 then 
						new_sleep(target_id, spell_duration)
					end
				end
				
			end
		end
		if monster_list[packet.Actor] and ((now - monster_list[packet.Actor].start) > 5) then 
			monster_list[packet.Actor] = {start=monster_list[packet.Actor].start,debuff_duration=0}
		end
	end
end)

windower.register_event('zone change',function()
reset_list()
end)


windower.register_event('addon command', function(command)
    if command == 'save' then
        config.save(settings, 'all')
    end
	if command == 'reset' then reset_list() end
	if command == 'show' then boxvisible = true end
	if command == 'hide' then boxvisible = false end 
end)


function calculate_duration_raw(spell_id)

	local self = windower.ffxi.get_player()
	
	-- Troub = 348, ClarionCall = 499, Soul Voice = 52, Marcato = 231
	
	local troubadour,clarioncall,soulvoice,marcato
	
	for i,v in pairs(self.buffs) do
		if v == 348 then troubadour = true end
		if v == 499 then clarioncall = true end
		if v == 52 then soulvoice = true end
		if v == 231 then marcato = true end
	end
	
	
	spell = res.spells[spell_id]
    local mult = 1
	
	local gear = windower.ffxi.get_items()
	local mainweapon = res.items[windower.ffxi.get_items(gear.equipment.main_bag, gear.equipment.main).id]
	local subweapon = res.items[windower.ffxi.get_items(gear.equipment.sub_bag, gear.equipment.sub).id]
	local range = res.items[windower.ffxi.get_items(gear.equipment.range_bag, gear.equipment.range).id]
	local ammo = res.items[windower.ffxi.get_items(gear.equipment.ammo_bag, gear.equipment.ammo).id]
	local head = res.items[windower.ffxi.get_items(gear.equipment.head_bag, gear.equipment.head).id]
	local neck = res.items[windower.ffxi.get_items(gear.equipment.neck_bag, gear.equipment.neck).id]
	local ear1 = res.items[windower.ffxi.get_items(gear.equipment.left_ear_bag, gear.equipment.left_ear).id]
	local ear2 = res.items[windower.ffxi.get_items(gear.equipment.right_ear_bag, gear.equipment.right_ear).id]
	local body = res.items[windower.ffxi.get_items(gear.equipment.body_bag, gear.equipment.body).id]
	local hands = res.items[windower.ffxi.get_items(gear.equipment.hands_bag, gear.equipment.hands).id]
	local ring1 = res.items[windower.ffxi.get_items(gear.equipment.left_ring_bag, gear.equipment.right_ring).id]
	local ring2 = res.items[windower.ffxi.get_items(gear.equipment.right_ring_bag, gear.equipment.left_ring).id]
	local back = res.items[windower.ffxi.get_items(gear.equipment.back_bag, gear.equipment.back).id]
	local waist = res.items[windower.ffxi.get_items(gear.equipment.waist_bag, gear.equipment.waist).id]
	local legs = res.items[windower.ffxi.get_items(gear.equipment.legs_bag, gear.equipment.legs).id]
	local feet = res.items[windower.ffxi.get_items(gear.equipment.feet_bag, gear.equipment.feet).id]
	
    if range.id == 18575 then mult = mult + 0.25 end -- Daurdabla LVL 90
	if range.id == 18571 or range.id == 18576 or range.id == 18839 then mult = mult + 0.3 end -- Daurdabla LVL 99 | LVL 95 | AG LVL 99
	if range.id == 18342 or range.id == 18577 or range.id == 18578 then mult = mult + 0.2 end -- Gjallarhorn LVL 75 | LVL 80 | LVL 85
	if range.id == 18579 or range.id == 18580 then mult = mult + 0.3 end -- Gjallarhorn LVL 90 | LVL 95
	if range.id == 18840 or range.id == 18572 then mult = mult + 0.4 end -- Gjallarhorn LVL 99 | AG LVL 99
	if range.id == 21398 then mult = mult + 0.5 end -- Marsyas
	
	if mainweapon.id == 18980 or mainweapon.id == 19000 then mult = mult + 0.1 end -- Carnwenhan LVL 75
    if mainweapon.id == 19069 then mult = mult + 0.2 end -- Carnwenhan LVL 80
	if mainweapon.id == 19089 then mult = mult + 0.3 end -- Carnwenhan LVL 85
	if mainweapon.id == 19621 or mainweapon.id == 19719 then mult = mult + 0.4 end -- Carnwenhan LVL 90 | LVL 95
	if mainweapon.id == 19828 or mainweapon.id == 19957 or mainweapon.id == 20561 or mainweapon.id == 20562 or mainweapon.id == 20586 then mult = mult + 0.5 end -- Carnwenhan LVL 99 - 119 AG
	
	if subweapon.id == 18980 or subweapon.id == 19000 then mult = mult + 0.1 end -- Carnwenhan LVL 75
    if subweapon.id == 19069 then mult = mult + 0.2 end -- Carnwenhan LVL 80
	if subweapon.id == 19089 then mult = mult + 0.3 end -- Carnwenhan LVL 85
	if subweapon.id == 19621 or subweapon.id == 19719 then mult = mult + 0.4 end -- Carnwenhan LVL 90 | LVL 95
	if subweapon.id == 19828 or subweapon.id == 19957 or subweapon.id == 20561 or subweapon.id == 20562 or subweapon.id == 20586 then mult = mult + 0.5 end -- Carnwenhan LVL 99 - 119 AG
	
    if mainweapon.en == "Legato Dagger" then mult = mult + 0.05 end
	if subweapon.en == "Legato Dagger" then mult = mult + 0.05 end
	if mainweapon.en == "Kali" then mult = mult + 0.05 end
	if subweapon.en == "Kali" then mult = mult + 0.05 end
	
	if neck.en == "Aoidos' Matinee" then mult = mult + 0.1 end
	if neck.en == "Moonbow Whistle" then mult = mult + 0.2 end 
	if neck.en == "Mnbw. Whistle +1" then mult = mult + 0.2 end 
    if body.en == "Fili Hongreline +1" then mult = mult + 0.12 end
    if legs.en == "Inyanga Shalwar +1" then mult = mult + 0.15 end
    if feet.en == "Brioso Slippers" then mult = mult + 0.1 end
    if feet.en == "Brioso Slippers +1" then mult = mult + 0.11 end
	if feet.en == "Brioso Slippers +2" then mult = mult + 0.13 end
	if feet.en == "Brioso Slippers +3" then mult = mult + 0.15 end
	if hands.en == 'Brioso Cuffs +1' then mult = mult + 0.1 end
	if hands.en == 'Brioso Cuffs +2' then mult = mult + 0.1 end
	if hands.en == 'Brioso Cuffs +3' then mult = mult + 0.2 end
    
	
	if self.job_points.brd.jp_spent >= 1200 then
		mult = mult + 0.05
	end
		
    if troubadour then
        mult = mult*2
    end
    
	if spell.en == "Foe Lullaby II" or spell.en == "Horde Lullaby II" then 
		base = 60
	elseif spell.en == "Foe Lullaby" or spell.en == "Horde Lullaby" then 
		base = 30
	end
	
	totalDuration = math.floor(mult*base)		
	
	
	-- Job Points Buff
	totalDuration = totalDuration + self.job_points.brd.lullaby_duration
	
	if clarioncall then
		if troubadour then 
			totalDuration = totalDuration + (self.job_points.brd.clarion_call_effect * 2)
		else
			totalDuration = totalDuration + self.job_points.brd.clarion_call_effect
		end
	end
	
	if marcato and not soulvoice then
		totalDuration = totalDuration + self.job_points.brd.marcato_effect
	end


	if troubadour then 
		totalDuration = totalDuration + troubMeritGain
	end

    return totalDuration
	
end


windower.register_event('outgoing chunk',function(id,data,modified,injected,blocked)
	if id == 0x01A then
		--local packet = packets.parse('outgoing', data)
		local packet = packets.parse('outgoing', modified)
		local self = windower.ffxi.get_player()
		local ability_used = packet.Param
		local category = packet.Category
		if res.job_abilities[ability_used] then 
			if res.job_abilities[ability_used].id == 164 and category == 9 then
				local gear = windower.ffxi.get_items()
				local body = res.items[windower.ffxi.get_items(gear.equipment.body_bag, gear.equipment.body).id]
				if body.en == "Bihu Justaucorps" or body.en == "Bihu Jstcorps +1" then 
					troubMeritGain = self.merits.troubadour * 4 
				end
				print("Adding Buff Gain",troubMeritGain,body.en)
			end
		end
	end
end)