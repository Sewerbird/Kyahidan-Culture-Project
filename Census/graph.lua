local _ = require('lib/shimmed')
local mendel = require('lib/mendel')
local inspect = require('lib/inspect')
require('make_utils')
require('graph_utils')

local working_set = {}
local locations = {"Aville","Burb","Chamlet"}
local input_data_path = arg[1]
local sample_people = arg[2]
setupLookup(input_data_path)
working_set = getWorkingSet()
print("Working set size is " .. #working_set)
do --Draw Graphs
	do --Draw All Locations in One Map
		local folks_by_location = _.groupBy(working_set, function(x) 
			print("Looking at " .. inspect(locations) .. " for " .. inspect(x))
			return locations[lookupPerson(x).location] 
		end)
		local g = assert(io.open("output/region_map.viz", "w"))
		g:write("strict digraph G {\n\tcompound=true;\n\toverlap=prism;")
		for location = 1, #locations do
			drawFullLocation(g,location,folks_by_location[locations[location]],true)
		end
		g:write("\n}")
		g.close()
	end

	do --Draw Each Location on Own Map
		local folks_by_location = _.groupBy(working_set, function(x) return locations[lookupPerson(x).location] end)
		for location = 1, #locations do
			print("DRAWING FOR LOCATION" .. location)
			local g = assert(io.open("output/town_map_"..locations[location]..".viz", "w"))
			g:write("strict digraph G {\n\tcompound=true;\n\toverlap=prism;")
			drawFullLocation(g,location,folks_by_location[locations[location]],false)
			g:write("\n}")
			g.close()
		end
	end

	do --Sample a living person and show their full lineage
		for i = 1, sample_people do
			local g = assert(io.open("output/sample_person_"..i..".viz", "w"))
			g:write("strict digraph G {compound=true; overlap=scale;")
			g:write("\n\tsubgraph cluster_ancestors {")
			local sample = lookupPerson(_.sample(working_set))
			local shape = sample.gender == "M" and "square" or "circle"
			local myname = sample.givennym.."."..sample.patronym
			print("Graphing geneological history of " .. myname)
			local parent_depth = 6
			function addParents(x,level)
				if level > parent_depth then return end
				if x.mother then
					local mothername = lookupPerson(x.mother).givennym .. "." .. lookupPerson(x.mother).patronym
					local isalive
					if lookupPerson(x.mother).alive then isalive = "blue" else isalive = "gray" end
					g:write("\n\t\t" .. x.mother .. " [shape=circle,color="..isalive..",label=\""..mothername.."("..lookupPerson(x.mother).age..")\"]")
					g:write("\n\t\t" .. x.mother .. "->" .. x.id .. " [color=blue]")
					addParents(lookupPerson(x.mother),level+1)
				end
				if x.father then
					local fathername = lookupPerson(x.father).givennym .. "." .. lookupPerson(x.father).patronym
					local isalive
					if lookupPerson(x.father).alive then isalive = "blue" else isalive = "gray" end
					g:write("\n\t\t" .. x.father .. " [shape=square,color="..isalive..",label=\""..fathername.."("..lookupPerson(x.father).age..")\"]")
					g:write("\n\t\t" .. x.father .. "->" .. x.id .. " [color=red]")
					addParents(lookupPerson(x.father),level+1)
				end
			end
			function addChildren(x)
				_.each(x.children, function(c)
					local child = lookupPerson(c)
					local childname = child.givennym .. "." .. child.patronym
					local isalive = child.alive and "blue" or "gray"
					local shape = child.gender == "M" and "square" or "circle"
					local linecolor = x.gender == "M" and "red" or "blue"
					g:write("\n\t\t" .. c .. " [shape="..shape..",color="..isalive..",label=\""..childname.."("..child.age..")\"]")
					g:write("\n\t\t" .. x.id .. "->" .. c .. " [color="..linecolor.."]")
					addChildren(child)
				end)
			end
			g:write("\n\t\t" .. sample.id .. " [color=orange,shape="..shape..",label=\""..myname.."("..sample.age..")\"]")
			addParents(sample,1)
			addChildren(sample)
			g:write("\n\t}")
			g:write("\n}")
			g.close()
		end
	end
end



