local function dot(v, w)
	return v.x * w.x + v.y * w.y + v.z * w.z
end

local function intersect(pos, dir, origin, normal)
	local t = -dot(vector.subtract(pos, origin), normal) / dot(dir, normal)
	return {
		x = pos.x + dir.x * t,
		y = pos.y + dir.y * t,
		z = pos.z + dir.z * t
	}
end

--[[
 _______
|\  3  /|
|  \ /  |
|1  X  2|
|  / \  |
|/__4__\|
]]
local function get_sector(x,y)
	if -x>=math.abs(y) then --left
		return 1
	elseif x>=math.abs(y) then --right
		return 2
	elseif -y>=math.abs(x) then --up
		return 3
	elseif y>=math.abs(x) then --down
		return 4
	end
end

--calculate the facedir given the face and the clicked position
local function get_facedir(normal,p)
	local axis=0
	local rotation=0 --might need to adjust this
	local face=minetest.dir_to_facedir(normal,true)
	--faces (direction is outwards from the block (I think))
	-- 0 - Z+
	-- 1 - X+
	-- 2 - Z-
	-- 3 - X-
	-- 4 - bottom
	-- 8 - top
	
	--if pointing at center of face:
	--(size is sqrt(5)/10 so that all 5 sections have the same area)
	if math.max(math.abs(p.x),math.abs(p.y),math.abs(p.z))<5^0.5/10 then
		axis=({[8]=0,[4]=5,[0]=1,[2]=2,[1]=3,[3]=4})[face]
	--normal:
	elseif face==8 or face==4 then -- top / bottom face
		axis=({3,4,1,2})[get_sector(p.x,p.z)]
	elseif face==0 or face==2 then -- z+ / z- face
		axis=({3,4,0,5})[get_sector(p.x,p.y)]
	elseif face==1 or face==3 then -- x+ / x- face
		axis=({1,2,0,5})[get_sector(p.z,p.y)]
	end
	return axis*4+rotation
end

--get the facedir given the position, the block it was placed onto, and the placer
function get_orientation(pos,placed_on,placer)
	local placer_pos=placer:get_pos()
	placer_pos.y=placer_pos.y+1.625
	
	local normal=vector.subtract(pos,placed_on)
	local surface=vector.add(placed_on,vector.multiply(normal,0.5))
	
	local p=intersect(placer_pos,placer:get_look_dir(),surface,normal)
	p=vector.subtract(p,surface)
	return get_facedir(normal,p)
end

--on_place function:
function on_place_orientable(itemstack,placer,pointed,_)
	minetest.item_place(itemstack,placer,pointed,get_orientation(pointed.above,pointed.under,placer))
end

--after_place_node function:
function after_place_node_orientable(node_pos,placer,_,pointed)
	--node_pos and pointed.under *should* be the same here
	--but I trust node_pos more
	local node=minetest.get_node(node_pos)
	node.param2=get_orientation(pointed.above,pointed.under,placer)
	minetest.set_node(node_pos,node)
end

--test:
minetest.register_node("test:test_slab",{
	description="Test Slab",
	drawtype="nodebox",
	tiles={"default_cactus_top.png"},
	paramtype="light",
	paramtype2="facedir",
	node_box={
		type="fixed",
		fixed={-0.5,-0.5,-0.5,0.5,0,0.5},
	},
	groups={dig_immediate=3},
	--after_place_node=after_place_node_orientable,
	on_place=on_place_orientable,
	
})
