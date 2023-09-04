json = require("json");
require("util");

version = "0.2";
love.window.setTitle(love.window.getTitle() .. " v" .. version);

function love.load()
	windowWidth, windowHeight, windowFlags = love.window.getMode();
	
	_SETTINGS_FILENAME = "settings.json";
	_IMAGES_FOLDER = "images";
	love.filesystem.createDirectory(_IMAGES_FOLDER);
	
	settingsMenu = {
		{text = "[F1] - Hide settings", type = "label"},
		{text = "[Arrow Keys] - Navigate settings", type = "label"},
		
		{text = "", type = "label"},
		
		{text = "Alternate Mode", 			type = "boolean", 	var = "alternateMode"},
		{text = "Export Format", 			type = "list", 		var = "exportFormat"},
		{text = "Alpha Mask Fill Mode", 	type = "list", 		var = "alphaFillMode"},
		{text = "Render Mode", 				type = "list", 		var = "combinedRenderMode"},
		
		{text = "", type = "label"},
		
		{text = "Shortcuts:", type = "label"},
		{text = "\t[S] - Quick export processed images", type = "label"},
		{text = "\t[O] - Open the processed images folder", type = "label"},
		{text = "\t[Tab] - Alternate the image processing mode", type = "label"},
		
		["visible"] = false,
		["selected"] = 1,
		["maxSelected"] = 0,
	}
	for i, v in ipairs(settingsMenu) do
		if (v.type ~= "label") then
			settingsMenu.maxSelected = settingsMenu.maxSelected + 1;
		end
	end
	
	alternateMode = false;
	exportFormat = util.makeList("tga", "png"):appendReference("TGA", "PNG");
	
	alphaFillMode = util
		.makeList		("stretch", "repeat", "fill_opaque",   "fill_transparent",   "fill_repeat")
		:appendReference("Stretch", "Repeat", "Fill (Opaque)", "Fill (Transparent)", "Fill (Repeat Edges)");
	
	combinedRenderMode = util
		.makeList		("transparent_light",   "transparent_dark",   "alpha_mask",           "premultiplied", "selfillum")
		:appendReference("Transparent (Light)", "Transparent (Dark)", "Highlight Alpha Mask", "Premultiplied", "Emissive ($selfillum)");
	
	readSettings();
	
	backgroundColor = {41/255, 49/255, 52/255}
	
	backgroundLightColor = {1, 1, 1};
	foregroundLightColor = {.75, .75, .75};
	backgroundDarkColor = {.1, .1, .1};
	foregroundDarkColor = {.25, .25, .25};
	alphaMaskColor = {1, 0, 0, .5};
	selfillumMaskOpacity = .75;
	
	margin = 16;
	checkerImg = love.graphics.newImage("checker.png");
	checkerImg:setFilter("nearest", "nearest");
	checkerImgW = checkerImg:getWidth();
	
	dropImg = love.graphics.newImage("drop.png");
	dropImg:setFilter("linear", "linear");
	
	trashImg = love.graphics.newImage("trash.png");
	trashImg:setFilter("linear", "linear");
	
	downloadImg = love.graphics.newImage("download.png");
	downloadImg:setFilter("linear", "linear");
	
	--[[
	local cursorGradientImgData = love.image.newImageData(512, 512);
	cursorGradientImgData:mapPixel(
		function(x, y)
			local dist = math.sqrt((x - 256)^2 + (y-256)^2);
			dist = dist / 256;
			local val = 1-math.max(0, math.min(1, dist));
			
			return 0, 0, 0, 1-val;
		end
	);
	cursorGradientImgData:encode("png", "gradient.png");
	]]
	cursorGradientImg = love.graphics.newImage("gradient.png");
	cursorGradientImg:setFilter("linear", "linear");
	
	imgSlots = {};
	checkerCanvas = nil;
	
	font = nil;
	settingsTabHeight = 0;
	
	updateSlots();
	
	baseName = nil;
	alphaName = nil;
	
	baseImageData = nil;
	baseImagePreview = nil;
	
	alphaImageData = nil;
	alphaImagePreview = nil;
	
	combinedName = nil;
	combinedImageData = nil;
	combinedImagePreview = nil;
	
	love.graphics.setBackgroundColor(backgroundColor);
