--Imports
local inspect = require 'lib/inspect'
local _ = require 'lib/shimmed'
require 'make_utils'

--Configuration

local years_to_simulate = arg[1]
local people_population = arg[2]
local infant_yearly_death_chance = 0.07
local child_yearly_death_chance = 0.03
local pubescent_yearly_death_chance = 0.05
local adult_yearly_death_chance = 0.03
local elder_yearly_death_chance = 0.09
local married_reproduction_chance = 0.50
local affair_reproduction_chance = 0.60
local yearly_marriage_chance = 0.40
local yearly_affair_chance = 0.03
local yearly_divorce_chance = 0.01
local only_marries_locally_chance = 0.7
local has_affair_locally_chance = 0.6
local retire_with_children_chance = 0.9
local infanthood_age = 0
local childhood_age = 3
local pubescent_age = 10
local adulthood_age = 15
local spinster_age = 36
local menopause_age = 40
local elder_age = 50
local maximum_age = 125
local bride_joins_groom_household = false
local groom_joins_bride_household = false
local couples_begin_new_household = true
local sample_people = 10

--Seed
math.randomseed(os.time())

local people = {}
local working_set = {}
local locations = {"Aville","Burb","Chamlet"}

local household_cntr = 1
for i = 1, people_population do
	local friend = random_person(i,math.random(1,#locations),household_cntr)
	household_cntr = household_cntr + 1
	table.insert(working_set, i)
	table.insert(people, friend)
end

function simulate_year(log, year, people, working_set, locations)
	local household_bins = _.groupBy(working_set, function(id) return people[id].household end)

	--Do Aging
	_.each(working_set, function (id)
		x = people[id]
		if not x.alive then return x end
		local age = x.age
		if (age >= infanthood_age and age < childhood_age and math.random() < infant_yearly_death_chance)
		or (age >= childhood_age  and age < pubescent_age and math.random() < child_yearly_death_chance)
		or (age >= pubescent_age and age < adulthood_age and math.random() < pubescent_yearly_death_chance)
		or (age >= adulthood_age and age < elder_age and math.random() < adult_yearly_death_chance)
		or (age >= elder_age and math.random() < elder_yearly_death_chance
		or (age >= maximum_age)) then
			people[id].alive = false
			people[id].deathyear = year
			logEvent(log,year,"death",id)
			--Handle widows & widowers
			if x.married then
				local spouse = people[x.spouse]
				if people[x.spouse].alive then
					table.insert(people[x.spouse].widowedBy,id)
					if #people[x.spouse].children == 0 then
						people[x.spouse].married = false --allow remarriage if childless
					end
				end
			end
			--Handle orphans
			if #x.children > 0 then
				_.each(x.children, function(cid) 
					local child = people[cid]
					if child.age < adulthood_age and 
						(child.mother and not people[child.mother].alive) and 
						(child.father and not people[child.father].alive) then
						people[cid].orphaned = true
					end
				end)
			end
		else
			people[id].age = people[id].age + 1
			if x.orphaned and x.age >= adulthood_age then
				x.orphaned = false
			end
			if x.gender == "F" and x.age >= menopause_age then
				x.fertile = false
			end
		end
	end)

	--Do Adoption & Elder Caretaking
	_.each(working_set, function(id)
		local x = people[id]
		--Handle lonely elderly moving in with grown children
		if x.age >= elder_age and
			#household_bins[x.household] == 1 and
			math.random() < retire_with_children_chance then

			local my_descendents = get_living_descendents(people, id, 0, {})
			if my_descendents.count > 0 then
				local unplaced = true
				local depth = 1
				while unplaced and my_descendents[depth] do
					local retire_with = _.sample(_.filter(my_descendents[depth], function(desc_id) return people[desc_id].age >= adulthood_age end))
					if retire_with then
						unplaced = false
						x.household = people[retire_with].household 
						x.location = people[retire_with].location 
					end
					depth=depth+1
				end
			end
		end
		--Handle orphans moving in with family members
		if x.age < adulthood_age and x.orphaned and (not x.foster or (x.foster and not people[x.foster].alive)) then
			local live_with = _.sample(_.filter(relatives_by_distance(people, id, 0, 4, {}) ,function(cid) 
					local adopter = people[cid]
					return adopter.age >= adulthood_age and adopter.alive
				end))
			if live_with ~= nil then
				x.household = people[live_with].household
				x.location = people[live_with].location
				x.foster = live_with
			end
		end
	end)

	--Do Marriage
	_.forIn(
		_.groupBy(working_set, function(id)
			local x = people[id]
			--Fundamental eligibility
			if x.alive and not x.married and x.age >= adulthood_age and x.age < elder_age then
				--Gendered eligibility
				if (x.gender == "M" and x.genetic > 0.0) or
					(x.gender == "F" and x.age < spinster_age) then
					--Participation
					if math.random() < yearly_marriage_chance then
						--Location
						if math.random() < only_marries_locally_chance then
							return x.location
						else
							return _.sample(locations)
						end
					end
				end
			end
			return nil
		end),
		function(participants, market)
			local brides = _.sort(_.filter(participants, function(id) return people[id].gender == "F" end), function(a,b) return people[a].genetic < people[b].genetic end)
			local grooms = _.sort(_.filter(participants, function(id) return people[id].gender == "M" end), function(a,b) return people[a].genetic < people[b].genetic end)
			for i = 1, #brides do
				if grooms and grooms[i] then
					-- incest taboo
					local bride = brides[i]
					local groom = grooms[i]
					local bridemother = people[bride].mother
					local bridefather = people[bride].father
					local groommother = people[groom].mother
					local groomfather = people[groom].father
					if not(
						(bridemother and groommother and (bridemother == groommother)) or
						(bridefather and groomfather and (bridefather == groomfather))) then
						people[groom].married = true
						people[bride].married = true
						people[groom].spouse = bride
						people[bride].spouse = groom
						logEvent(log,year,"marriage",groom,bride)
						if groom_joins_bride_household then 
							people[groom].household = people[bride].household
							people[groom].location = people[bride].location
						elseif bride_joins_groom_household then
							people[bride].household = people[groom].household
							people[bride].location = people[groom].location
						elseif couples_begin_new_household then
							people[groom].household = household_cntr
							people[bride].household = household_cntr
							people[groom].location = math.random() > 0.5 and people[groom].location or people[bride].location
							people[bride].location = people[groom].location
							household_cntr = household_cntr + 1
						end
					end
				end
			end
		end
	)

	-- Handle Affairs
	_.forIn(
		_.groupBy(working_set, 
			function(id)
				local x = people[id]
				if x.alive and 
					x.married and 
					x.age >= adulthood_age and x.age < elder_age and 
					((x.gender == "M" and x.genetic > 0.25) or
					(x.gender == "F" and x.age < spinster_age)) and 
					math.random() < yearly_affair_chance then
					--Location
					if math.random() < has_affair_locally_chance then
						return x.location
					else
						return _.sample(locations)
					end
				end
				return nil
			end),
		function(participants, market)
			local women = _.sort(_.filter(participants, function(id) return people[id].gender == "F" end), function(a,b) return people[a].genetic < people[b].genetic end)
			local men = _.sort(_.filter(participants, function(id) return people[id].gender == "M" end), function(a,b) return people[a].genetic < people[b].genetic end)
			for i = 1, #women do
				if men and men[i] and people[men[i]].genetic > people[people[women[i]].spouse].genetic then
					logEvent(log, year, "affair", men[i], women[i])
					if math.random() < affair_reproduction_chance and people[women[i]].fertile and x.pregnant == false then
						people[women[i]].pregnant = true 
						people[women[i]].fetus_is_bastard_of = men[i]
					end
				end
			end
		end
	)

	-- Handle Birth & Pregnancy
	_.each(working_set, function(id)
		local x = people[id]
		if x.alive 
		and x.gender == "F" 
		and x.pregnant then
			--Finished pregnancy
			local father = x.fetus_is_bastard_of and x.fetus_is_bastard_of or x.spouse
			local baby = baby_person(x,people[father])

			baby.id = #people+1
			baby.birthyear = year
			baby.is_bastard_of = x.fetus_is_bastard_of and x.fetus_is_bastard_of or nil
			if baby.is_bastard_of then 
				--Assume cuckold adopts
				baby.patronym = people[x.spouse].patronym 
				baby.foster = x.spouse
				logEvent(log, year, "bastard_adoption", baby.id, baby.foster, baby.mother, baby.is_bastard_of)
			end
			table.insert(people,baby)
			table.insert(working_set,baby.id)
			table.insert(people[baby.mother].children, baby.id)
			if not baby.is_bastard_of then
				table.insert(people[baby.father].children, baby.id)
			end
			people[id].pregnant = false
			people[id].fetus_is_bastard_of = nil
			logEvent(log,year,"birth",baby.id, baby.father, baby.mother)
		elseif x.alive 
		and x.married 
		and x.gender == "F"
		and x.fertile
		and x.pregnant == false
		and people[x.spouse].alive 
		and math.random() < married_reproduction_chance then
			--Became pregnant
			people[id].pregnant = true
		end
	end)

	-- Handle Divorces
	local broken_homes = {}
	_.forIn(household_bins, function(housemates, household_id) 
		if math.random() < yearly_divorce_chance then
			_.sample(_.compact(_.map(housemates, function(housemate) 
				local a = people[housemate]
				if a.married and 
					a.age < elder_age and 
					people[a.spouse].age < elder_age and 
					people[a.spouse].alive and 
					people[a.spouse].household == a.household then
					if a.gender == "M" then 
						table.insert(broken_homes, { household = household_id, husband = a.id, wife = a.spouse })
					elseif a.gender == "F" then 
						table.insert(broken_homes, { household = household_id, husband = a.spouse, wife = a.id })
					end
				end
			end)))
		end
	end)
	_.each(broken_homes, function(broken_home) 
		local husband = people[broken_home.husband]
		local wife = people[broken_home.wife]
		local others = _.filter(household_bins[broken_home.household], function(person) 
			return person ~= broken_home.husband and person ~= broken_home.wife 
		end)

		--Old Testament assumptions

		husband.married = false 
		wife.married = false
		table.insert(husband.divorces, wife.id)
		table.insert(wife.divorces, husband.id)
		logEvent(log,year,"divorce",husband.id,wife.id)

		local wifes_pater = wife.foster and wife.foster or wife.father 
		if wifes_pater and people[wifes_pater].alive and people[wifes_pater].household ~= wife.household then
			wife.household = people[wifes_pater].household
		elseif wifes_pater and people[wifes_pater].spouse and people[people[wifes_pater].spouse].alive and people[people[wifes_pater].spouse].household ~= wife.household then
			wife.household = people[people[wifes_pater].spouse].household 
		else
			wife.household = household_cntr
			household_cntr = household_cntr + 1
		end
		_.each(others, function(id) 
			local x = people[id]
			if x.foster == wife.id then x.household = wife.household
			elseif x.age < pubescent_age and x.mother == wife.id then x.household = wife.household
			elseif wife.mother == id or wife.father == id then x.household = wife.household
			elseif x.father == husband.id then x.household = husband.household
			else
				x.household = household_cntr
				household_cntr = household_cntr + 1
			end
		end)
	end)

	--Cleanup working set: dead people lie in peace
	working_set = _.filter(working_set, function(id)
		return people[id].alive
	end)

	return people, working_set, locations
end

--Simulate
local log = assert(io.open("output/event.log", "w"))
for year = 1, years_to_simulate do
	people, working_set, locations = simulate_year(log, year, people, working_set, locations)
	print("Year " .. year .. ". Working set is " .. #working_set .. " of " .. #people .. ". ")
end
log.close()
export_people_csv("output/geneology.csv",people)

do --Draw Graphs
	local function drawPerson(context, id, whitespaceprefix)
		local x = people[id]
		local name = x.givennym .. "." .. x.patronym
		local lifeborder = x.alive and "blue" or "gray"
		local fill = x.orphaned and "orange" or (x.is_bastard_of and "red" or "white")
		local gendershape = x.gender == "M" and "square" or "circle"
		if #x.widowedBy > 0 then gendershape = x.gender == "M" and "Msquare" or "Mcircle" end
		context:write(whitespaceprefix..id.." [color="..lifeborder..",style=\"filled\",fillcolor="..fill..",shape="..gendershape..",label=\""..name.."("..x.age..")\"];")
	end
	local function drawRelations(context, id, sameLoc, sameHouse)
		local x = people[id]
		if x.mother and people[x.mother].alive and 
			((sameLoc and x.location == people[x.mother].location) or (not sameLoc)) and
			((sameHouse and x.household == people[x.mother].household) or (not sameHouse)) then
			context:write("\n\t".. x.mother .. "->" .. id .. " [color=blue];")
		elseif x.mother and x.father and people[x.father].alive and not people[x.mother].alive and 
			((sameLoc and x.location == people[x.father].location) or (not sameLoc)) and
			((sameHouse and x.household == people[x.father].household) or (not sameHouse)) then
			--Usually we draw parentage from the mother, but if she has died and the father is alive, draw from him
			context:write("\n\t"..x.father.."->"..id.."[color=purple];")
		end

		if x.foster and people[x.foster].alive and 
			((sameLoc and x.location == people[x.foster].location) or (not sameLoc)) and
			((sameHouse and x.household == people[x.foster].household) or (not sameHouse)) then
			context:write("\n\t"..x.foster.."->"..id.."[color=orange];")
		end
		if x.married and people[x.spouse].alive and x.gender == "F" and 
			((sameLoc and x.location == people[x.spouse].location) or (not sameLoc)) and
			((sameHouse and x.household == people[x.spouse].household) or (not sameHouse)) then
			context:write("\n\t".. x.spouse .. "->" .. id .. " [color=red];")
		end
		if x.is_bastard_of and people[x.is_bastard_of].alive and 
			((sameLoc and x.location == people[x.is_bastard_of].location) or (not sameLoc)) and
			((sameHouse and x.household == people[x.is_bastard_of].household) or (not sameHouse)) then
			context:write("\n\t".. x.is_bastard_of .. "->" .. id .. " [color=green];")
		end
		if #x.divorces > 0 then
			_.each(x.divorces, function(divorcee)
				if ((sameLoc and x.location == people[divorcee].location) or (not sameLoc)) and
					((sameHouse and x.household == people[divorcee].household) or (not sameHouse)) then
					context:write("\n\t"..divorcee.."->"..id.." [color=cyan];")
				end
			end)
		end

	end
	local function drawFullLocation(context, location, location_working_set, out_of_town_is_out_of_town)
		print("Graphing households in " .. locations[location])
		local households = _.groupBy(location_working_set, function(x) return people[x].household end)
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
		local folks_by_location = _.groupBy(working_set, function(x) return locations[people[x].location] end)
		local g = assert(io.open("output/region_map.viz", "w"))
		g:write("strict digraph G {\n\tcompound=true;\n\toverlap=prism;")
		for location = 1, #locations do
			drawFullLocation(g,location,folks_by_location[locations[location]],true)
		end
		g:write("\n}")
		g.close()
	end

	do --Draw Each Location on Own Map
		local folks_by_location = _.groupBy(working_set, function(x) return locations[people[x].location] end)
		for location = 1, #locations do
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
				local sample = people[_.sample(working_set)]
				local shape = sample.gender == "M" and "square" or "circle"
				local myname = sample.givennym.."."..sample.patronym
				print("Graphing geneological history of " .. myname)
				local parent_depth = 6
				function addParents(x,level)
					if level > parent_depth then return end
					if x.mother then
						local mothername = people[x.mother].givennym .. "." .. people[x.mother].patronym
						local isalive
						if people[x.mother].alive then isalive = "blue" else isalive = "gray" end
						g:write("\n\t\t" .. x.mother .. " [shape=circle,color="..isalive..",label=\""..mothername.."("..people[x.mother].age..")\"]")
						g:write("\n\t\t" .. x.mother .. "->" .. x.id .. " [color=blue]")
						addParents(people[x.mother],level+1)
					end
					if x.father then
						local fathername = people[x.father].givennym .. "." .. people[x.father].patronym
						local isalive
						if people[x.father].alive then isalive = "blue" else isalive = "gray" end
						g:write("\n\t\t" .. x.father .. " [shape=square,color="..isalive..",label=\""..fathername.."("..people[x.father].age..")\"]")
						g:write("\n\t\t" .. x.father .. "->" .. x.id .. " [color=red]")
						addParents(people[x.father],level+1)
					end
				end
				function addChildren(x)
					_.each(x.children, function(c)
						local child = people[c]
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


