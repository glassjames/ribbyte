pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
local player
local gravity
local friction
local game_frame

-- pico-8 functions --

-- on cart start
function _init()
	-- clear screen
	cls()

	gravity = 0.1
	friction = 0.8

	game_frame = 0
	
	player = {
		-- sprite data
		sprite = 1,
		frame = 0,
		w = 8,
		h = 8,
		walking_sprites = {1, 23, 24},
		walking_sprite_ptr = 1,
		-- position
		pos_x = 72,
		pos_y = 8,
		-- change in position
		dx = 0,
		dy = 0,
		-- speed and acceleration
		max_speed = 1,
		max_air_speed = 3,
		acceleration = 0.4,
		air_acceleration = 0.9,
		slide_friction = 0.95,
		jump_boost = 2.5,
		-- states
		flip = false,
		is_jumping = false,
		is_falling = false,
		is_crouching = false,
		is_walking = false,
		is_ledge_falling = false,
		is_grounded = true,
		is_walking_into_wall = false,
		is_licky = false,
		----
		update = function(self)
			self.frame = iterate_frames(self.frame)

			---- constants
			self.apply_constants(self)
			
			---- inputs
			self.handle_inputs(self)

			---- move speed cap
			self.apply_speed_cap(self)

			-- debug
			self.log_states(self)
		end,
		draw = function(self)
			self.animate(self)
			spr(self.sprite, self.pos_x, self.pos_y, 1, 1, self.flip) 
		end,
		log_states = function(self)
			print(self.dx)
			print(self.dy)

			print(self.is_jumping)
			print(self.is_falling)
			print(self.is_ledge_falling)
			print(self.is_grounded)
		end,
		handle_inputs = function(self)
			if not self.is_crouching then
				-- left
				if btn(0) then
					self.dx -= self.acceleration
					self.flip = true
				end

				-- right
				if btn(1) then
					self.dx += self.acceleration
					self.flip = false
				end

				if btn(0) and btn(1) then
					self.dx = 0
				end
			end

			-- check for wall
			if not check_wall(self.pos_x + self.dx, self.pos_y) then
				self.pos_x += self.dx
			else
				self.dx = 0
			end 

			-- ground movement states
			self.is_walking = (btn(0) or btn(1)) and self.dx != 0
			self.is_walking_into_wall = (btn(0) or btn(1)) and not (btn(0) and btn(1)) and not self.walking
			

			-- jump (up) press; check to see if can jump
			if (jump_btnp() and not self.is_jumping and not self.is_falling and not self.is_ledge_falling) then
				self.dy -= self.air_acceleration * self.jump_boost
				self.is_jumping = true

				-- create land jump sprite
				create_jump_fx(self.pos_x, self.pos_y, self.flip)

			elseif (jump_btnp() and self.is_ledge_falling) then
				self.dy = - (self.air_acceleration * self.jump_boost)
				self.is_jumping = true
				self.is_ledge_falling = false

				-- create air jump sprite
				create_jump_fx(self.pos_x, self.pos_y, self.flip)
				create_air_jump_fx(self.pos_x, self.pos_y, self.flip)
			end

			-- air movement states
			if self.dy > 0 and self.is_jumping then
				self.is_jumping = false
				self.is_falling = true
			elseif self.dy >= 0.5 and not self.is_falling and not self.is_jumping then
				self.is_ledge_falling = true
			end

			-- check for floor
			if not check_wall(self.pos_x, self.pos_y + self.dy) then
				self.pos_y += self.dy
				self.is_grounded = false
			else
				self.dy = 0
				self.is_grounded = true
				self.is_falling = false
				self.is_ledge_falling = false
			end

			-- down
			self.is_crouching = (btn(3) and not self.is_jumping and not self.is_falling)
		end,
		animate = function(self)
			-- ground movement
			if self.is_grounded and not self.is_walking and not self.is_walking_into_wall then
				if self.frame > 29 then
					self.sprite = 2
				else
					self.sprite = 1
				end
			elseif self.is_walking then
				if self.frame % 3 == 0 then
					self.sprite = self.walking_sprites[self.walking_sprite_ptr]
					if self.walking_sprite_ptr < #self.walking_sprites then
						self.walking_sprite_ptr += 1
					else
						self.walking_sprite_ptr = 1
					end
				end
			elseif self.is_walking_into_wall then
				if self.frame > 49 then
					self.sprite = 20
				elseif self.frame > 29 then
					self.sprite = 21
				else
					self.sprite = 22
				end
			end

			-- jumping and falling
			if self.is_jumping then
				self.sprite = 3
			elseif self.is_falling then
				self.sprite = 4
			elseif self.is_ledge_falling then
				self.sprite = 5
			end

			--crouching
			if self.is_crouching then 
				self.sprite = 6
			end
		end,
		apply_constants = function(self)
			if not self.is_crouching then
				self.dx *= friction
			else
				self.dx *= self.slide_friction
			end

			self.dy += gravity
		end,
		apply_speed_cap = function(self)
			self.dx = mid(-self.max_speed, self.dx, self.max_speed)
			self.dy = mid(-self.max_air_speed, self.dy, self.max_air_speed)
		end
	}

	player_fx = {}
end 

-- update game state
function _update60()
	cls()
	map(0,0,0,0,16,16)
	game_frame = iterate_frames(game_frame)
	player:update()
	for fx in all(player_fx) do
		fx:update()
	end
end

-- draw to screen
function _draw() 
 	player:draw()
	for fx in all(player_fx) do
		fx:draw()
	end
end