end

function love.draw()
	love.graphics.setColor(1, 1, 1);
	love.graphics.draw(checkerCanvas);
	
	local imgs = {baseImagePreview, alphaImagePreview, combinedImagePreview};
	
	local texts = {"Base Image", "Alpha Image", "Combined Image"};
	for i, v in ipairs(imgSlots) do
		if (imgs[i]) then
			if (i == 3) then -- Only the combined view uses all this fancy tech
				-- combinedRenderMode = {"transparent_light", "transparent_dark", "alpha_mask", "premultiplied", "selfillum"};
				if (combinedRenderMode.current == "alpha_mask" or combinedRenderMode.current == "selfillum") then
					love.graphics.setColor(1, 1, 1, 1);
					love.graphics.draw(baseImagePreview,
						v.x, v.y, 0, v.width/baseImagePreview:getWidth(), v.height/baseImagePreview:getHeight());
					
					if (combinedRenderMode.current == "alpha_mask") then
						love.graphics.setColor(alphaMaskColor);
						love.graphics.rectangle("fill", v.x, v.y, v.width, v.height);
					elseif (combinedRenderMode.current == "selfillum") then
						-- TO-DO: should this only happen when the mouse is held?
						if (love.mouse.isDown(1)) then
							love.graphics.setScissor(v.x, v.y, v.width, v.height);
							
							local px, py = love.mouse.getPosition();
							local pwidth, pheight = v.width*2, v.height*2;
							-- local pwidth, pheight = v.width, v.height;
							
							love.graphics.setColor(0, 0, 0, selfillumMaskOpacity);
							love.graphics.rectangle("fill", 0, 0, px - pwidth/2, windowHeight);
							love.graphics.rectangle("fill", px - pwidth/2, 0, pwidth, py - pheight/2);
							love.graphics.rectangle("fill", px - pwidth/2, py + pheight/2, pwidth, windowHeight - (py + pheight/2));
							love.graphics.rectangle("fill", px + pwidth/2, 0, windowWidth - (px + pwidth/2), windowHeight);
							
							love.graphics.setColor(1, 1, 1, selfillumMaskOpacity)
							love.graphics.draw(cursorGradientImg, px - pwidth/2, py - pheight/2, 0, pwidth/cursorGradientImg:getWidth(), pheight/cursorGradientImg:getHeight());
							
							love.graphics.setScissor();
						else
							love.graphics.setColor(0, 0, 0, selfillumMaskOpacity);
							love.graphics.rectangle("fill", v.x, v.y, v.width, v.height);
						end
					end
				end
			end
			
			love.graphics.setColor(1, 1, 1, 1);
			love.graphics.draw(imgs[i],
				v.x, v.y, 0, v.width/imgs[i]:getWidth(), v.height/imgs[i]:getHeight());
		end
		
		local dropSpot;
		if (alternateMode) then
			dropSpot = (i == 3);
		else
			dropSpot = (i < 3);
		end
		
		if (dropSpot) then
			if (not imgs[i]) then
				love.graphics.setColor(.5, .5, .5, .75);
				love.graphics.draw(dropImg, v.x, v.y, 0, v.width/dropImg:getWidth(), v.height/dropImg:getHeight());
			end
		end
			
		for j, w in ipairs(v.buttons) do
			love.graphics.setColor(0, 0, 0, .75);
			if (w.isActive() == false) then
				love.graphics.setColor(.25, .25, .25, .75);
			end
			love.graphics.rectangle("fill", w.x, w.y, w.width, w.height);
			love.graphics.setColor(0, 0, 0, 1);
			if (w.isActive() == false) then
				love.graphics.setColor(0, 0, 0, .5);
			end
			love.graphics.rectangle("line", w.x+.5, w.y+.5, w.width-1, w.height-1);
			love.graphics.setColor(1, 1, 1, 1);
			if (w.isActive() == false) then
				love.graphics.setColor(.75, .75, .75, .5);
			elseif (w.color) then
				love.graphics.setColor(w.color);
			end
			love.graphics.draw(w.image, w.x, w.y, 0, w.width/w.image:getWidth(), w.height/w.image:getHeight());
		end
		
		local text = texts[i];
		text = " " .. text .. " ";
		local textHeight = font:getHeight();
		local textWidth = font:getWidth(text);
		love.graphics.setColor(0, 0, 0, .75);
		love.graphics.rectangle("fill", v.x, v.y + v.height - textHeight, textWidth, textHeight);
		love.graphics.setColor(1, 1, 1, 1);
		love.graphics.print(text, v.x, v.y + v.height - textHeight);
	end
	
	if (settingsMenu.visible) then
		love.graphics.setColor(0, 0, 0, .85);
		love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight);
		local _idx = 0;
		for i, v in ipairs(settingsMenu) do
			local label = v.text;
			local selected = false;
			local px, py = margin, margin/2 + (i-1)*font:getHeight();
			
			if (v.type == "label") then
				love.graphics.setColor(1, 1, 1, 1);
			else
				_idx = _idx + 1;
				love.graphics.setColor(.75, .75, .75, 1);
				label = v.text .. ": ";
				if (_idx == settingsMenu.selected) then
					selected = true;
					
					label = "• " .. label;
					love.graphics.print(label, px+.5, py+.5);
					love.graphics.setColor(1, 1, 1, 1);
				end
			end
			love.graphics.print(label, px, py);
			
			if (v.type ~= "label") then
				px = px + font:getWidth(label) + margin;
				local text = "";
				local var = _G[v.var];
				
				if (v.type == "boolean") then
					text = text .. (var == true and "ON" or "OFF");
				elseif (v.type == "list") then
					text = text .. var.currentReference;
				end
				
				if (selected) then
					text = "< " .. text .. " >";
				end
				love.graphics.print(text, px, py);
			end
		end
	else
		love.graphics.setColor(0, 0, 0, .85);
		love.graphics.rectangle("fill", 0, 0, windowWidth, settingsTabHeight);
		love.graphics.setColor(1, 1, 1, 1);
		love.graphics.print("[F1] - Show settings", margin, margin/2);
	end
