print("ChestLock Loading...")

local protectedBlocks = {
	"mcl_chests:chest",
	"mcl_chests:chest_small",
	"mcl_chests:chest_left",
	"mcl_chests:chest_right",
	"mcl_hoppers:hopper",
	"mcl_hoppers:hopper_side",
	"mcl_furnaces:furnace",
	"mcl_barrels:barrel_open",
	"mcl_barrels:barrel_closed",
	"mcl_blast_furnace:blast_furnace",
	"mcl_smoker:smoker",
	"mcl_enchanting:table",
	"mcl_jukebox:jukebox",
	"mcl_smithing_table:table",
	"mcl_fletching_table:fletching_table",
	"mcl_grindstone:grindstone",
	"mcl_loom:loom",
	"mcl_anvils:anvil",
	"mcl_anvils:anvil_damage_1",
	"mcl_anvils:anvil_damage_2",
}

local signs = {
	"mcl_signs:wall_sign",
	"mcl_signs:wall_sign_birchwood",
	"mcl_signs:wall_sign_sprucewood",
	"mcl_signs:wall_sign_darkwood",
	"mcl_signs:wall_sign_junglewood",
	"mcl_signs:wall_sign_acaciawood",
	"mcl_signs:wall_sign_mangrove_wood",
	"mcl_signs:wall_sign_warped_hyphae_wood",
	"mcl_signs:wall_sign_crimson_hyphae_wood",
	"mcl_signs:wall_sign_bamboo",
	"mcl_signs:wall_sign_cherrywood",
}

chestlock = {}
chestlock.message = function(name, str)
	minetest.chat_send_player(name, minetest.colorize("#CC5000", "[ChestLock] " .. str))
end
string.startswith = function(self, str)
	return self:find("^" .. tostring(str)) ~= nil
end

local blockBehindSign = {
	vector.new(0, 0, 1), --dir: 0
	vector.new(1, 0, 0), --dir: 1
	vector.new(0, 0, -1), --dir: 2
	vector.new(-1, 0, 0), --dir: 3
}

local function patchSign(nodename)
	getmetatable(core.registered_nodes[nodename])["__newindex"] = nil --unwritelock the table
	local patchednode = core.registered_nodes[nodename]

	local oldplace = core.registered_nodes[nodename].on_place
	if oldplace ~= nil then
		patchednode.on_place = function(itemstack, placer, pointed_thing)
			--other mods can place blocks as no players
			if placer == nil then
				return oldplace(itemstack, placer, pointed_thing)
			end
			local playername = placer:get_player_name()

			--get the block the sign is attached on
			local above = pointed_thing.above
			local under = pointed_thing.under
			local dir = vector.subtract(under, above)
			local fdir = minetest.dir_to_facedir(dir)
			local blockpos = vector.add(above, blockBehindSign[fdir + 1])

			local owner = minetest.get_meta(blockpos):get_string("chestlock:owner") or "" --might return an empty string by default, oh well
			if owner ~= playername and owner ~= "" then --make sure player A cant lock player B's chest, also make sure if owner isnt set then just ignore it (post mod install)
				chestlock.message(playername, "You are not the owner of this block")
			elseif not minetest.is_protected(blockpos, playername) then
				return oldplace(itemstack, placer, pointed_thing)
			end
		end
	end
end

local smallBlockNeighbors = {
	vector.new(1, 0, 0), --  +x
	vector.new(-1, 0, 0), --  -x
	vector.new(0, 0, 1), --  +z
	vector.new(0, 0, -1), --  -z
}

--the correct direction for a sign to protect a chest
local smallBlockAttachedSigns = {
	3, --  +x
	2, --  -x
	5, --  +z
	4, --  -z
}

--direction from chest_left, to find chest_right
local doublechestFindRight = {
	vector.new(1, 0, 0), --dir: 0
	vector.new(0, 0, -1), --dir: 1
	vector.new(-1, 0, 0), --dir: 2
	vector.new(0, 0, 1), --dir: 3
}

