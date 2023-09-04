-- Most things here have been STOLED from my Paperboy project.

-- UTIL
util = {}
util._FILE_SEPARATOR = "/" -- TO-DO: Change per operational system
util._LINE_BREAK = "\r\n" -- TO-DO: Change per operational system

function util.aabb(x1, y1, w1, h1, x2, y2, w2, h2)
	return x1 >= x2 and x1+w1 <= x2+w2 and y1 >= y2 and y1+h1 <= y2+h2
end

function util.makeList(...)
	local items = {...};
	
	local ret = {
		list = items,
		listReference = items,
		current = items[1],
		currentReference = items[1],
		idx = 1,
		
		listSize = #items,
		
		setIdx = function(self, idx)
			self.idx = idx;
			self.current = self.list[self.idx];
			self.currentReference = self.listReference[self.idx];
			return self.current;
		end,
		next = function(self)
			return self:setIdx( self.idx == self.listSize and 1 or (self.idx + 1) );
		end,
		previous = function(self)
			return self:setIdx( self.idx == 1 and self.listSize or (self.idx - 1) );
		end,
		first = function(self)
			return self:setIdx(1);
		end,
		last = function(self)
			return self:setIdx(self.listSize);
		end,
		getIdx = function(self, _idx)
			return (_idx <= self.listSize and self.list[_idx] or nil);
		end,
		appendReference = function(self, ...)
			self.listReference = {...};
			self.currentReference = self.listReference[self.idx];
			return self;
		end
	};
	
	return ret;
end



-- TABLE
function table.contains(t, val, compareFunction, recursiveSearch)
	recursiveSearch = recursiveSearch or false
	compareFunction = compareFunction or function(a, b) return a == b end

	for i, v in pairs(t) do
		if compareFunction(val, v) then
			return i
		elseif recursiveSearch and type(v) == "table" and v ~= t then -- Let's not search the table if it's inside itself
			local ret = {table.contains(v, val, recursiveSearch)}
			if #ret > 0 then
				return i, unpack(ret)
			end
		end
	end

	return false
end



-- JSON
function json.decodeFile(filename)
	local txt = love.filesystem.read(filename)
	return json.decode(txt)
end

function json.encodeToFile(data, filename)
	local txt = json.encode(data)
	love.filesystem.write(filename, txt)

	return txt
end



-- FILESYSTEM
function love.filesystem.exists(filename) -- Old habits die hard
	local info = love.filesystem.getInfo(filename)
	return info ~= nil
end