end

function love.keypressed(key)
	if (key == "f1") then
		settingsMenu.visible = not settingsMenu.visible;
	elseif (key == "esc" or key == "escape") then
		settingsMenu.visible = false;
	elseif (settingsMenu.visible == false) then
		if (key == "s") then
			if (alternateMode) then
				exportImage(baseImageData, exportFormat.current, "_base", true);
				exportImage(alphaImageData, exportFormat.current, "_alpha");
			else
				exportImage(combinedImageData, exportFormat.current);
			end
		elseif (key == "o") then
			openImagesFolder();
		elseif (key == "tab") then
			alternateMode = not alternateMode;
			saveSettings();
			updateSlots();
		end
	elseif (settingsMenu.visible == true) then
		if (key == "up") then
			settingsMenu.selected = (settingsMenu.selected == 1 and settingsMenu.maxSelected or settingsMenu.selected-1);
		elseif (key == "down") then
			settingsMenu.selected = (settingsMenu.selected == settingsMenu.maxSelected and 1 or settingsMenu.selected+1);
		elseif (key == "left" or key == "right") then
			local _idx = 0;
			for i, v in ipairs(settingsMenu) do
				if (v.type ~= "label") then
					_idx = _idx + 1;
					if (_idx == settingsMenu.selected) then
						
						if (v.type == "boolean") then
							_G[v.var] = not _G[v.var];
						elseif (v.type == "list") then
							local var = _G[v.var];
							if (key == "left") then
								var:previous();
							else
								var:next();
							end
							
							-- Making an exception for these options because it is useful to see some settings change in real time
							if (v.var == "alphaFillMode" and not alternateMode) then
								renderCombinedImage();
							end
						end
						
						updateSlots();
						saveSettings();
						break;
					end
				end
			end
		end
	end
