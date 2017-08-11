local _ = require("lib/shimmed")
local inspect = require("lib/inspect")

--Some Globe Math

function importSVGtoPoints (svg_file,transform_fn)
  local f = assert(io.open(svg_file,'r'))
  local svg_string = f:read("*all")
  f:close()
  local translated = {}
  _.forIn(parseSVGtoPolygons(svg_string), function(group,key)
    translated[key] = _.map(group, function(polygon)
      return _.map(polygon, function(point)
        local z = {point[1],point[2]}
        if transform_fn ~= nil then z = transform_fn(z) end
        return z
      end)
    end)
  end)
  return translated
end

function parseSVGtoPolygons(path_string)
  local paths = {}
  for path_object in string.gmatch(path_string,[[<path(.-)/>]]) do
    for identifier, path in string.gmatch(path_object,[[id="(%w*)".*d="([^"]*)".*style=]]) do
      local polygons = {}
      local turtle = {}
      local polygon = {}
      for command, poly_string in string.gmatch(path,"([MmLlCc])%s?([^MmLlCc]+)") do
        if command == "M" then
          --Start new polygon at absolute location
          turtle = {}
          polygon = {}
          for coord_string, terminus in string.gmatch(poly_string,"([^ ,zZ]+)([zZ]?)") do
            table.insert(turtle, tonumber(coord_string))
            if terminus == "z" or terminus == "Z" then 
              table.insert(polygons, polygon) end
          end
          table.insert(polygon, {turtle[1],turtle[2]})
        elseif command == "m" then
          --Start new polygon at relative location
          polygon = {}
          local point = {}
          for coord_string, terminus in string.gmatch(poly_string,"([^ ,zZ]+)([zZ]?)") do
            table.insert(point, tonumber(coord_string))
            if terminus == "z" or terminus == "Z" then 
              table.insert(polygons, polygon) end
          end
          turtle[1] = turtle[1] + point[1]
          turtle[2] = turtle[2] + point[2]
          table.insert(polygon, {turtle[1],turtle[2]})
        elseif command == "L" then
          --Add new polygonal point at absolute location
          local point = {}
          for coord_string, terminus in string.gmatch(poly_string,"([^ ,zZ]+)([zZ]?)") do
            table.insert(point, tonumber(coord_string))
            if terminus == "z" or terminus == "Z" then 
              table.insert(polygons, polygon) end
          end
          turtle[1] = turtle[1] + point[1]
          turtle[2] = turtle[2] + point[2]
          table.insert(polygon,{turtle[1],turtle[2]})
        elseif command == "l" then
          --Add new polygonal point at relative location
          local point = {}
          for coord_string, terminus in string.gmatch(poly_string,"([^ ,zZ]+)([zZ]?)") do
            table.insert(point, tonumber(coord_string))
            if terminus == "z" or terminus == "Z" then 
              table.insert(polygons, polygon) 
            end
          end
          turtle[1] = turtle[1] + point[1]
          turtle[2] = turtle[2] + point[2]
          table.insert(polygon, {turtle[1],turtle[2]})
        end
      end
      paths[identifier] = polygons
    end
  end
  return paths
end

function getLatLngFromXY (x, y, lat0, lng0)
  local R = 250
  local lat0 = lat0 or math.pi/2
  local lng0 = lng0 or 0
  local cos = math.cos
  local sin = math.sin
  local atan2 = math.atan2
  local asin = math.asin
  local sqrt = math.sqrt
  local p = sqrt(x*x + y*y)
  local c = asin(p/R)
  local lat = asin((cos(c)*sin(lat0)) + (y*(sin(c)*cos(lat0)/p)))
  local lng = lng0 + atan2(x*sin(c),(p*cos(c)*cos(lat0))-(y*sin(c)*sin(lat0)))
  return lat, lng
end

function getXYZfromLatLng (lat, lng, lat0, lng0)
  local R = 250
  local lat0 = lat0 or math.pi/2
  local lng0 = lng0 or 0
  local cos = math.cos
  local sin = math.sin
  local atan2 = math.atan2
  local asin = math.asin
  local x = R * cos(lat) * sin(lng-lng0)
  local y = R * (cos(lat0)*sin(lat) - sin(lat0)*cos(lat)*cos(lng-lng0))
  local z = R * sin(lat)
  return x, y, z
end

function radToDeg(rad)
  return rad * 180 / math.pi
end

function degToRad(deg)
  return deg * math.pi / 180
end

