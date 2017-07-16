--Imports
local inspect = require 'lib/inspect'
local _ = require 'lib/shimmed'
local mendel = require 'mendel'
local sql = require 'lsqlite3'
require 'make_utils'

--Configuration

local database_path = arg[4] or 'output/data.db'
local years_to_simulate = arg[1] or 100
local people_population = arg[2] or 1000
local sample_people = arg[3] or 10

local infant_yearly_death_chance = 0.07
local child_yearly_death_chance = 0.03
local pubescent_yearly_death_chance = 0.05
local adult_yearly_death_chance = 0.03
local elder_yearly_death_chance = 0.09
local married_reproduction_chance = 0.50
local affair_reproduction_chance = 0.30
local yearly_marriage_chance = 0.40
local yearly_affair_chance = 0.03
local yearly_divorce_chance = 0.01
local widow_catharsis_yearly_chance = 0.8
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

--Setup Database

local db = sql.open(database_path)
local people = {} --cache
local working_set = {}
setupLookup(db,people)

--Seed
math.randomseed(os.time())

local locations = {"Aville","Burb","Chamlet"}

local household_cntr = 1
local people_cntr = 1
for i = 1, people_population do
	local friend = random_person(i,math.random(1,#locations),household_cntr)
	household_cntr = household_cntr + 1
	people_cntr = people_cntr + 1
	insertPerson(friend)
end

function simulate_year(log, year, locations)
	working_set = {}
	for a in db:rows("SELECT id FROM people WHERE alive = 1") do
		table.insert(working_set,a[1])
	end

	local household_bins = _.groupBy(working_set, function(id) return lookupPerson(id).household end)
	--Do Aging
	_.each(working_set, function (id)
		x = lookupPerson(id)
		if not x.alive then return x end
		local age = x.age
		if (age >= infanthood_age and age < childhood_age and math.random() < infant_yearly_death_chance)
		or (age >= childhood_age  and age < pubescent_age and math.random() < child_yearly_death_chance)
		or (age >= pubescent_age and age < adulthood_age and math.random() < pubescent_yearly_death_chance)
		or (age >= adulthood_age and age < elder_age and math.random() < adult_yearly_death_chance)
		or (age >= elder_age and math.random() < elder_yearly_death_chance
		or (age >= maximum_age)) then
			modifyPerson(id, "alive", false)
			modifyPerson(id, "deathyear", year)
			logEvent(log,year,"death",id)
			--Handle widows & widowers
			if x.married then
				local spouse = lookupPerson(x.spouse)
				if lookupPerson(x.spouse).alive then
					local z = lookupPerson(x.spouse).widowedBy
					table.insert(z,id)
					modifyPerson(x.spouse,"widowedBy",z)
					if #lookupPerson(x.spouse).children == 0 then
						modifyPerson(x.spouse,"married",false) --allow remarriage if childless)
					end
				end
			end
			--Handle orphans
			if #x.children > 0 then
				_.each(x.children, function(cid) 
					local child = lookupPerson(cid)
					if child.age < adulthood_age and 
						(child.mother and not lookupPerson(child.mother).alive) and 
						(child.father and not lookupPerson(child.father).alive) then
						modifyPerson(cid,"orphaned",true)
					end
				end)
			end
		else
			modifyPerson(id,"age",lookupPerson(id).age + 1)
			if x.orphaned and x.age >= adulthood_age then
				modifyPerson(x.id,"orphaned",false)
			end
			if x.gender == "F" and x.age >= menopause_age then
				modifyPerson(x.id,"fertile",false)
			end
			if x.widowedBy and x.married and not lookupPerson(x.spouse).alive and x.age >= adulthood_age and math.random() < widow_catharsis_yearly_chance then
				logEvent(log,year,"widow_catharsis",id)
				modifyPerson(id,"married",false)
			end
		end
	end)

	--Do Adoption & Elder Caretaking
	_.each(working_set, function(id)
		local x = lookupPerson(id)
		--Handle lonely elderly moving in with grown children
		if x.age >= elder_age and
			#household_bins[x.household] == 1 and
			math.random() < retire_with_children_chance then

			local my_descendents = get_living_descendents(id, 0, {})
			if my_descendents.count > 0 then
				local unplaced = true
				local depth = 1
				while unplaced and my_descendents[depth] do
					local retire_with = _.sample(_.filter(my_descendents[depth], function(desc_id) return lookupPerson(desc_id).age >= adulthood_age end))
					if retire_with then
						unplaced = false
						modifyPerson(x.id,"household",lookupPerson(retire_with).household )
						modifyPerson(x.id,"location",lookupPerson(retire_with).location )
					end
					depth=depth+1
				end
			end
		end
		--Handle orphans moving in with family members
		if x.age < adulthood_age and x.orphaned and (not x.foster or (x.foster and not lookUpPerson(x.foster).alive)) then
			local live_with = _.sample(_.filter(relatives_by_distance(id, 0, 4, {}) ,function(cid) 
					local adopter = lookupPerson(cid)
					return adopter.age >= adulthood_age and adopter.alive
				end))
			if live_with ~= nil then
				modifyPerson(x.id,"household",lookupPerson(live_with).household)
				modifyPerson(x.id,"location",lookupPerson(live_with).location)
				modifyPerson(x.id,"foster",live_with)
			end
		end
	end)

	--Do Marriage
	_.forIn(
		_.groupBy(working_set, function(id)
			local x = lookupPerson(id)
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
			local brides = _.sort(_.filter(participants, function(id) return lookupPerson(id).gender == "F" end), function(a,b) return lookupPerson(a).genetic < lookupPerson(b).genetic end)
			local grooms = _.sort(_.filter(participants, function(id) return lookupPerson(id).gender == "M" end), function(a,b) return lookupPerson(a).genetic < lookupPerson(b).genetic end)
			for i = 1, #brides do
				if grooms and grooms[i] then
					-- incest taboo
					local bride = brides[i]
					local groom = grooms[i]
					local bridemother = lookupPerson(bride).mother
					local bridefather = lookupPerson(bride).father
					local groommother = lookupPerson(groom).mother
					local groomfather = lookupPerson(groom).father
					if not(
						(bridemother and groommother and (bridemother == groommother)) or
						(bridefather and groomfather and (bridefather == groomfather))) then
						modifyPerson(groom,"married",true)
						modifyPerson(bride,"married",true)
						modifyPerson(groom,"spouse",bride)
						modifyPerson(bride,"spouse",groom)
						logEvent(log,year,"marriage",groom,bride)
						if groom_joins_bride_household then 
							modifyPerson(groom,"household",lookupPerson(bride).household)
							modifyPerson(groom,"location",lookupPerson(bride).location)
						elseif bride_joins_groom_household then
							modifyPerson(bride,"household",lookupPerson(groom).household)
							modifyPerson(bride,"location",lookupPerson(groom).location)
						elseif couples_begin_new_household then
							modifyPerson(groom,"household",household_cntr)
							modifyPerson(bride,"household",household_cntr)
							modifyPerson(groom,"location",math.random() > 0.5 and lookupPerson(groom).location or lookupPerson(bride).location)
							modifyPerson(bride,"location",lookupPerson(groom).location)
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
				local x = lookupPerson(id)
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
			local women = _.sort(_.filter(participants, function(id) return lookupPerson(id).gender == "F" end), function(a,b) return lookupPerson(a).genetic < lookupPerson(b).genetic end)
			local men = _.sort(_.filter(participants, function(id) return lookupPerson(id).gender == "M" end), function(a,b) return lookupPerson(a).genetic < lookupPerson(b).genetic end)
			for i = 1, #women do
				if men and men[i] and lookupPerson(men[i]).genetic > lookupPerson(lookupPerson(women[i]).spouse).genetic then
					logEvent(log, year, "affair", men[i], women[i])
					if math.random() < affair_reproduction_chance and lookupPerson(women[i]).fertile and x.pregnant == false then
						modifyPerson(women[i],"pregnant",true )
						modifyPerson(women[i],"fetus_is_bastard_of",men[i])
					end
				end
			end
		end
	)

	-- Handle Birth & Pregnancy
	_.each(working_set, function(id)
		local x = lookupPerson(id)
		if x.alive 
		and x.gender == "F" 
		and x.pregnant then
			--Finished pregnancy
			local father = x.fetus_is_bastard_of and x.fetus_is_bastard_of or x.spouse
			local baby = baby_person(x,lookupPerson(father))

			baby.id = people_cntr + 1
			people_cntr = people_cntr + 1
			baby.birthyear = year
			baby.is_bastard_of = x.fetus_is_bastard_of and x.fetus_is_bastard_of or nil
			if baby.is_bastard_of then 
				--Assume cuckold adopts
				baby.patronym = lookupPerson(x.spouse).patronym 
				baby.foster = x.spouse
				logEvent(log, year, "bastard_adoption", baby.id, baby.foster, baby.mother, baby.is_bastard_of)
			end
			insertPerson(baby)
			table.insert(working_set,baby.id)
			local z = lookupPerson(baby.mother).children 
			table.insert(z, baby.id)
			modifyPerson(baby.mother,"children",z)
			if not baby.is_bastard_of then
				z = lookupPerson(baby.father).children 
				table.insert(z, baby.id)
				modifyPerson(baby.father,"children",z)
			end
			modifyPerson(id,"pregnant",false)
			modifyPerson(id,"fetus_is_bastard_of",nil)
			logEvent(log,year,"birth",baby.id, baby.father, baby.mother)
		elseif x.alive 
		and x.married 
		and x.gender == "F"
		and x.fertile
		and x.pregnant == false
		and x.spouse and lookupPerson(x.spouse).alive 
		and math.random() < married_reproduction_chance then
			print("Pregnancy")
			--Became pregnant
			modifyPerson(id,"pregnant",true)
		end
	end)

	-- Handle Divorces
	local broken_homes = {}
	_.forIn(household_bins, function(housemates, household_id) 
		if math.random() < yearly_divorce_chance then
			_.sample(_.compact(_.map(housemates, function(housemate) 
				local a = lookupPerson(housemate)
				if a.married and 
					a.age < elder_age and 
					lookupPerson(a.spouse).age < elder_age and 
					lookupPerson(a.spouse).alive and 
					lookupPerson(a.spouse).household == a.household then
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
		local husband = lookupPerson(broken_home.husband)
		local wife = lookupPerson(broken_home.wife)
		local others = _.filter(household_bins[broken_home.household], function(person) 
			return person ~= broken_home.husband and person ~= broken_home.wife 
		end)

		--Old Testament assumptions

		modifyPerson(husband.id,"married",false )
		modifyPerson(wife.id,"married",false)
		table.insert(husband.divorces, wife.id)
		table.insert(wife.divorces, husband.id)
		logEvent(log,year,"divorce",husband.id,wife.id)

		local wifes_pater = wife.foster and wife.foster or wife.father 
		if wifes_pater and lookupPerson(wifes_pater).alive and lookupPerson(wifes_pater).household ~= wife.household then
			modifyPerson(wife.id,"household",lookupPerson(wifes_pater).household)
		elseif wifes_pater and lookupPerson(wifes_pater).spouse and lookupPerson(lookupPerson(wifes_pater).spouse).alive and lookupPerson(lookupPerson(wifes_pater).spouse).household ~= wife.household then
			modifyPerson(wife.id,"household",lookupPerson(lookupPerson(wifes_pater).spouse).household )
		else
			modifyPerson(wife.id,"household",household_cntr)
			household_cntr = household_cntr + 1
		end
		_.each(others, function(id) 
			local x = lookupPerson(id)
			if x.foster == wife.id then x.household = wife.household
			elseif x.age < pubescent_age and x.mother == wife.id then x.household = wife.household
			elseif wife.mother == id or wife.father == id then x.household = wife.household
			elseif x.father == husband.id then x.household = husband.household
			else
				modifyPerson(x.id,"household",household_cntr)
				household_cntr = household_cntr + 1
			end
		end)
	end)

	--Cleanup working set: dead people lie in peace
	working_set = _.filter(working_set, function(id)
		local z = lookupPerson(id).alive
		return lookupPerson(id).alive
	end)

	return working_set, locations
end

--Simulate
local log = assert(io.open("output/event.log", "w"))

for year = 1, years_to_simulate do
	working_set, locations = simulate_year(log, year, working_set, locations)
	print("Year " .. year .. ". Working set is " .. #working_set)
end
log.close()

do --Draw Graphs
	local function drawPerson(context, id, whitespaceprefix)
		local x = lookupPerson(id)
		local name = x.givennym .. "." .. x.patronym
		local lifeborder = x.alive and "blue" or "gray"
		local fill = x.orphaned and "orange" or (x.is_bastard_of and "red" or "white")
		local gendershape = x.gender == "M" and "square" or "circle"
		if #x.widowedBy > 0 then gendershape = x.gender == "M" and "Msquare" or "Mcircle" end
		context:write(whitespaceprefix..id.." [color="..lifeborder..",style=\"filled\",fillcolor="..fill..",shape="..gendershape..",label=<<FONT POINT-SIZE=\"120\">"..name.."("..x.age..")</FONT><BR ALIGN=\"CENTER\"/>"..mendel.describeFace(name, x.genome)..">];")
	end
	local function drawRelations(context, id, sameLoc, sameHouse)
		local x = lookupPerson(id)
		print("Drawing relation for: " .. inspect(x))
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

db:close()