end

function love.mousepressed(x, y, button)
	if (button == 1) then
		for i, v in ipairs(imgSlots) do
			for j, w in ipairs(v.buttons) do
				if ( w.isActive() and util.aabb(x, y, 1, 1, w.x, w.y, w.width, w.height) and w.callback ) then
					w.callback();
				end
			end
		end
	end
end

function love.filedropped(file)
	local filename = file:getFilename();
	local ext = filename:match("%.%w+$");
	
	local exts = {".jpg", ".jpeg", ".png", ".bmp", ".tga", ".hdr", ".pic", ".exr"};
	
	if (table.contains(exts, ext)) then
		-- Valid image file format
		
		local mx, my = love.mouse.getPosition();
		for i, v in ipairs(imgSlots) do
			if (v.validDrop and util.aabb(mx, my, 1, 1, v.x, v.y, v.width, v.height) ) then
				local name = string.sub(filename, 0, -string.len(ext)-1);
				print(name)
				repeat
					name = name:match("%\\.+$"):sub(2)
				until not name:match("\\");
				print(name)
				
				file:open("r");
				local fileData = file:read("data");
				local imgData = love.image.newImageData(fileData);
				
				if (i == 1) then
					receiveBase(imgData, name);
				elseif (i == 2) then
					receiveAlpha(imgData, name);
				elseif (i == 3) then
					receiveCombined(imgData, name);
				end
			end
		end
	else
		print("Invalid image format");
	end
end

function love.resize(w, h)
	windowWidth, windowHeight = w, h;
	saveSettings();
	updateSlots();
end



