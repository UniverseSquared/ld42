local Timer = require("timer")
local sw,sh=love.graphics.getDimensions()
local d={
	right=1,
	left=2,
	up=3
}
local PLATFORM_WIDTH,PLATFORM_HEIGHT=50,520
local platforms = {
	{
		x = sw/2-100,
		y = 0,
		s = d.left,
	},
	{
		x = sw/2+100,
		y = 0,
		s = d.right
	}
}
local SPIKE_WIDTH,SPIKE_HEIGHT=35,35
local level={}
local player = {
	x = 0,
	y = 460,
	w = 32,
	h = 32,
	d=d.left,
	speed = 500,
	yspeed=0.75,
	canmove=true,
	score=0
}
local gameover=false
local shouldWriteScore=true
local currentLevel=nil
local section=1
local gameovermsg="Game over!"
local states={
	menu=1,
	game=2,
	gameover=3,
	tutorial=4,
	levelcomplete=5,
	skinselect=6,
	levelselect=7
}
local state=states.menu
local mainmenu={
	{
		label="Start",
		callback=function() levelselect=1 state=states.levelselect end
	},
	{
		label="Skin Select",
		callback=function() state=states.skinselect end
	},
	{
		label="Tutorial",
		callback=function() state=states.tutorial end
	},
	{
		label="Exit",
		callback=function() love.event.quit() end
	}
}
local menuselect=1
local hiscore=0
local skins = {}
local currentSkin = "default"
local PLAYER_DRAW_SCALE=0.5
local skinmenuselect=1
local skinmenuname=nil
local ITEM_WIDTH,ITEM_HEIGHT=32,32
local platformsFrozen=false
local items={
	{
		color={ 31, 111, 239 },
		oncollect=function()
			platformsFrozen=true
			t:after(0.5, function() platformsFrozen=false end)
		end
	}
}
local levelselect=1
local tutorial="Welcome to Space, Spike, Squid! You, the devilishly handsome squid, must escape from the terrible tower you have found yourself in! You must jump from pillar to pillar with the arrow keys to avoid spikes and collect items to aid on your journey."
local paused=false

function player:touching()
	if self.x+self.w>=platforms[2].x then
		return d.right
	elseif self.x<=platforms[1].x+PLATFORM_WIDTH then
		return d.left
	else
		return 0
	end
end

function player:isTouching(p)
	return self:touching() == p
end

function generateLevel(spikeMin, spikeMax)
	local level={
		spikes={},
		platformSpeed=1
	}

	local spikenum=love.math.random(spikeMin, spikeMax)
	for i=1,spikenum do
		local s=love.math.random(1,2)
		local y=love.math.random(1,PLATFORM_HEIGHT-(player.w*3))
		table.insert(level.spikes, {
			s=s,
			y=y
		})
	end

	return level
end

function split(s, sep)
	local sep, fields = sep, {}
	local pattern = string.format("([^%s]+)", sep)
	s:gsub(pattern, function(c) table.insert(fields, c) end)
	return fields
end

function capitalize(s)
	return s:sub(1,1):upper() .. s:sub(2)
end

function loadLevel(levelname)
	local level = {}
	local path = nil

	if love.filesystem.getInfo("levels/" .. levelname .. ".lvl") == nil then
		if love.filesystem.getInfo("custom-levels/" .. levelname .. ".lvl") == nil then
			error("No such level!")
		else
			path="custom-levels/" .. levelname .. ".lvl"
		end
	else
		path="levels/" .. levelname .. ".lvl"
	end

	local section=0
	local lines = {}
	for line in love.filesystem.lines(path) do
		table.insert(lines, line)
	end

	for i=1,#lines do
		local line=lines[i]
		if i==1 then
			local info=split(line, " ")
			level.platformSpeed=tonumber(info[1])
			level.playerVSpeed=tonumber(info[2])
		else
			if line == "SECTION" then
				section=section+1
				table.insert(level, { spikes={}, items={} })
			else
				local data = split(line, " ")
				if data[1] == "SPIKE" then
					local s, y = tonumber(data[2]), tonumber(data[3])
					table.insert(level[section].spikes, { s=s, y=y })
				elseif data[1] == "ITEM" then
					local id, s, y = tonumber(data[2]), tonumber(data[3]), tonumber(data[4])
					table.insert(level[section].items, { id=id, s=s, y=y })
				end
			end
		end
	end

	return level
