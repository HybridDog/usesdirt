minetest.register_alias("usesdirt:dirt_ladder", "usesdirt:dirt_brick_ladder")
minetest.register_alias("usesdirt:dirt_fence", "usesdirt:dirt_brick_fence")


local dirtnodes = {
	{"brick", "Brick", {snappy=2,choppy=1,oddly_breakable_by_hand=3}, "default:dirt"},
	{"cobble_stone", "Cobble Stone", {cracky=3, stone=2}, 'usesdirt:dirt_brick'},
	{"stone", "Stone", {cracky=3, stone=2}, "usesdirt:dirt_cobble_stone", true},
--	{"dried_dirt", "Dried", {cracky=3, stone=2}}
}


for _,dirtnode in pairs(dirtnodes) do
	local name = dirtnode[1]
	local desc = "Dirt "..dirtnode[2]
	local groups = dirtnode[3]
	local craftinput = dirtnode[4]

	local nodename = "usesdirt:dirt_"..name
	local texture = "usesdirt_"..name..".png"
	minetest.register_node(nodename, {
		tiles = {texture},
		description = desc,
		groups = groups,
	})

	local lnodename = "usesdirt:dirt_"..name.."_ladder"
	local ltexture = "usesdirt_ladder_"..name..".png"
	minetest.register_node(lnodename, {
		description = desc.." Ladder",
		drawtype = "signlike",
		tiles ={ltexture},
		inventory_image = ltexture,
		wield_image = ltexture,
		paramtype = "light",
		paramtype2 = "wallmounted",
		walkable = false,
		climbable = true,
		selection_box = {
			type = "wallmounted",
		},
		groups = groups,
		legacy_wallmounted = true,
	})

	local fnodename = "usesdirt:dirt_"..name.."_fence"
	local ftexture = "usesdirt_fence_"..name..".png"
	minetest.register_node(fnodename, {
		description = desc.." Fence",
		drawtype = "fencelike",
		tiles ={texture},
		inventory_image = ftexture,
		wield_image = ftexture,
		paramtype = "light",
		selection_box = {
			type = "fixed",
			fixed = {-1/7, -1/2, -1/7, 1/7, 1/2, 1/7},
		},
		groups = groups,
	})

	if dirtnode[5] then
		minetest.register_craft({
			type = "cooking",
			output = nodename,
			recipe = craftinput,
		})
	else
		minetest.register_craft({
			output = nodename..' 6',
			recipe = {
				{craftinput, craftinput, craftinput},
				{craftinput, craftinput, craftinput},
				{craftinput, craftinput, craftinput},
			}
		})
	end

	minetest.register_craft({
		output = lnodename..' 3',
		recipe = {
			{nodename, '', nodename},
			{nodename, nodename, nodename},
			{nodename, '', nodename},
		}
	})

	minetest.register_craft({
		output = fnodename..' 2',
		recipe = {
			{nodename, nodename, nodename},
			{nodename, nodename, nodename},
		}
	})
end
----------------------------------------------------------------------------------------------------
--Furnace
local tmp = table.copy(minetest.registered_nodes["default:furnace"])
if not tmp then
	return
end
tmp.description = "Dirt "..tmp.description
tmp.tiles = {"usesdirt_furnace_top.png", "usesdirt_furnace_bottom.png", "usesdirt_furnace_side.png",
	"usesdirt_furnace_side.png", "usesdirt_furnace_side.png", "usesdirt_furnace_front.png"}
minetest.register_node("usesdirt:dirt_furnace", tmp)

local tmp = table.copy(minetest.registered_nodes["default:furnace_active"])
tmp.description = "Dirt "..tmp.description
tmp.tiles = {"usesdirt_furnace_top.png", "usesdirt_furnace_bottom.png", "usesdirt_furnace_side.png",
	"usesdirt_furnace_side.png", "usesdirt_furnace_side.png", "usesdirt_furnace_front_active.png"}
tmp.drop = "usesdirt:dirt_furnace"
minetest.register_node("usesdirt:dirt_furnace_active", tmp)

function hacky_swap_node(pos,name)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local meta0 = meta:to_table()
	if node.name == name then
		return
	end
	node.name = name
	local meta0 = meta:to_table()
	minetest.set_node(pos,node)
	meta = minetest.get_meta(pos)
	meta:from_table(meta0)
end