function updateSlots()
	imgSlots = {};
	
	local fullWidth = windowWidth - margin*2;
	local fullHeight = windowHeight - margin*2;
	
	-- This font setting thing is temporary
	local fontSize = math.floor(fullHeight / 32);
	fontSize = math.max(fontSize, 16);
	font = love.graphics.newFont(fontSize);
	settingsTabHeight = font:getHeight() + margin;
	
	fullHeight = fullHeight - settingsTabHeight;
	
	local bigSlotSize = math.floor( math.min(fullHeight, (fullWidth - margin/2) * 2/3) );
	local smallSlotSize = math.floor( bigSlotSize/2 - margin/2 );
	local allSlotsWidth = bigSlotSize + smallSlotSize + margin;
	local allSlotsHeight = bigSlotSize;
	
	-- UPDATE FONT
	fontSize = math.floor(bigSlotSize / 32);
	fontSize = math.max(fontSize, 16);
	font = love.graphics.newFont(fontSize);
	settingsTabHeight = font:getHeight() + margin;
	love.graphics.setFont(font);
	
	imgSlots[1] = {
		x = math.floor(windowWidth/2 - allSlotsWidth/2),
		y = math.floor(windowHeight/2 - allSlotsHeight/2 + settingsTabHeight/2),
		width = smallSlotSize,
		height = smallSlotSize
	}
	imgSlots[2] = {
		x = math.floor(windowWidth/2 - allSlotsWidth/2),
		y = math.floor(windowHeight/2 + margin/2 + settingsTabHeight/2),
		width = smallSlotSize,
		height = smallSlotSize
	}
	imgSlots[3] = {
		x = math.floor(windowWidth/2 - allSlotsWidth/2 + smallSlotSize + margin),
		y = math.floor(windowHeight/2 - allSlotsHeight/2 + settingsTabHeight/2),
		width = bigSlotSize,
		height = bigSlotSize
	}
	
	if (alternateMode) then
		-- Lazy approach, but why reinvent the wheel?
		imgSlots[3].x = imgSlots[1].x;
		
		imgSlots[1].x = imgSlots[3].x + imgSlots[3].width + margin;
		imgSlots[2].x = imgSlots[3].x + imgSlots[3].width + margin;
		
		imgSlots[1].validDrop = false;
		imgSlots[2].validDrop = false;
		imgSlots[3].validDrop = true;
	else
		imgSlots[1].validDrop = true;
		imgSlots[2].validDrop = true;
		imgSlots[3].validDrop = false;
	end
	
	local buttonSize = math.floor(imgSlots[3].height / 32);
	buttonSize = math.max(buttonSize, 24);
	local buttonMargin = math.max(buttonSize/8, 4);
	
	for i = 1, 3 do
		imgSlots[i].buttons = {
			{ -- DELETE
				x = imgSlots[i].x + imgSlots[i].width - (buttonSize + buttonMargin)*2,
				y = imgSlots[i].y + buttonMargin,
				width = buttonSize,
				height = buttonSize,
				image = trashImg,
				color = {207/255, 112/255, 112/255, 1},
				isActive = function()
					local imgs = {baseImagePreview, alphaImagePreview, combinedImagePreview};
					return (imgs[i] ~= nil and imgSlots[i].validDrop); -- Can delete if image exists AND is the correct alternateMode value
				end,
				callback = function()
					deleteImage(i);
				end
			},
			
			{ -- DOWNLOAD
				x = imgSlots[i].x + imgSlots[i].width - (buttonSize + buttonMargin)*1,
				y = imgSlots[i].y + buttonMargin,
				width = buttonSize,
				height = buttonSize,
				image = downloadImg,
				color = {161/255, 207/255, 112/255, 1},
				isActive = function()
					local imgs = {baseImagePreview, alphaImagePreview, combinedImagePreview};
					return imgs[i] ~= nil; -- Can download if image exists
				end,
				callback = function()
					downloadImage(i);
				end
			}
		};
	end
	
	checkerCanvas = love.graphics.newCanvas();
	love.graphics.setCanvas(checkerCanvas);
	do
		love.graphics.clear();
		for i, v in ipairs(imgSlots) do
			-- combinedRenderMode = {"transparent_light", "transparent_dark", "alpha_mask", "premultiplied", "selfillum"};
			
			if (combinedRenderMode.current == "transparent_light" or combinedRenderMode.current == "transparent_dark") then
				love.graphics.setColor(combinedRenderMode.current == "transparent_light" and backgroundLightColor or backgroundDarkColor);
				love.graphics.rectangle("fill", v.x, v.y, v.width, v.height);
				
				love.graphics.setColor(combinedRenderMode.current == "transparent_light" and foregroundLightColor or foregroundDarkColor);
				love.graphics.setScissor(v.x, v.y, v.width, v.height);
				for x = 0, math.ceil(v.width / checkerImgW) do
					for y = 0, math.ceil(v.height / checkerImgW) do
						love.graphics.draw(checkerImg, v.x + x*checkerImgW, v.y + y*checkerImgW, 0, 1, 1);
					end
				end
				love.graphics.setScissor();
			else
				love.graphics.setColor(0, 0, 0, 1);
				love.graphics.rectangle("fill", v.x, v.y, v.width, v.height);
			end
		end
	end
	love.graphics.setCanvas();
end

function receiveBase(imgData, name)
	baseImageData = imgData;
	
	baseImageData:mapPixel(
		function(x, y, r, g, b, a)
			-- Base should always be at full opacity
			return r, g, b, 1;
		end
	);
	
	baseImagePreview = love.graphics.newImage(imgData);
	baseName = name;
	
	print("Received base");
	
	if (baseImageData and alphaImageData) then
		renderCombinedImage();
	end
end

function receiveAlpha(imgData, name)
	alphaImageData = imgData;
	
	alphaImageData:mapPixel(
		function(x, y, r, g, b, a)
			-- Alpha should always be at full opacity AND black-and-white
			local av = (r+g+b)/3 * a;
			return av, av, av, 1;
		end
	);
	
	alphaImagePreview = love.graphics.newImage(imgData);
	alphaName = name;
	
	print("Received alpha");
	
	if (baseImageData and alphaImageData) then
		renderCombinedImage();
	end
end