end

function resetLevel()
	level=loadLevel(currentLevel)
	platformsFrozen=false
	player.score=0
	gameover=false
	player.x=(platforms[2].x+(platforms[1].x+PLATFORM_WIDTH))/2-(player.w/2)
	player.y=460
	section=1
	platforms = {
		{
			x = sw/2-(50+PLATFORM_WIDTH),
			y = 0,
			s = d.left,
		},
		{
			x = sw/2+(50+PLATFORM_WIDTH),
			y = 0,
			s = d.right
		}
}
end

function len(a)
	local l=0
	for k,v in pairs(a) do l = l + 1 end
	return l
end

function cprint(t,y,scale)
	scale=scale or 1
	love.graphics.print(t,(love.graphics.getWidth()/2)-(font:getWidth(t)*scale/2),y,0,scale)
end

function getHiScore()
	if love.filesystem.getInfo("hiscore")~=nil then
		local data = love.filesystem.read("hiscore")
		return tonumber(data)
	end
	return 0
end

function changeSkin(name, dir)
	dir=dir or player.d
	currentSkin = name
	player.w = skins[currentSkin][dir]:getWidth() * PLAYER_DRAW_SCALE
	player.h = skins[currentSkin][dir]:getHeight() * PLAYER_DRAW_SCALE
	player.d=dir
end

function getLevels()
	local d=love.filesystem.getInfo("custom-levels")
	if not d or d~="directory" then
		love.filesystem.createDirectory("/custom-levels")
	end
	local levels=love.filesystem.getDirectoryItems("levels")
	local customs=love.filesystem.getDirectoryItems("custom-levels")
	for k,v in pairs(customs) do table.insert(levels,v) end
	return levels
end

function love.load()
	font=love.graphics.getFont()
	player.x=(platforms[2].x+(platforms[1].x+PLATFORM_WIDTH))/2-(player.w/2)
	hiscore=getHiScore()

	levels=getLevels()

	bgTexture=love.graphics.newImage("assets/background.png")
	spikeTextures={}
	spikeTextures[d.right]=love.graphics.newImage("assets/spike-right.png")
	spikeTextures[d.left]=love.graphics.newImage("assets/spike-left.png")
	pillarTextures={}
	pillarTextures[d.right]=love.graphics.newImage("assets/pillar-right-extended.png")
	pillarTextures[d.left]=love.graphics.newImage("assets/pillar-left-extended.png")

	jumpSound=love.audio.newSource("assets/jump.wav", "static")

	t = Timer()
	t:every(0.3, function()
		if not gameover and state==states.game and not platformsFrozen then
			platforms[1].x = platforms[1].x + level.platformSpeed
			platforms[2].x = platforms[2].x - level.platformSpeed
			player.score=player.score+10
		end
	end)

	for k, skin in pairs(love.filesystem.getDirectoryItems("skins")) do
		local skinname = skin:sub(1, -5)
		local name, dir = skin:match("^(.+)-(.+).png$")
		if name == nil then error(skin) end
		if skins[name] == nil then
			skins[name] = {}
		end
		skins[name][d[dir]] = love.graphics.newImage("skins/" .. skin)
	end

	changeSkin("default")
end

