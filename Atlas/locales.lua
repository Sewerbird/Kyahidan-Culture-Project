local _ = require("lib/shimmed")
local delaunay = require("lib/delaunay")

--Create a non-repeated list of edges ready for squiggling
function getDelaunayEdges(delaunay_triangles)
  local edges_drawn = {}
  local dedges = 	_.flatten(_.map(delaunay_triangles,function(tri) 
    return _.map(_.filter(tri:getSides(),function(edge)
      if not _.some(edges_drawn, function(e) return e:same(edge) end) then
        table.insert(edges_drawn,edge)
        return true
      end
      return false
    end), function(edge)
        return {{edge.p1.x,edge.p1.y},{edge.p2.x,edge.p2.y}}
    end)
  end))
end

--Construct voronoi edges
function getVoronoiEdges(delaunay_triangles)
  local vedges_drawn = {}
  local circumcenters = _.map(delaunaytriangles,function(tri) return delaunay.Point(tri:getCircumCenter()) end)
  _.each(circumcenters, function(cc,i)
    local my_tri = triangles[i]
    _.each(my_tri:getSides(),function(edge) 
      --get the other tri with this side
      _.find(triangles,function(o_tri)
        local match = _.find(o_tri:getSides(), function(o_edge) 
          return o_edge:same(edge)
        end)
        if match then
          if not _.some(vedges_drawn, function(vedge) return vedge:same(match) end) then
            local o_cc = delaunay.Point(o_tri:getCircumCenter())
            table.insert(vedges_drawn,delaunay.Edge(cc,o_cc))
            return true
          else
            return true
          end
        else
          return false
        end
      end)
    end)
  end)
  return _.map(vedges_drawn, function(edge) 
    return {{edge.p1.x,edge.p1.y},1/4,{edge.p2.x,edge.p2.y}} 
  end)
end

--Some Globe Math
function parseSVGtoPolygons(path_string)
  local paths = {}
  for path_object in string.gmatch(path_string,[[<path(.-)/>]]) do
    for identifier, path in string.gmatch(path_object,[[id="(%w*)".*d="([^"]*)".*style=]]) do
      local polygons = {}
      for poly_string in string.gmatch(path,"[Mm]([^Mm]+)") do
        local polygon = {}
        for point_string in string.gmatch(poly_string,"[LlCc]?%s*([^LlCc]+)") do
          local point = {}
          for coord_string in string.gmatch(point_string,"([^ ,zZ]+)") do
            local coord = tonumber(coord_string)
            table.insert(point, coord)
          end
          table.insert(polygon, point)
        end
        table.insert(polygons, polygon)
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

--Configuration

local width = 200
local height = 200
local num_locales = 100

--Random points
local lPoints = _.times(num_locales, function(i)
  return delaunay.Point(math.random() * width, math.random() * height)
end)

local triangles = delaunay.triangulate(unpack(lPoints))
local test_polys = importSVGtoPoints("slice1.svg", function(p) 
  p[1] = p[1] - 250
  p[2] = p[2] - 250
  return {getXYZfromLatLng(getLatLngFromXY(p[1],p[2]))} 
end)


