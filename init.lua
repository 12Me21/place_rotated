local function disp(x)
	minetest.chat_send_all(dump(x))
end

local function tell(player,message)
	minetest.chat_send_player(player:get_player_name(),message)
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

local function remove_normal(pos,normal)
	for i in pairs(pos) do
		if normal[i]~=0 then pos[i]=0 end
	end
end

--calculate the facedir given the face and the clicked position
local function choose_slab_facedir(normal,p)
	if not(p and normal) then return 0 end
	
	remove_normal(p,normal) --ignore the "depth" of the point
	
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

--convert normal vector to box index
-- x-, y-, z-, x+, y+, z+
local function get_face(normal)
	local face=minetest.dir_to_facedir(normal,true)
	return ({[3]=1,[4]=2,[2]=3,[1]=4,[8]=5,[0]=6})[face]
end

local wallmounted_to_facedir={[2]=0,[3]=2,[4]=3,[5]=1}

local function match(name,groups,query)
	if query:sub(1,6)=="group:" then
		local level=groups[query:sub(7)]
		return level and level>0
	end
	return name==query
end

local function connects(connects_to,pos,opposite)
	local node=minetest.get_node(pos)
	local info=minetest.registered_nodes[node.name]
	if info then
		if info.connect_sides then
			local found
			for _,side in ipairs(info.connect_sides) do
				if side==opposite then
					found=true
					--I REALLY want to use goto here but I'm pretty sure this version of Lua doesn't have it
					--goto @found
					break
				end
			end
			if not found then return false end
			--return false
			--@found
		end
		
		for _,query in ipairs(connects_to) do
			if match(node.name,info.groups,query) then
				return true
			end
		end
	end
end

local function concat(array1,array2)
	local length=#array1
	for i,v in ipairs(array2) do
		array1[length+i]=v
	end
end

local connections={
	{pos={x=-1,y=0 ,z=0 },name="left"  ,opposite="right" },
	{pos={x=1 ,y=0 ,z=0 },name="right" ,opposite="left"  },
	{pos={x=0 ,y=-1,z=0 },name="bottom",opposite="top"   },
	{pos={x=0 ,y=1 ,z=0 },name="top"   ,opposite="bottom"},
	{pos={x=0 ,y=0 ,z=-1},name="front" ,opposite="back"  },
	{pos={x=0 ,y=0 ,z=1 },name="back"  ,opposite="front" },
}

--convert all box list formats into standard form
-- {x,y,z,x,y,z} -> {{x,y,z,x,y,z}}
-- nil -> {}
local function box_list(box_list)
	if not box_list then return {} end
	if type(box_list[1])=="number" then
		box_list={box_list}
	end
	return box_list
end

--input: position
--output: selection boxes, facedir
local function get_boxes(pos)
	local node=minetest.get_node(pos)
	local name=node.name
	local info=minetest.registered_nodes[name]
	if not info then return {-0.5,-0.5,-0.5,0.5,0.5,0.5},0 end
	
	local param2=0
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
	elseif info.selection_box.type=="connected" then
		local boxes=box_list(info.selection_box.fixed)
		--IMPORTANT: update this when v0.5.0.0 comes out!
		--adds `disconnected_` variants and `disconnected` and `disconnected_sides`
		for _,connection in ipairs(connections) do
			if connects(info.connects_to,vector.add(pos,connection.pos),connection.opposite) then
				local new_boxes=info.selection_box["connect_"..connection.name]
				concat(boxes,box_list(new_boxes))
			end
		end
		disp(boxes)
		return boxes,0
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

local function get_rotated_box(box,facedir)
	box=adjust_rotation(box,facedir%4)
	box=adjust_axis(box,math.floor(facedir/4))
	return box
end

local function get_surface_depth(box,face)
	local mul=1
	if face<=3 then
		mul=-1
	end
	return mul*box[face]
end

local function inside_box(box,point)
	return point.x>=box[1] and point.x<=box[4] and point.y>=box[2] and point.y<=box[5] and point.z>=box[3] and point.z<=box[6]
end

--This is the most important function
--It returns the exact location the player is pointing at,
--given the position of the node, the node it was placed onto, and the player
local function get_point(pos,placed_on,placer)
	local placer_pos=placer:get_pos()
	placer_pos.y=placer_pos.y+(placer:get_properties().eye_height or 1.625)
	local normal=get_normal(pos,placed_on)
	if vector.length(normal)~=1 then --unfixable :(
		tell(placer,"error: large selection box?")
		return normal
	end
	local look=placer:get_look_dir()
	local face=get_face(normal)
	local boxes,facedir=get_boxes(placed_on)
	--if there's a list with just 1 box
	if #boxes==1 then boxes=boxes[1] end
	--single box
	if type(boxes[1])=="number" then
		local surface=vector.add(placed_on,vector.multiply(normal,
			get_surface_depth(get_rotated_box(boxes,facedir),face)
		))
		local p=intersect(placer_pos,look,surface,normal)
		p=vector.subtract(p,placed_on) -- or p-surface instead...
		return normal,p
	--multiple boxes (aaaa)
	else
		local best=math.huge
		local best_p
		for i,box in ipairs(boxes) do
			box=get_rotated_box(box,facedir)
			--this can be simplified:
			local surface=vector.add(placed_on,vector.multiply(normal,get_surface_depth(box,face)))
			local p=intersect(placer_pos,look,surface,normal)
			p=vector.subtract(p,placed_on)
			if inside_box(box,p) then
				local dist=vector.distance(p,placer_pos)
				if dist<best then
					best=dist
					best_p=p
				end
			elseif not best_p then
				--
			end
		end
		return normal,best_p
		--tell(placer,"error: multiple selection boxes not supported")
	end
	return normal
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
	end,
	--allow other things to use these I guess
	get_point=get_point, 
	choose_log_facedir=choose_log_facedir,
	choose_slab_facedir=choose_slab_facedir,
	connects=connects,
	connections=connections,
}

dofile(minetest.get_modpath("place_rotated").."/items.lua")
dofile(minetest.get_modpath("place_rotated").."/wires.lua")