function love.update(dt)
	if paused then return end
	t:update(dt)
	if state==states.game then
		if love.keyboard.isDown("q") then
			love.event.quit()
		elseif love.keyboard.isDown("escape") then
			state=states.menu
			menuselect=1
		end
		if not gameover then

			if (platforms[2].x)-(platforms[1].x+PLATFORM_WIDTH)<=player.w then
				gameover=true
			end

			if player.d==d.right then
				if player:isTouching(d.right) then
					player.canmove=true
					player.x=platforms[2].x-player.w
				else
					player.canmove=false
					player.x=player.x+player.speed*dt
				end
			elseif player.d==d.left then
				if player:isTouching(d.left) then
					player.canmove=true
					player.x=platforms[1].x+PLATFORM_WIDTH
				else
					player.canmove=false
					player.x=player.x-player.speed*dt
				end
			end

			for k, s in pairs(level[section].spikes) do
				local x = nil
				if s.s==d.left then
					x=platforms[1].x+PLATFORM_WIDTH
				elseif s.s==d.right then
					x=platforms[2].x-SPIKE_WIDTH
				end
				local y=s.y
				if (player.x>=x and player.x<=x+SPIKE_WIDTH
					and player.y>=y and player.y<=y+SPIKE_HEIGHT)
					or (player.x+player.w>=x and player.x+player.w<=x+SPIKE_WIDTH
					and player.y+player.h>=y and player.y+player.h<=y+SPIKE_HEIGHT) then
					gameover=true
				end
				local gx,gy,gw,gh=platforms[1].x+PLATFORM_WIDTH,0,(platforms[2].x)-(platforms[1].x+PLATFORM_WIDTH),20
				if player.x>=gx and player.x+player.w<=gx+gw
					and player.y>=gy and player.y<=gy+gh then
					if section==#level then
						state=states.levelcomplete
					else
						section=section+1
						player.x=(platforms[2].x+(platforms[1].x+PLATFORM_WIDTH))/2-(player.w/2)
						player.y=460
					end
				end
				player.y=player.y-level.playerVSpeed*dt
			end

			for k, i in pairs(level[section].items) do
				local item=items[i.id]
				local x = nil
				if i.s==d.left then
					x=platforms[1].x+PLATFORM_WIDTH
				elseif i.s==d.right then
					x=platforms[2].x-ITEM_WIDTH
				end

				if player.x>=x and player.x+player.w<=x+ITEM_WIDTH
					and math.floor(player.y)>=i.y and math.floor(player.y)+player.h<=i.y+ITEM_HEIGHT then
					item.oncollect()
					table.remove(level[section].items, k)
					break
				end
			end
		end
	elseif state==states.levelcomplete then
		if love.keyboard.isDown("return") or love.keyboard.isDown("escape") then
			player.score=0
			state=states.menu
		end
	end
end

function love.keypressed(key, scancode, isrepeat)
	if state==states.menu then
		if key=="up" then
			menuselect=menuselect-1
		elseif key=="down" then
			menuselect=menuselect+1
		elseif key=="return" then
			mainmenu[menuselect].callback()
		end

		if menuselect>#mainmenu then menuselect=1
		elseif menuselect<1 then menuselect=#mainmenu end
	elseif state==states.tutorial then
		if key=="escape" or key=="return" then
			state=states.menu
		end
	elseif state==states.skinselect then
		if key=="escape" or key=="return" then
			state=states.menu
		end
		if key=="up" then
			skinmenuselect=skinmenuselect-1
		elseif key=="down" then
			skinmenuselect=skinmenuselect+1
		elseif key=="return" then
			changeSkin(skinmenuname)
		end

		if skinmenuselect>len(skins) then skinmenuselect=1
		elseif skinmenuselect<1 then skinmenuselect=len(skins) end
	elseif state==states.levelselect then
		if key=="escape" then
			state=states.menu
		end
		if key=="up" then
			levelselect=levelselect-1
		elseif key=="down" then
			levelselect=levelselect+1
		elseif key=="return" then
			currentLevel=split(levels[levelselect],".")[1]
			resetLevel()
			state=states.game
		end

		if levelselect>#levels then levelselect=1
		elseif levelselect<1 then levelselect=#levels end
	elseif state==states.game then
		if key=="p" then paused=not paused end
		
		if player.canmove then
			if key=="left" then
				jumpSound:play()
				changeSkin(currentSkin, d.left)
			elseif key=="right" then
				jumpSound:play()
				changeSkin(currentSkin, d.right)
			end
		end
	end
end