function receiveCombined(imgData, name)
	combinedImageData = imgData;
	
	-- Combined image is the only one that SHOULDN'T be pre-treated
	
	combinedImagePreview = love.graphics.newImage(imgData);
	combinedName = name;
	alphaName = name .. "_alpha";
	baseName = name .. "_base";
	
	print("Received combined");
	
	renderAlphaImage();
	renderBaseImage();
end

function renderAlphaImage()
	if (combinedImageData) then
		alphaImageData = love.image.newImageData(combinedImageData:getWidth(), combinedImageData:getHeight());
		
		alphaImageData:mapPixel(
			function(x, y)
				local _, _, _, a = combinedImageData:getPixel(x, y);
				return a, a, a, 1;
			end
		);
		
		alphaImagePreview = love.graphics.newImage(alphaImageData);
		print("Produced render of alpha image");
	end
end

function renderBaseImage()
	if (combinedImageData) then
		baseImageData = love.image.newImageData(combinedImageData:getWidth(), combinedImageData:getHeight());
		
		baseImageData:mapPixel(
			function(x, y)
				local r, g, b = combinedImageData:getPixel(x, y);
				return r, g, b, 1;
			end
		);
		
		baseImagePreview = love.graphics.newImage(baseImageData);
		print("Produced render of base image");
	end
end

function renderCombinedImage()
	if (baseImageData and alphaImageData) then
		combinedImageData = love.image.newImageData(baseImageData:getWidth(), baseImageData:getHeight());
		
		local alphaWidth, alphaHeight = alphaImageData:getDimensions();
		local combinedWidth, combinedHeight = combinedImageData:getDimensions();
		-- alphaFillMode = {"stretch", "repeat", "fill_opaque", "fill_transparent", "fill_repeat"}
		
		combinedImageData:mapPixel(
			function(x, y)
				local r, g, b = baseImageData:getPixel(x, y);
				
				-- We ignore alpha here because it is premultiplied in the receiveAlpha step
				local r2, g2, b2 = 0, 0, 0;
				if (alphaFillMode.current == "stretch") then
					local px, py = x / (combinedWidth-1), y / (combinedHeight-1);
					px = px * (alphaWidth - 1);
					py = py * (alphaHeight - 1);
					
					r2, g2, b2 = alphaImageData:getPixel( px, py );
				elseif (alphaFillMode.current == "repeat") then
					local px, py = math.mod(x, alphaWidth), math.mod(y, alphaHeight);
					
					r2, g2, b2 = alphaImageData:getPixel(px, py);
				else
					if (x < alphaWidth and y < alphaHeight) then
						r2, g2, b2 = alphaImageData:getPixel(x, y);
					elseif (alphaFillMode.current == "fill_opaque") then
						r2, g2, b2 = 1, 1, 1;
					elseif (alphaFillMode.current == "fill_transparent") then
						r2, g2, b2 = 0, 0, 0;
					elseif (alphaFillMode.current == "fill_repeat") then
						if (x < alphaWidth) then
							r2, g2, b2 = alphaImageData:getPixel(x, alphaHeight-1);
						elseif (y < alphaHeight) then
							r2, g2, b2 = alphaImageData:getPixel(alphaWidth-1, y);
						else
							r2, g2, b2 = alphaImageData:getPixel(alphaWidth-1, alphaHeight-1);
						end
					end
				end
				
				local a = (r2+g2+b2)/3;
				
				return r, g, b, a
			end
		);
		
		combinedImagePreview = love.graphics.newImage(combinedImageData);
		print("Produced render of combined image");
	end
end

function deleteImage(slot)
	print("Deleting slot " .. slot);
	
	-- BASE
	if (slot == 1 and baseImageData) then
		baseName = "";
		baseImageData = nil;
		baseImagePreview = nil;
		
		-- As a consequence, also delete the combined image (this is subject to change!)
		if (not alternateMode) then
			deleteImage(3);
		end
	end
	
	-- ALPHA
	if (slot == 2 and alphaImageData) then
		alphaName = "";
		alphaImageData = nil;
		alphaImagePreview = nil;
		
		-- As a consequence, also delete the combined image (this is subject to change!)
		if (not alternateMode) then
			deleteImage(3);
		end
	end
	
	-- COMBINED
	if (slot == 3 and combinedImageData) then
		combinedName = "";
		combinedImageData = nil;
		combinedImagePreview = nil;
		
		-- As a consequence, also delete the divided images (this is subject to change!)
		if (alternateMode) then
			deleteImage(1);
			deleteImage(2);
		end
	end
