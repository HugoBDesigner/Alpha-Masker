require("util");

version = "0.1";

function love.load()
	windowW, windowH = love.window.getMode();
	
	margin = 16;
	checkerImg = love.graphics.newImage("checker.png");
	checkerImg:setFilter("nearest", "nearest");
	checkerImgW = checkerImg:getWidth();
	imgSlots = {};
	checkerCanvas = nil;
	
	backgroundColor = {1, 1, 1};
	foregroundColor = {.75, .75, .75};
	
	updateSlots();
	
	baseName = nil;
	alphaName = nil;
	
	baseImageData = nil;
	baseImagePreview = nil;
	
	alphaImageData = nil;
	alphaImagePreview = nil;
	
	renderedName = nil;
	renderedImageData = nil;
	renderedImagePreview = nil;
end

function love.draw()
	love.graphics.setColor(1, 1, 1);
	love.graphics.draw(checkerCanvas);
	
	if (baseImagePreview) then
		love.graphics.draw(baseImagePreview,
			imgSlots[1].x, imgSlots[1].y, 0, imgSlots[1].width/baseImagePreview:getWidth(), imgSlots[1].height/baseImagePreview:getHeight());
	end
	
	if (alphaImagePreview) then
		love.graphics.draw(alphaImagePreview,
			imgSlots[2].x, imgSlots[2].y, 0, imgSlots[2].width/alphaImagePreview:getWidth(), imgSlots[2].height/alphaImagePreview:getHeight());
	end
	
	if (renderedImagePreview) then
		love.graphics.draw(renderedImagePreview,
			imgSlots[3].x, imgSlots[3].y, 0, imgSlots[3].width/renderedImagePreview:getWidth(), imgSlots[3].height/renderedImagePreview:getHeight());
	end
end

function love.keypressed(key)
	if key == "s" then
		exportImage();
	end
end

function love.filedropped(file)
	local filename = file:getFilename();
	local ext = filename:match("%.%w+$");
	
	local mx, my = love.mouse.getPosition();
	local inDrop1 = aabb(mx, my, 1, 1, imgSlots[1].x, imgSlots[1].y, imgSlots[1].width, imgSlots[1].height);
	local inDrop2 = aabb(mx, my, 1, 1, imgSlots[2].x, imgSlots[2].y, imgSlots[2].width, imgSlots[2].height);
	
	local exts = {".jpg", ".jpeg", ".png", ".bmp", ".tga", ".hdr", ".pic", ".exr"};
	
	if (tableContains(exts, ext) and (inDrop1 or inDrop2)) then
		-- Valid image file format
		local name = string.sub(filename, 0, -string.len(ext)-1);
		print(name)
		repeat
			name = name:match("%\\.+$"):sub(2)
		until not name:match("\\");
		print(name)
		
		file:open("r");
		local fileData = file:read("data");
		local imgData = love.image.newImageData(fileData);
		imgData:mapPixel(
			function(x, y, r, g, b, a)
				return r, g, b, 1;
			end
		);
		
		if (inDrop1) then
			receiveBase(imgData, name);
		elseif (inDrop2) then
			receiveAlpha(imgData, name);
		end
	else
		print("Invalid image format");
	end
end

function love.resize(w, h)
	windowW, windowH = w, h;
	updateSlots();
end



function updateSlots()
	imgSlots = {};
	
	local fullWidth = windowW - margin*2;
	local fullHeight = windowH - margin*2;
	
	local bigSlotSize = math.floor( math.min(fullHeight, (fullWidth - margin/2) * 2/3) );
	local smallSlotSize = math.floor( bigSlotSize/2 - margin/2 );
	local allSlotsWidth = bigSlotSize + smallSlotSize + margin;
	local allSlotsHeight = bigSlotSize;
	
	imgSlots[1] = {
		x = math.floor(windowW/2 - allSlotsWidth/2),
		y = math.floor(windowH/2 - allSlotsHeight/2),
		width = smallSlotSize,
		height = smallSlotSize
	}
	imgSlots[2] = {
		x = math.floor(windowW/2 - allSlotsWidth/2),
		y = math.floor(windowH/2 + margin/2),
		width = smallSlotSize,
		height = smallSlotSize
	}
	imgSlots[3] = {
		x = math.floor(windowW/2 - allSlotsWidth/2 + smallSlotSize + margin),
		y = math.floor(windowH/2 - allSlotsHeight/2),
		width = bigSlotSize,
		height = bigSlotSize
	}
	
	checkerCanvas = love.graphics.newCanvas();
	love.graphics.setCanvas(checkerCanvas);
	do
		love.graphics.clear();
		for i, v in ipairs(imgSlots) do
			love.graphics.setColor(backgroundColor);
			love.graphics.rectangle("fill", v.x, v.y, v.width, v.height);
			
			love.graphics.setColor(foregroundColor);
			love.graphics.setScissor(v.x, v.y, v.width, v.height);
			for x = 0, math.ceil(v.width / checkerImgW) do
				for y = 0, math.ceil(v.height / checkerImgW) do
					love.graphics.draw(checkerImg, v.x + x*checkerImgW, v.y + y*checkerImgW, 0, 1, 1);
				end
			end
			love.graphics.setScissor();
		end
	end
	love.graphics.setCanvas();
end

function receiveBase(imgData, name)
	baseImageData = imgData;
	baseImagePreview = love.graphics.newImage(imgData);
	baseName = name;
	
	print("Received base");
	
	if (baseImageData and alphaImageData) then
		renderImage();
	end
end

function receiveAlpha(imgData, name)
	alphaImageData = imgData;
	alphaImagePreview = love.graphics.newImage(imgData);
	alphaName = name;
	
	print("Received alpha");
	
	if (baseImageData and alphaImageData) then
		renderImage();
	end
end

function renderImage()
	if (baseImageData and alphaImageData) then
		renderedImageData = love.image.newImageData(baseImageData:getWidth(), baseImageData:getHeight());
		
		local alphaWidth, alphaHeight = alphaImageData:getDimensions();
		
		renderedImageData:mapPixel(
			function(x, y)
				local r, g, b = baseImageData:getPixel(x, y);
				local r2, g2, b2 = 0, 0, 0;
				if (x < alphaWidth and y < alphaHeight) then
					r2, g2, b2 = alphaImageData:getPixel(x, y);
				end
				local a = (r2+g2+b2)/3;
				
				return r, g, b, a
			end
		)
		
		renderedImagePreview = love.graphics.newImage(renderedImageData);
		print("Produced render");
		
		-- exportImage();
	end
end

function exportImage(format, suffix)
	if (not renderedImageData) then
		return;
	end
	
	format = format or "tga"; -- TGA or PNG
	suffix = suffix or ""; -- "_base" or "_alpha"
	
	local filename = baseName;
	print(baseName);
	
	local add = "";
	local addN = 0;
	
	while (love.filesystem.getInfo(filename .. add .. suffix .. "." .. format, "file")) do
		print("Exists");
		addN = addN + 1;
		add = "000" .. addN;
		add = "_" .. add:sub(-4, -1);
	end
	
	renderedImageData:encode(format, filename .. add .. suffix .. "." .. format);
	love.system.openURL( "file://" .. love.filesystem.getSaveDirectory() );
end