function love.draw()
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(bgTexture, 0, 0)

	if state==states.menu then
		love.graphics.setColor(1,1,1)
		cprint("Space, Spike, Squid", 20, 1.5)
		local w=love.graphics.getWidth()
		local m=w/2
		local bw,bh=100,30
		local bvo=50
		for i=1,#mainmenu do
			if i==menuselect then
				love.graphics.setColor(1,60/255,60/255)
			else
				love.graphics.setColor(1,1,1)
			end
			love.graphics.rectangle("fill",m-bw/2,((i*bh)+bvo)*1.5,bw,bh)
			love.graphics.setColor(0,0,0)
			cprint(mainmenu[i].label, ((i*bh)+bvo)*1.5+10, 1)
		end
		love.graphics.setColor(1,1,1)
		cprint("Current hi score: " .. hiscore,love.graphics.getHeight()-(20+font:getHeight()))
	elseif state==states.game then
		love.graphics.setColor(1, 1, 1, 1)
		cprint("Score: " .. player.score, 550)
		love.graphics.setColor(1,1,1,1)
		love.graphics.draw(skins[currentSkin][player.d], player.x, player.y, 0, PLAYER_DRAW_SCALE, PLAYER_DRAW_SCALE)

		love.graphics.setColor(1,1,1)
		for k, p in pairs(platforms) do
			love.graphics.draw(pillarTextures[p.s], p.x, p.y)
		end

		love.graphics.setColor(1,1,1,1)
		for k, s in pairs(level[section].spikes) do
			local x = nil
			if s.s==d.left then
				x=platforms[1].x+PLATFORM_WIDTH
			elseif s.s==d.right then
				x=platforms[2].x-SPIKE_WIDTH
			end
			love.graphics.draw(spikeTextures[s.s], x, s.y, 0, 0.5, 0.5)
		end

		for k, i in pairs(level[section].items) do
			local item=items[i.id]
			local c=item.color
			love.graphics.setColor(c[1]/255,c[2]/255,c[3]/255)
			local x = nil
			if i.s==d.left then
				x=platforms[1].x+PLATFORM_WIDTH
			elseif i.s==d.right then
				x=platforms[2].x-ITEM_WIDTH
			end
			love.graphics.rectangle("fill",x,i.y,ITEM_WIDTH,ITEM_HEIGHT)
			love.graphics.setColor(1,1,1,1)
			love.graphics.print(x..","..i.y..","..player.x..","..player.y, 5,love.graphics.getHeight()-20)
		end

		love.graphics.setColor(0,1,0)
		love.graphics.rectangle("fill",platforms[1].x+PLATFORM_WIDTH,0,(platforms[2].x)-(platforms[1].x+PLATFORM_WIDTH),20)

		love.graphics.setColor(1,0,0)
		if gameover then
			cprint("Game Over!", 560)
			if shouldWriteScore then
				shouldWriteScore=false
				if player.score > hiscore then
					gameovermsg=gameovermsg.."\nNew hi score: " .. player.score
					love.filesystem.write("hiscore", tostring(player.score))
					hiscore=player.score
				else
					gameovermsg=gameovermsg.."\nCurrent hi score: " .. player.score
				end
			end
		end
	elseif state==states.tutorial then
		love.graphics.setColor(1,1,1)
		love.graphics.printf(tutorial, 20, 20, love.graphics.getWidth()-40)
		love.graphics.print("Press escape to return.", 20, love.graphics.getHeight()-(20+font:getHeight()))
	elseif state==states.levelcomplete then
		cprint("Level complete!", 50, 1.5)
		cprint("Score: " .. player.score, 75)
		cprint("Hi score: " .. hiscore, 95)
		cprint("Press return or escape to return to the menu.", 120, 1)
		if shouldWriteScore then
			shouldWriteScore=false
			if player.score > hiscore then
				love.filesystem.write("hiscore", tostring(player.score))
				hiscore=player.score
			end
		end
	elseif state==states.skinselect then
		local ty=30
		local i=1
		for k, v in pairs(skins) do
			if skinmenuselect==i then
				skinmenuname=k
				love.graphics.draw(v[d.up],100,30)
				love.graphics.setColor(1, 0, 0, 1)
			else
				love.graphics.setColor(1, 1, 1, 1)
			end
			love.graphics.print(k, 20, ty*1.5)
			ty = ty + font:getHeight() + 5
			i=i+1
		end
	elseif state==states.levelselect then
		love.graphics.setColor(1,1,1,1)
		love.graphics.print("Press escape to return to the menu.", 20, love.graphics.getHeight()-40)
		local ty=30
		for i=1,#levels do
			local name=capitalize(split(levels[i],".")[1]:gsub("-"," "))
			if levelselect==i then
				love.graphics.setColor(1,0,0,1)
			else
				love.graphics.setColor(1,1,1,1)
			end
			love.graphics.print(name,20,ty)
			ty=ty+font:getHeight()+5
		end
	end
end
