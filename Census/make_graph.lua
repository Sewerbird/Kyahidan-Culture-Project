local _ = require('lib/lodash')
require('make_utils')

local working_set = {}
local input_data_path = arg[1]
setupLookup(input_data_path)
do --Draw Graphs
	local function drawPerson(context, id, whitespaceprefix)
		local x = lookupPerson(id)
		local name = x.givennym .. "." .. x.patronym
		local lifeborder = x.alive and "blue" or "gray"
		local fill = x.orphaned and "orange" or (x.is_bastard_of and "red" or "white")
		local gendershape = x.gender == "M" and "square" or "circle"
		if #x.widowedBy > 0 then gendershape = x.gender == "M" and "Msquare" or "Mcircle" end
		context:write(whitespaceprefix..id..
			" [color="..lifeborder..
			",style=filled, fillcolor="..fill..
			",shape="..gendershape..
			",label=<<FONT POINT-SIZE=\"120\">"..name.."("..x.age..")</FONT><BR ALIGN=\"CENTER\"/>"..mendel.describeFace(name, x.genome)..">];")
	end
	local function drawRelations(context, id, sameLoc, sameHouse)
		local x = lookupPerson(id)
		--print("Drawing relation for: " .. inspect(x))
		if x.mother and lookupPerson(x.mother).alive and 
			((sameLoc and x.location == lookupPerson(x.mother).location) or (not sameLoc)) and
			((sameHouse and x.household == lookupPerson(x.mother).household) or (not sameHouse)) then
			context:write("\n\t".. x.mother .. "->" .. id .. " [color=blue];")
		elseif x.mother and x.father and lookupPerson(x.father).alive and not lookupPerson(x.mother).alive and 
			((sameLoc and x.location == lookupPerson(x.father).location) or (not sameLoc)) and
			((sameHouse and x.household == lookupPerson(x.father).household) or (not sameHouse)) then
			--Usually we draw parentage from the mother, but if she has died and the father is alive, draw from him
			context:write("\n\t"..x.father.."->"..id.."[color=purple];")
		end

		if x.foster and lookupPerson(x.foster).alive and 
			((sameLoc and x.location == lookupPerson(x.foster).location) or (not sameLoc)) and
			((sameHouse and x.household == lookupPerson(x.foster).household) or (not sameHouse)) then
			context:write("\n\t"..x.foster.."->"..id.."[color=orange];")
		end
		if x.married and lookupPerson(x.spouse).alive and x.gender == "F" and 
			((sameLoc and x.location == lookupPerson(x.spouse).location) or (not sameLoc)) and
			((sameHouse and x.household == lookupPerson(x.spouse).household) or (not sameHouse)) then
			context:write("\n\t".. x.spouse .. "->" .. id .. " [color=red];")
		end
		if x.is_bastard_of and lookupPerson(x.is_bastard_of).alive and 
			((sameLoc and x.location == lookupPerson(x.is_bastard_of).location) or (not sameLoc)) and
			((sameHouse and x.household == lookupPerson(x.is_bastard_of).household) or (not sameHouse)) then
			context:write("\n\t".. x.is_bastard_of .. "->" .. id .. " [color=green];")
		end
		if x.divorces and #x.divorces > 0 then
			_.each(x.divorces, function(divorcee)
				if ((sameLoc and x.location == lookupPerson(divorcee).location) or (not sameLoc)) and
					((sameHouse and x.household == lookupPerson(divorcee).household) or (not sameHouse)) then
					context:write("\n\t"..divorcee.."->"..id.." [color=cyan];")
				end
			end)
		end

	end
	local function drawFullLocation(context, location, location_working_set, out_of_town_is_out_of_town)
		print("Graphing households in " .. locations[location])
		local households = _.groupBy(location_working_set, function(x) return lookupPerson(x).household end)
		context:write("\nsubgraph cluster_"..location.." {")
			_.forIn(households, function(housemates, household) 
				context:write("\n\tsubgraph cluster_"..household.." {")
					context:write("\n\t\tlabel=\""..household.."\";")
					context:write("\n\t\tstyle=filled;")
					context:write("\n\t\tcolor=gray;")
					_.each(housemates, function(id)
						drawPerson(context, id, "\n\t\t")
						drawRelations(context,id,true,true)
					end)
				context:write("\n\t}")
				_.each(housemates, function(id)
					drawRelations(context,id,true,false)
				end)
			end)
			if not out_of_town_is_out_of_town then
				_.each(location_working_set, function(id)
					drawRelations(context,id,false,false)
				end)
			end
		context:write("}")
		if out_of_town_is_out_of_town then
				_.each(location_working_set, function(id)
					drawRelations(context,id,false,false)
				end)
		end
	end

	do --Draw All Locations in One Map
		local folks_by_location = _.groupBy(working_set, function(x) return locations[lookupPerson(x).location] end)
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