-----
-- utility
function iterate_frames(f)
	-- update frame data
	if(f < 59) then
		f += 1
	else
		f = 0
	end

	return f
end

-- buttons
function jump_btnp()
	return (btnp(2) or btnp(4))
end

-- collisions
function check_flag(x, y, f)
	local x1 = x / 8
	local y1 = y / 8
	local x2 = (x + 7) / 8
	local y2 = (y + 7) / 8
	return fget(mget(x1, y1), f) or 
		   fget(mget(x1, y2), f) or 
		   fget(mget(x2, y2), f) or 
		   fget(mget(x2, y1), f)
end

function check_wall(x, y)
	return check_flag(x, y, 1)
end

-- fx
function create_jump_fx(pos_x, pos_y, flip)
	fx_jump = {
		pos_x = pos_x,
		pos_y = pos_y,
		sprites = {25, 26, 27},
		r_sprites = {},
		sprite = 25,
		flip = flip,
		update = function(self)
			if game_frame % 3 == 0 then
				if #self.sprites != 0 then
					self.sprite = self.sprites[1]
					add(self.r_sprites, self.sprite, 1)
					deli(self.sprites, 1)
				else 
					if #self.r_sprites != 0 then
						self.sprite = self.r_sprites[1]
						deli(self.r_sprites, 1)
					else
						del(player_fx, self)
					end
				end
			end
		end,
		draw = function(self)
			spr(self.sprite, self.pos_x, self.pos_y, 1, 1, self.flip)
		end
	}

	add(player_fx, fx_jump)
end

function create_air_jump_fx(pos_x, pos_y, flip)
	fx_air_jump = {
		pos_x = pos_x,
		pos_y = pos_y,
		sprites = {28, 29, 30},
		r_sprites = {},
		sprite = 28,
		flip = flip,
		update = function(self)
			if game_frame % 3 == 0 then
				if #self.sprites != 0 then
					self.sprite = self.sprites[1]
					add(self.r_sprites, self.sprite, 1)
					deli(self.sprites, 1)
				else 
					if #self.r_sprites != 0 then
						self.sprite = self.r_sprites[1]
						deli(self.r_sprites, 1)
					else
						del(player_fx, self)
					end
				end
			end
		end,
		draw = function(self)
			spr(self.sprite, self.pos_x, self.pos_y, 1, 1, self.flip)
		end
	}

	add(player_fx, fx_air_jump)
end

__gfx__
00000000000000000000000000bb0bb000bb0bb00000000000000000bbbbbbbb2222222200000000000000000000000000000000000000000000000000000000
0000000000bb0bb00000000003b1bb1b03b1bb1b00bb0bb000000000bbbbbbbb2222222200bb0bb0000000000000000000000000000000000000000000000000
0070070003b1bb1b00bb0bb00bbb82bb0bb8822b0bb1bb1b00bb0bb03b3b3b3b2222222203b1bb1b00bb0bb00000000000000000000000000000000000000000
000770000bb1bb1b03b1bb1b0bbbbbbb0bbbbbbb0bbb82bb03b1bb1bfbf3fbf3222222220bb1bb1b03b1bb1b0000000000000000000000000000000000000000
000770000bbb82bb0bbb82bb0bb3b3bb0bb3b3bb0bbbbbbb0bb8822bf3fff3ff222222220bbb82bb0bbb82bb0000000000000000000000000000000000000000
0070070033bbbbbb33bbbbbb03bbbbb303bbbbb30bb3bb3b0bbbbbbbffffffff2222222203bbbbbb03bbbbbb0000000000000000000000000000000000000000
0000000033bbbbb333bbbbb303bbbbb303bbbbb303bbbbb30bb3bb3bffffffff2222222203bbbbb303bbbbb30000000000000000000000700000007000000070
0000000003b3b3b303b3b3b303000003030000030000000003bbbbb3ffffffff22222222303b3b30303b3b300000000500000065000007650000076000000700
000000000000000000000000000000000000000000000000000000000bb0bb0000bb0bb000000000000000000000000000000000000000000000000000000000
00bb0bb000bb0bb000bb0bb000088000000bb0bb00000000000bb0bb0b1bb1b003b1bb1b00000000000000000000000000000000000000000000000000000000
03b1bb1b03b1bb1b03b1bb1b00888800003b1bb1000bb0bb003bbbbbbb1bb1b00bb1bb1b00000000000000000000000000000000000000000000000000000000
0bb1bb1b0bb1221b0bb1221b0888882000bb1bb1003bbbbb00bb1bb1bbb82bb00bbb82bb00000000000000000000000000000000000000000000000000000000
0bbb82bb0bbb82bb0bbb88880288882000bbb82b00bb11b100bb1bb1bbbbbbb033bbbbbb00000000000000000000000000000000000000000000000000000000
33bbbbbb33bb88bb33bb82bb0028820003bbbbbb00bbb82b03bbb82b33bbbbb333bbbbb300000000000000000007000000000000000000000000000000000000
33bbbbb333bbbbb333bbbbb30002200033bbbbbb033bbbbb33bbbbbb33b3b3b330b3b3b000000000000660000006600000600600076006707650056700000000
03b3b3b303b3b3b303b3b3b300000000303b3b303303b3b3303b3b30300000000000000000766700007667000076670000000000007667000765567000000000
__gff__
0000000000000002ff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000070000000000070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000007070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000707070707070707070707000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0007000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000070000070700070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000070707070707070707070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0004000000000350503505035050350503405033050310502f0502e0502b0502a0502605024050220501e0501a0501605013050100500f0500f0500e0500f0500000000000000000000000000000000000000000