end

function downloadImage(slot)
	print("Downloading slot " .. slot);
	
	if (slot == 1 and baseImageData) then
		exportImage(baseImageData, exportFormat.current, "_base");
	end
	if (slot == 2 and alphaImageData) then
		exportImage(alphaImageData, exportFormat.current, "_alpha");
	end
	if (slot == 3 and combinedImageData) then
		exportImage(combinedImageData, exportFormat.current, "");
	end
end

function exportImage(imageData, format, suffix, skipOpenFile)
	if (not imageData) then
		return;
	end
	
	format = format or "tga"; -- TGA or PNG
	suffix = suffix or ""; -- "_base" or "_alpha"
	skipOpenFile = skipOpenFile or false;
	
	local filename = alternateMode and combinedName or baseName;
	if (not filename or filename == "") then
		filename = "untitled";
	end
	filename = _IMAGES_FOLDER .. util._FILE_SEPARATOR .. filename;
	print(filename);
	
	local add = "";
	local addN = 0;
	
	while (love.filesystem.getInfo(filename .. add .. suffix .. "." .. format, "file")) do
		print("Exists");
		addN = addN + 1;
		add = "000" .. addN;
		add = "_" .. add:sub(-4, -1);
	end
	
	imageData:encode(format, filename .. add .. suffix .. "." .. format);
	if (not skipOpenFile) then
		openImagesFolder();
	end
end

function openImagesFolder()
	love.system.openURL( "file://" .. love.filesystem.getSaveDirectory() .. util._FILE_SEPARATOR .. _IMAGES_FOLDER );
end



function readSettings()
	settings = getCurrentSettings(); -- Sets the "default" ones
	if ( love.filesystem.exists(_SETTINGS_FILENAME) ) then
		local _settings = json.decodeFile(_SETTINGS_FILENAME);
		applyCurrentSettings(_settings);
	else
		-- First settings save
		saveSettings();
	end
end

function saveSettings()
	settings = getCurrentSettings(); -- Updates the current list
	print(tostring(settings));
	json.encodeToFile(settings, _SETTINGS_FILENAME);
end

function getCurrentSettings()
	local _settings = {
		["alternateMode"] = alternateMode,
		["exportFormat"] = exportFormat.idx,
		["alphaFillMode"] = alphaFillMode.idx,
		["combinedRenderMode"] = combinedRenderMode.idx,
		["windowWidth"] = windowWidth,
		["windowHeight"] = windowHeight,
		["windowMaximized"] = love.window.isMaximized(),
	}
	
	return _settings;
end

function applyCurrentSettings(_settings)
	-- Done this way so that, if the list of settings changes at any point, it won't crash or ignore the old settings
	for i, v in pairs(_settings) do
		settings[i] = v;
	end
	
	alternateMode = settings["alternateMode"];
	exportFormat:setIdx(settings["exportFormat"]);
	alphaFillMode:setIdx(settings["alphaFillMode"]);
	combinedRenderMode:setIdx(settings["combinedRenderMode"]);
	local _oldWidth, _oldHeight = windowWidth, windowHeight;
	windowWidth = settings["windowWidth"];
	windowHeight = settings["windowHeight"];
	local windowMaximized = settings["windowMaximized"];
	if (windowMaximized) then
		love.window.maximize();
	elseif (windowWidth ~= _oldWidth or windowHeight ~= _oldHeight) then
		-- No need to cause unnecessary flickering
		windowFlags.centered = true;
		love.window.setMode(windowWidth, windowHeight, windowFlags);
	end
	
	-- Currently not needed, since this is only called on load, and updateSlots already happens there
	-- updateSlots();
end
