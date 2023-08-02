function aabb(x1, y1, w1, h1, x2, y2, w2, h2)
	return x1 >= x2 and x1+w1 <= x2+w2 and y1 >= y2 and y1+h1 <= y2+h2
end

function tableContains(t, val)
	for i, v in pairs(t) do
		if (val == v) then
			return i
		end
	end

	return false
end
