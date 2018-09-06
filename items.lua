-- Debug
local function disp(x)
	minetest.chat_send_all(dump(x))
end

--example slab
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
	on_place=place_rotated.slab,
})

--example log
minetest.register_node("place_rotated:test_tree",{
	description="Test Tree",
	tiles={"test_log.png","test_log.png","test_bark.png"},
	paramtype2="facedir",
	groups={dig_immediate=3},
	on_place=place_rotated.log,
})

minetest.register_node("place_rotated:test_diagram",{
	description="Test Diagram",
	tiles={"test_diagram.png"},
	groups={dig_immediate=3},
})

--level + ruler
minetest.register_craftitem("place_rotated:level",{
	description="Level (left click = check rotation, right click = get point)",
	inventory_image="test_level.png",
	wield_image="test_level.png^[transformR270",
	liquids_pointable=true,
	--left click: get rotation data from node
	on_use=function(_,user,pointed_thing)
		local user_name=user:get_player_name()
		if pointed_thing.ref then
			minetest.chat_send_player(user_name,pointed_thing.ref:get_properties().wield_item)
		elseif pointed_thing.under then
			local node=minetest.get_node(pointed_thing.under)
			minetest.chat_send_player(user_name,"Node \""..node.name.."\" at "..minetest.pos_to_string(pointed_thing.under))
			local node_info=minetest.registered_nodes[node.name]
			if node_info then
				if node_info.paramtype2=="wallmounted" then
					minetest.chat_send_player(user_name,"Facing: "..(({[0]="y-","Y+","x-","X+","z-","Z+"})[node.param2]))
				elseif node_info.paramtype2=="facedir" then
					minetest.chat_send_player(user_name,"Axis: "..(({[0]="Y+","Z+","z-","X+","x-","y-"})[math.floor(node.param2/4)]))
					minetest.chat_send_player(user_name,"Rotation: "..(node.param2%4*90).."°")
				else
					minetest.chat_send_player(user_name,"(no rotation)")
				end
			end
		end
	end,
	--right click: measure location of clicked point
	on_place=function(_,placer,pointed_thing)
		local user_name=placer:get_player_name()
		local normal,p = place_rotated.get_point(pointed_thing.above,pointed_thing.under,placer)
		if p then
			minetest.chat_send_player(user_name,"Position within node:")
			minetest.chat_send_player(user_name,"X: "..p.x)
			minetest.chat_send_player(user_name,"Y: "..p.y)
			minetest.chat_send_player(user_name,"Z: "..p.z)
		else
			minetest.chat_send_player(user_name,"Could not get point")
		end
	end,
})