minetest.register_abm({
	nodenames = {"usesdirt:dirt_furnace","usesdirt:dirt_furnace_active"},
	interval = 1,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local meta = minetest.get_meta(pos)
		for i, name in ipairs({
				"fuel_totaltime",
				"fuel_time",
				"src_totaltime",
				"src_time"
		}) do
			if meta:get_string(name) == "" then
				meta:set_float(name, 0.0)
			end
		end

		local inv = meta:get_inventory()

		local srclist = inv:get_list("src")
		local cooked = nil
		local aftercooked

		if srclist then
			cooked, aftercooked = minetest.get_craft_result({method = "cooking", width = 1, items = srclist})
		end

		local was_active = false

		if meta:get_float("fuel_time") < meta:get_float("fuel_totaltime") then
			was_active = true
			meta:set_float("fuel_time", meta:get_float("fuel_time") + 1)
			meta:set_float("src_time", meta:get_float("src_time") + 1)
			if cooked and cooked.item and meta:get_float("src_time") >= cooked.time then
				-- check if there's room for output in "dst" list
				if inv:room_for_item("dst",cooked.item) then
					-- Put result in "dst" list
					inv:add_item("dst", cooked.item)
					-- take stuff from "src" list
					inv:set_stack("src", 1, aftercooked.items[1])
				else
					print("Could not insert '"..cooked.item:to_string().."'")
				end
				meta:set_string("src_time", 0)
			end
		end

		if meta:get_float("fuel_time") < meta:get_float("fuel_totaltime") then
			local percent = math.floor(meta:get_float("fuel_time") /
					meta:get_float("fuel_totaltime") * 100)
			meta:set_string("infotext","Furnace active: "..percent.."%")
			hacky_swap_node(pos,"usesdirt:dirt_furnace_active")
			meta:set_string("formspec",default.get_furnace_active_formspec(pos, percent))
			return
		end

		local fuel = nil
		local afterfuel
		local cooked = nil
		local fuellist = inv:get_list("fuel")
		local srclist = inv:get_list("src")

		if srclist then
			cooked = minetest.get_craft_result({method = "cooking", width = 1, items = srclist})
		end
		if fuellist then
			fuel, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = fuellist})
		end
		if not fuel then
			return
		end

		if fuel.time <= 0 then
			meta:set_string("infotext","Furnace out of fuel")
			hacky_swap_node(pos,"usesdirt:dirt_furnace")
			meta:set_string("formspec", default.furnace_inactive_formspec)
			return
		end

		if cooked.item:is_empty() then
			if was_active then
				meta:set_string("infotext","Furnace is empty")
				hacky_swap_node(pos,"usesdirt:dirt_furnace")
				meta:set_string("formspec", default.furnace_inactive_formspec)
			end
			return
		end

		meta:set_string("fuel_totaltime", fuel.time)
		meta:set_string("fuel_time", 0)

		inv:set_stack("fuel", 1, afterfuel.items[1])
	end,
})

minetest.register_craft({
	output = 'usesdirt:dirt_furnace',
	recipe = {
		{'usesdirt:dirt_stone', 'usesdirt:dirt_stone', 'usesdirt:dirt_stone'},
		{'usesdirt:dirt_stone', 'default:dirt','usesdirt:dirt_stone'},
		{'usesdirt:dirt_stone','usesdirt:dirt_stone','usesdirt:dirt_stone'},
	}
})
--Tools
local dirttools_list = {
	{"axe", "Axe"},
	{"sword", "Sword"},
	{"shovel", "Shovel"},
	{"pick", "Pickaxe"},
}

for _,i in pairs(dirttools_list) do
	local tmp = table.copy(minetest.registered_tools["default:"..i[1].."_stone"])
	tmp.description = "Dirt "..i[2]
	tmp.inventory_image = "usesdirt_dirt_"..i[1]..".png"
	minetest.register_tool("usesdirt:dirt_"..i[1], tmp)
end

local a = 'usesdirt:dirt_stone'
local b = 'default:stick'
minetest.register_craft({
	output = 'usesdirt:dirt_axe',
	recipe = {
		{a, a},
		{a, b},
		{'', b},
	}
})

minetest.register_craft({
	output = 'usesdirt:dirt_sword',
	recipe = {
		{a},
		{a},
		{b},
	}
})

minetest.register_craft({
	output = 'usesdirt:dirt_shovel',
	recipe = {
		{a},
		{b},
		{b},
	}
})

minetest.register_craft({
	output = 'usesdirt:dirt_pick',
	recipe = {
		{a, a, a},
		{'', b, ''},
		{'', b, ''},
	}
})
--Chest
local tmp = table.copy(minetest.registered_nodes["default:chest"])
tmp.description = "Dirt "..tmp.description
tmp.tiles = {"usesdirt_chest.png"}
tmp.groups = {cracky=3, stone=2}
minetest.register_node("usesdirt:dirt_chest", tmp)

local tmp = table.copy(minetest.registered_nodes["default:chest_locked"])
tmp.description = "Dirt "..tmp.description
tmp.tiles = {"usesdirt_locked_chest.png"}
tmp.groups = {cracky=3, stone=2}
minetest.register_node("usesdirt:dirt_locked_chest", tmp)

minetest.register_craft({
	output = 'usesdirt:dirt_locked_chest',
	recipe = {
		{'usesdirt:dirt_stone', 'usesdirt:dirt_stone', 'usesdirt:dirt_stone'},
		{'usesdirt:dirt_stone', 'default:steel_ingot', 'usesdirt:dirt_stone'},
		{'usesdirt:dirt_stone', 'usesdirt:dirt_stone', 'usesdirt:dirt_stone'},
	}
})
minetest.register_craft({
	output = 'usesdirt:dirt_chest',
	recipe = {
		{'usesdirt:dirt_stone', 'usesdirt:dirt_stone', 'usesdirt:dirt_stone'},
		{'usesdirt:dirt_stone', '', 'usesdirt:dirt_stone'},
		{'usesdirt:dirt_stone', 'usesdirt:dirt_stone', 'usesdirt:dirt_stone'},
	}
})
----Glow dirt
minetest.register_node("usesdirt:dirt_normal_glow", {
	tiles = {"usesdirt_dirt_normal_glow.png"},
	light_source = 10,
	description = "Normal Glow Dirt",
	groups = {crumbly=3},
})
minetest.register_craft({
	output = 'usesdirt:dirt_normal_glow',
	recipe = {
		{'default:dirt', 'default:dirt', 'default:dirt'},
		{'', 'default:torch', ''},
		{'default:dirt', 'default:dirt', 'default:dirt'},
	}
})
--
minetest.register_node("usesdirt:dirt_super_glow", {
	tiles = {"usesdirt_dirt_normal_glow.png^usesdirt_dirt_super_glow.png"},
	light_source = 15,
	description = "Super Glow Dirt",
	groups = {crumbly=3},
})
minetest.register_craft({
	output = 'usesdirt:dirt_super_glow',
	recipe = {
		{'default:dirt', 'default:dirt', 'default:dirt'},
		{'default:torch', 'default:torch', 'default:torch'},
		{'default:dirt', 'default:dirt', 'default:dirt'},
	}
})
