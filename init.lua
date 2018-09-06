local function choose_log_facedir(normal)
	local face=minetest.dir_to_facedir(normal,true)
	local axis=({[8]=0, [4]=5, [0]=1, [2]=2, [1]=3, [3]=4})[face]
	return axis * 4 + 0
end

--[[
 _______
|\  3  /|
|  \ /  |
|1  X  2|
|  / \  |
|/__4__\|
]]
local function get_sector(x, y)
	if -x >= math.abs(y) then --left
		return 1
	elseif x >= math.abs(y) then --right
		return 2
	elseif -y >= math.abs(x) then --up
		return 3
	elseif y >= math.abs(x) then --down
		return 4
	end
end

local function point_on_face(pos, normal)
	for i in pairs(pos) do
		if normal[i] ~= 0 then
			pos[i] = 0
		else
			pos[i] = (pos[i] + 0.5) % 1 - 0.5
		end
	end
end

--calculate the facedir given the face and the clicked position
local function choose_slab_facedir(normal, p)
	if not(p and normal) then return 0 end
	
	point_on_face(p, normal) --ignore the "depth" of the point
	
	--if pointing at center of face:
	--(size is (close to) sqrt(5)/10 (3.5777/16) so that all 5 sections have the same area)
	if math.max(math.abs(p.x), math.abs(p.y), math.abs(p.z)) < 3.5/16 then 
		return choose_log_facedir(normal)
	end
	--
	local axis = 0
	local face = minetest.dir_to_facedir(normal, true)
	--normal:
	if face == 8 or face == 4 then -- top / bottom face
		axis = ({3,4,1,2})[get_sector(p.x, p.z)]
	elseif face == 0 or face == 2 then -- z+ / z- face
		axis = ({3,4,0,5})[get_sector(p.x, p.y)]
	elseif face == 1 or face == 3 then -- x+ / x- face
		axis = ({1,2,0,5})[get_sector(p.z, p.y)]
	end
	--convert axis/rotation to facedir
	return axis * 4 + 0
end

-- This is the most important function
-- It returns the exact location the player is pointing at,
-- given the player
local function get_point(placer)
	local placer_pos = placer:get_pos()
	placer_pos.y = placer_pos.y + placer:get_properties().eye_height
	local raycast = minetest.raycast(placer_pos, vector.add(placer_pos, vector.multiply(placer:get_look_dir(), 20)), false)
	local pointed = raycast:next()
	if pointed and pointed.type == "node" then
		return pointed.intersection_normal,
			   vector.subtract(pointed.intersection_point,pointed.under),
			   pointed.box_id
	end
end

place_rotated = {
	--on_place function for "slab-like" blocks
	slab = function(itemstack, placer, pointed, _)
		return minetest.item_place(itemstack, placer, pointed,
			choose_slab_facedir(get_point(placer))
		)
	end,
	--on_place function for "log-like" blocks
	log = function(itemstack, placer, pointed, _)
		return minetest.item_place(itemstack, placer, pointed,
			choose_log_facedir(get_point(placer))
		)
	end,
	--allow other things to use these I guess
	get_point = get_point, 
	choose_log_facedir = choose_log_facedir,
	choose_slab_facedir = choose_slab_facedir,
}

dofile(minetest.get_modpath("place_rotated").."/items.lua")
--dofile(minetest.get_modpath("place_rotated").."/wires.lua")