function blockCheckTrust(pos, name) --returns true if player name is trusted to the protection
	if minetest.get_meta(pos):get_string("chestlock:owner") == name then
		return true
	end
	local istrusted = 0 --unlocked by default
	for i = 1, 4 do
		local cpos = vector.add(pos, smallBlockNeighbors[i]) --find some signs
		local node = minetest.get_node_or_nil(cpos)
		if
			node ~= nil
			and node.param2 == smallBlockAttachedSigns[i]
			and node.name:startswith("mcl_signs:wall_sign")
		then --make sure the sign is attached to the chest
			local nodemeta = minetest.get_meta(cpos)
			local text = string.split(nodemeta:get_string("text") or "", "\n")
			if text ~= nil and string.lower(text[1] or "") == "[private]" then
				if istrusted ~= 2 then
					istrusted = 1
				end --theres probably a better way
				for i = 2, 4 do
					if text[i] == name then
						istrusted = 2 --they are trusted
					end
				end
			end
		end
	end
	if istrusted == 0 or istrusted == 2 then
		return true
	end
	return false
end

function testDouble(pos, name)
	local node = minetest.get_node_or_nil(pos)
	local otherpos
	if node.name == "mcl_chests:chest_left" then
		otherpos = vector.add(doublechestFindRight[node.param2 + 1], pos)
	elseif node.name == "mcl_chests:chest_right" then
		otherpos = vector.add(vector.multiply(doublechestFindRight[node.param2 + 1], -1), pos)
	else
		return blockCheckTrust(pos, name)
	end
	return blockCheckTrust(pos, name) and blockCheckTrust(otherpos, name)
end

local old_isprotected = minetest.is_protected
minetest.is_protected = function(pos, name)
	local node = minetest.get_node_or_nil(pos)
	local short = string.split(node.name, ":")
	local shortname = short[#short]
	if node.name:startswith("mcl_signs:wall_sign") then
		local nodemeta = minetest.get_meta(pos)
		if nodemeta:get_string("chestlock:owner") == name then
			return old_isprotected(pos, name)
		end
		local text = string.split(nodemeta:get_string("text") or "", "\n")
		if text ~= nil and string.lower(text[1] or "") == "[private]" then
			for i = 2, 4 do
				if text[i] == name then
					return old_isprotected(pos, name)
				end
			end
			chestlock.message(name, "You do not have access to this sign")
			return true
		end
	end
	if node.name == "mcl_chests:chest_left" or node.name == "mcl_chests:chest_right" then
		if not testDouble(pos, name) then
			chestlock.message(name, "You do not have access to this locked " .. shortname)
			return true
		end
	end
	for i = 1, #protectedBlocks do
		if node.name == protectedBlocks[i] then
			if not blockCheckTrust(pos, name) then
				chestlock.message(name, "You do not have access to this locked " .. shortname)
				return true
			end
		end
	end
	return old_isprotected(pos, name)
end

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	--im very, very sorry
	for i = 1, #protectedBlocks do
		if protectedBlocks[i] == newnode.name then
			minetest.get_meta(pos):set_string("chestlock:owner", placer:get_player_name())
		end
	end
	for i = 1, #signs do
		if signs[i] == newnode.name then
			minetest.get_meta(pos):set_string("chestlock:owner", placer:get_player_name())
		end
	end
end)

minetest.register_on_mods_loaded(function()
	for i = 1, #signs do
		patchSign(signs[i])
	end

	for i = 1, #core.registered_abms do
		local abm = core.registered_abms[i]
		if abm.label == "Hopper/container item exchange" then --im sorry jon
			local oldaction = abm.action
			abm.action = function(pos, node, active_object_count, active_object_count_wider)
				local canmove = true
				local uppos = vector.offset(pos, 0, 1, 0)
				local upnode = minetest.get_node(uppos)
				if not minetest.registered_nodes[upnode.name] then
					return
				end
				for j = 1, #protectedBlocks do
					if upnode.name == protectedBlocks[j] and not blockCheckTrust(uppos, "#HOPPER") then
						return
					end
				end
				oldaction(pos, node, active_object_count, active_object_count_wider)
			end
		end
	end
end)
