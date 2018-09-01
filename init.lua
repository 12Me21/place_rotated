local function disp(x)
	minetest.chat_send_all(dump(x))
end

local function choose_log_facedir(normal)
	local face=minetest.dir_to_facedir(normal,true)
	local axis=({[8]=0,[4]=5,[0]=1,[2]=2,[1]=3,[3]=4})[face]
	return axis*4+0
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
local function choose_slab_facedir(normal,p)
	if not(p and normal) then return 0 end
	--if pointing at center of face:
	--(size is (close to) sqrt(5)/10 (3.5777/16) so that all 5 sections have the same area)
	if math.max(math.abs(p.x),math.abs(p.y),math.abs(p.z))<3.5/16 then
		return choose_log_facedir(normal)
	end
	--
	local axis=0
	local rotation=0 --might need to adjust this
	local face=minetest.dir_to_facedir(normal,true)
	--normal:
	if face==8 or face==4 then -- top / bottom face
		axis=({3,4,1,2})[get_sector(p.x,p.z)]
	elseif face==0 or face==2 then -- z+ / z- face
		axis=({3,4,0,5})[get_sector(p.x,p.y)]
	elseif face==1 or face==3 then -- x+ / x- face
		axis=({1,2,0,5})[get_sector(p.z,p.y)]
	end
	--convert axis/rotation to facedir
	return axis*4+rotation
end

local function get_normal(pos,placed_on)
	return vector.subtract(pos,placed_on)
end

local function get_face(normal)
	local face=minetest.dir_to_facedir(normal,true)
	return ({[3]=1,[4]=2,[2]=3,[1]=4,[8]=5,[0]=6})[face]
end

local wallmounted_to_facedir={[2]=0,[3]=2,[4]=3,[5]=1}

--input: node name + param2
--output: selection boxes, facedir
local function get_boxes(node)
	local name=node.name
	local param2=0
	local info=minetest.registered_nodes[name]
	if not info then return {-0.5,-0.5,-0.5,0.5,0.5,0.5},0 end
	if info.paramtype2=="wallmounted" or info.paramtype2=="facedir" then
		param2=node.param2
	end
	if not info.selection_box or info.selection_box.type=="regular" then
		return {-0.5,-0.5,-0.5,0.5,0.5,0.5},0
	elseif info.selection_box.type=="fixed" then
		return info.selection_box.fixed,param2
	elseif info.selection_box.type=="wallmounted" then
		if param2==0 then --placed on ceiling
			return info.selection_box.wall_top or {-0.5,7/16,-0.5,0.5,0.5,0.5},0
		elseif param2==1 then --placed on floor
			return info.selection_box.wall_bottom or {-0.5,-0.5,-0.5,0.5,-7/16,0.5},0
		else
			return info.selection_box.wall_side or {7/16,-0.5,-0.5,0.5,0.5,0.5},wallmounted_to_facedir[param2] --try to convert wallmounted to facedir
		end
	elseif info.selection_box.type=="connected" then --TODO
		return info.selection_box.fixed,0
	end
end

local function adjust_rotation(box,facedir_rotation)
	local new_box=table.copy(box)
	for i=1,facedir_rotation do
		local box_4=new_box[4]
		new_box[4]=new_box[6]
		new_box[6]=-new_box[1]
		new_box[1]=new_box[3]
		new_box[3]=-box_4
	end
	return new_box
end

--[[
   -     +
 x y z x y z ]]
-- local axis_table={
	-- {1,2,3,4,5,6, 1}, --y+
	-- {3,1,2,6,4,5, 1}, --z+
	-- {6,4,5,3,1,2, -1}, --z-
	-- {2,3,1,5,6,4, 1}, --x+
	-- {5,6,4,2,3,1, -1}, --x-
	-- {4,5,6,1,2,3, -1}, --y-
-- }

--source points
--value = where does [i] come from
local axis_table={
	{1,2,3,4,5,6}, --y+
	{1,6,2,4,3,5}, --z+
	{1,3,5,4,6,2}, --z-
	{2,4,3,5,1,6}, --x+ --
	{5,1,3,2,4,6}, --x- --
	{4,5,3,1,2,6}, --y- --rotates around the z axis
}

local function adjust_axis(box,facedir_axis)
	local new_box={0,0,0,0,0,0}
	for i in ipairs(box) do
		local source=axis_table[facedir_axis+1][i]
		local mul=1
		if (source<=3)~=(i<=3) then mul=-1 end
		new_box[i]=box[source]*mul
	end
	return new_box
end

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

--get the facedir given the position, the block it was placed onto, and the placer
local function get_point(pos,placed_on,placer)
	local placer_pos=placer:get_pos()
	placer_pos.y=placer_pos.y+1.625
	
	local normal=get_normal(pos,placed_on)
	if vector.length(normal)~=1 then
		disp("error: large selection box?")
		return normal
	end
	
	local face=get_face(normal)
	local boxes,facedir=get_boxes(minetest.get_node(placed_on))
	disp(boxes)
	disp(math.floor(facedir/4))
	disp(facedir%4)
	--if there's a list with just 1 box
	if #boxes==1 then boxes=boxes[1] end
	--single box
	if type(boxes[1])=="number" then
		local box=adjust_rotation(boxes,facedir%4)
		disp(box)
		box=adjust_axis(box,math.floor(facedir/4))
		disp(box)
		local mul=1
		if face<=3 then
			mul=-1
		end
		local surface=vector.add(placed_on,vector.multiply(normal,mul*box[face]))
		local p=intersect(placer_pos,placer:get_look_dir(),surface,normal)
		p=vector.subtract(p,surface)
		return normal,p
	--multiple boxes (aaaa)
	else
		disp("error: multiple selection boxes not supported")
	end
	return normal
end

local function between(value,min,max)
	return value>=min and value<=max
end

place_rotated={
	--on_place function for "slab-like" blocks
	slab=function(itemstack,placer,pointed,_)
		return minetest.item_place(itemstack,placer,pointed,
			choose_slab_facedir(get_point(pointed.above,pointed.under,placer))
		)
	end,
	--on_place function for "log-like" blocks
	log=function(itemstack,placer,pointed,_)
		return minetest.item_place(itemstack,placer,pointed,
			choose_log_facedir(get_normal(pointed.above,pointed.under))
		)
	end
}

--test:
minetest.register_node("place_rotated:test_slab",{
	description="Test Slab",
	drawtype="nodebox",
	tiles={"test_brick.png"},
	paramtype="light",
	paramtype2="facedir",
	node_box={
		type="fixed",
		fixed={-0.5,-0.5,-0.5,0.5,0,0.5},
	},
	groups={dig_immediate=3},
	on_place=place_rotated.slab
})

minetest.register_node("place_rotated:test_tree",{
	description="Test Tree",
	tiles={"test_log.png","test_log.png","test_bark.png"},
	paramtype2="facedir",
	groups={dig_immediate=3},
	on_place=place_rotated.log
})

minetest.register_node("place_rotated:test_diagram",{
	description="Test Diagram",
	tiles={"test_diagram.png"},
	groups={dig_immediate=3},
})
