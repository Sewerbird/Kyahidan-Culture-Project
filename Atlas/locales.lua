local _ = require("lib/shimmed")
local inspect = require("lib/inspect")
local delaunay = require("lib/delaunay")
local matrix = require("lib/matrix")
local squiggle = require("squiggle")

--Configuration

local width = 200
local height = 200
local num_locales = 100

--Random points
local lPoints = _.times(num_locales, function(i)
	return delaunay.Point(math.random() * width, math.random() * height)
end)
--Hacky 'Infinity' points
table.insert(lPoints,delaunay.Point(-10000,0))
table.insert(lPoints,delaunay.Point(10000,0))
table.insert(lPoints,delaunay.Point(0,10000))
table.insert(lPoints,delaunay.Point(0,-10000))

local triangles = delaunay.triangulate(unpack(lPoints))
--Create a non-repeated list of edges ready for squiggling
local edges_drawn = {}
local dedges = 	_.flatten(_.map(triangles,function(tri) 
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

--Construct voronoi edges
local vedges_drawn = {}
local circumcenters = _.map(triangles,function(tri) return delaunay.Point(tri:getCircumCenter()) end)
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
					print "Not gonna double draw"
					return true
				end
			else
				return false
			end
		end)
	end)
end)
local voronoiedges = _.map(vedges_drawn, function(edge) 
	return {{edge.p1.x,edge.p1.y},1/4,{edge.p2.x,edge.p2.y}} 
end)

--Draw Delaunay
makeSquiggleSVG(
	"output/delaunay_squiggle.svg",
	"0 0 200 200",
  dedges,
  0
)
--Draw Voronoi
makeSquiggleSVG(
	"output/voronoi_squiggle.svg",
	"0 0 200 200",
	voronoiedges,
	3
)
