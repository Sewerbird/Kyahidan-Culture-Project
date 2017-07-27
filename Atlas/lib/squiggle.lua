local inspect = require("lib/inspect")
local _ = require("lib/shimmed")
local matrix = require("lib/matrix")

local function orthoSquiggle(startpoint,endpoint,amplitude,iterations)
	local sX = startpoint[1][1]
	local sY = startpoint[2][1]
	local eX = endpoint[1][1]
	local eY = endpoint[2][1]
	local len = math.sqrt(math.pow(eX-sX,2) + math.pow(eY-sY,2))
  local z = {0,len*amplitude,0}

	--Make jitter displacements with fractal midpoint displacement
	for j = 1, iterations do
		z = _.flatten(_.map(z, function(e,i)
			if i < #z then
				if e < z[i+1] then
					return {e,math.pow(0.5,j-1) * math.random() * (z[i+1]-e) + e}
				else
					return {e,math.pow(0.5,j-1) * math.random() * (e-z[i+1]) + z[i+1]}
				end
			else
				return e
			end
		end))
	end
	--Map displacements to a scaled horizontal jitter line
	local seg_len = len / (#z -1)
	z = _.map(z, function(e,i)
		return matrix({(i-1)*seg_len, e})
	end)
	--Rotate & Translate line to match start and endpoint
	local rad = math.atan2(eY - sY, eX - sX)
	local rot = matrix({{math.cos(rad), -math.sin(rad)},{math.sin(rad), math.cos(rad)}})
	z = _.map(z, function(e)
		return (rot * e) + matrix({sX,sY})
	end)

	return z
end

function squiggleShape(input,iterations)
	local points = _.filter(input, function(e) return _.isTable(e) end)
	local amps = _.filter(input, function(e) return not _.isTable(e) end)

	local z = _.map(points, function(e) return matrix(e) end)
	for j = 1, iterations do
		z = _.flatten(_.map(z, function(e,i)
			if i < # z then
				local amp = math.floor(i/(#z/#amps))+1
				return orthoSquiggle(
					e,
					z[i+1],
					((j > 1 and math.random() > 0.5) and -1 or 1 )*amps[amp],
					1)
			else
				return {e}
			end
		end))
	end
	return z
end

function drawPath(points, style)
  style = style and style or [[fill:none;stroke:black;stroke-width:0.25px;]]
	local sX = points[1][1][1]
	local sY = points[1][2][1]
	return (_.reduce(points, function(acc,e,i)
		return acc .. " L " .. e[1][1] .. " " .. e[2][1]
	end, [[<path style="]] .. style .. [[" d="M ]] .. sX .. [[ ]] .. sY .. [[ L ]] .. sX .. " " .. sY) .. [[" />]])
end

function makeSquiggleSVG(filepath, viewbox, lines, roughness)
	local f = assert(io.open(filepath, "w"))
	f:write([[<svg viewBox="]] .. viewbox .. [[" xmlns="http://www.w3.org/2000/svg">]])
	_.each(lines, function(k) f:write(drawPath(squiggleShape(k,roughness))) end)
	f:write("</svg>")
	f:close()
end

