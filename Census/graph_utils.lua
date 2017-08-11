local _ = require('lib/lodash')
local mendel = require('lib/mendel')

function drawPerson(context, id, whitespaceprefix)
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
		--",label=<<FONT POINT-SIZE=\"120\">"..name.."("..x.age..")</FONT><BR ALIGN=\"CENTER\"/>"..mendel.describeFace(name, x.genome)..">];")
    ",label=\""..name.."("..x.age..")\"]")
end
function drawRelations(context, id, sameLoc, sameHouse)
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
function drawFullLocation(context, location, location_working_set, out_of_town_is_out_of_town)
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


