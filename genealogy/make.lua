--Imports
local inspect = require 'inspect'
local _ = require 'shimmed'

--Configuration

local years_to_simulate = 500
local summary_period = 1
local male_female_population_ratio = 0.47 / 0.53
local people_population = 1000
local infant_yearly_death_chance = 0.07 -- 0-2
local child_yearly_death_chance = 0.03 -- 3-9
local pubescent_yearly_death_chance = 0.05 -- 10-14
local adult_yearly_death_chance = 0.03 -- 15-49
local elder_yearly_death_chance = 0.09 -- 50+
local married_reproduction_chance = 0.50
local marriage_market_eligibility_chance = 0.40
local infanthood_age = 0
local childhood_age = 3
local pubescent_age = 10
local adulthood_age = 15 -- age at which marriage is allowed
local spinster_age = 36
local menopause_age = 40
local elder_age = 50
local bride_joins_groom_household = true
local groom_joins_bride_household = false
local lastnames_path = "CSV_Database_of_Last_Names.csv"
local sample_people = 10

--Load helper data
local alphabet = {"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"}
local lastnames_file = assert(io.open(lastnames_path,"rb"))
local lastnames = {}
while true do
	local line = lastnames_file:read("*l")
	if line == nil then break
	else
		table.insert(lastnames,""..line)
	end
end
lastnames_file.close()


function baby_person(mom,dad)
	return {
		gender = math.random() > 0.5 and "F" or "M",
		alive = true,
		married = false,
		pregnant = false,
		fertile = true,
		father = dad.id,
		mother = mom.id,
		household = mom.household,
		children = {},
		dead_children = 0,
		age = 0,
		givennym = alphabet[math.random(1,26)],
		patronym = dad.patronym,
		genetic = (dad.genetic + mom.genetic + math.random())/3,
		birthyear = year,
		birthday = math.random() -- % through year e.g.: 0.088 is evening of February 1st
	}
end

function random_person(new_id, household_id)
	return {
		id = new_id,
		gender = (2 * math.random() > male_female_population_ratio) and "F" or "M",
		alive = true,
		married = false,
		pregnant = false,
		fertile = true,
		father = nil,
		mother = nil,
		children = {},
		dead_children = 0,
		age = math.random(10,30),
		genetic = math.random(),
		givennym = alphabet[math.random(1,26)],
		patronym = lastnames[math.random(1,#lastnames)],
		household = household_id,
		birthyear = -10,
		deathyear = nil
	}
end

--Seed
math.randomseed(os.time())
local people = {}
local working_set = {}
for i = 1, people_population do
	local friend = random_person(i,i)
	table.insert(working_set, i)
	table.insert(people, friend)
end

--Simulate
for year = 1, years_to_simulate do

	--Do Aging
	local deaths = 0
	local survivals = 0
	_.each(working_set, function (id)
		x = people[id]
		if not x.alive then return x end
		local age = x.age
		if (age >= infanthood_age and age < childhood_age and math.random() < infant_yearly_death_chance)
		or (age >= childhood_age  and age < pubescent_age and math.random() < child_yearly_death_chance)
		or (age >= pubescent_age and age < adulthood_age and math.random() < pubescent_yearly_death_chance)
		or (age >= adulthood_age and age < elder_age and math.random() < adult_yearly_death_chance)
		or (age >= elder_age and math.random() < elder_yearly_death_chance) then
			people[id].alive = false
			people[id].deathyear = year
		else
			people[id].age = people[id].age + 1
		end
	end)

	--Do Marriage
	local marriages = 0
	local brides = _.filter(working_set, function(id)
				local x = people[id] 
				return x.alive 
				and not x.married
				and x.age >= adulthood_age and x.age < elder_age 
				and x.gender == "F"
				and x.age < spinster_age
				and math.random() < marriage_market_eligibility_chance 
			end)
	local grooms = _.filter(working_set, function(id)
				local x = people[id] 
				return x.alive 
				and not x.married
				and x.age >= adulthood_age and x.age < elder_age 
				and x.gender == "M"
				and math.random() < marriage_market_eligibility_chance 
			end)
	local new_marriages = {}
	if #brides > 0 and #grooms > 0 then
		table.sort(brides, function(a,b) return people[a].genetic < people[b].genetic end)
		table.sort(grooms, function(a,b) return people[a].genetic < people[b].genetic end)
		for i = 1, #brides do
			if grooms[i] then
				-- incest taboo
				bridemother = people[brides[i]].mother
				bridefather = people[brides[i]].father
				groommother = people[grooms[i]].mother
				groomfather = people[grooms[i]].father
				if not(
					(bridemother and groommother and (bridemother == groommother)) or
					(bridefather and groomfather and (bridefather == groomfather))) then
					new_marriages[brides[i]] = grooms[i]
					new_marriages[grooms[i]] = brides[i]
					marriages = marriages + 1
				end
			end
		end
	end
	_.each(working_set, function(id) 
		local x = people[id]
		if new_marriages[id] then
			people[id].married = true
			people[id].spouse = new_marriages[id]
			if groom_joins_bride_household and x.gender == "M" then 
				people[id].household = people[new_marriages[id]].household
			elseif bride_joins_groom_household and x.gender == "F" then
				people[id].household = people[new_marriages[id]].household
			end
		end
	end)

	-- Handle Birth & Pregnancy
	local births = 0
	local pregnancies = 0
	local new_babies = {}
	_.each(working_set, function(id)
		local x = people[id]
		if x.alive 
		and x.gender == "F" 
		and x.pregnant then
			--Finished pregnancy
			local baby = baby_person(x,people[x.spouse])
			table.insert(new_babies, baby)
			people[id].pregnant = false
			births = births + 1
		elseif x.alive 
		and x.married 
		and x.gender == "F"
		and x.age < menopause_age
		and x.pregnant == false
		and people[x.spouse].alive 
		and math.random() < married_reproduction_chance then
			--Became pregnant
			people[id].pregnant = true
			pregnancies = pregnancies + 1
		end
	end)
	_.each(new_babies, function(x)
		x.id = #people+1
		table.insert(people,x)
		table.insert(working_set,x.id)
		table.insert(people[x.mother].children, x.id)
		table.insert(people[x.father].children, x.id)
	end)

	print("Year " .. year)
end

--Utility

function get_ids_by_familial_distance(person_id, distance, genetic_only)
	if person_id and distance <= 0 then return person_id end

	local person = people[person_id]
	local people = {}
	local relations = {}

	if person.father then
		table.insert(people, target)
		table.insert(relations, { src = person_id, dst = person.father, kind = 'father'})
		table.insert(relations, { src = person.father, dst = person_id, kind = 'child'})
	end
	if person.mother then
		table.insert(people, target)
		table.insert(relations, { src = person_id, dst = person.mother, kind = 'mother'})
		table.insert(relations, { src = person.mother, dst = person_id, kind = 'child'})
	end
	if person.spouse and not genetic_only then
		table.insert(people, target)
		table.insert(relations, { src = person_id, dst = person.spouse, kind = 'spouse'})
		table.insert(relations, { src = person.spouse, dst = person_id, kind = 'child'})
	end
	if person.children and #person.children > 0 then
		_.each(person.children, function(child) 
				table.insert(relations, { src = person_id, dst = child, kind = person.gender == "M" and 'father' or 'mother'})
				table.insert(relations, { src = child, dst = person_id, kind = 'child'})
			end)
	end
	table.insert(result, get_by_familial_distance(person.mother,distance-1))
	if not genetic_only then table.insert(result, get_by_familial_distance(person.spouse,distance-1)) end

	return _.uniq(_.flatten(people)), relations
end

--Perform data dump
local csv_header = "id, firstname, lastname, gender, alive, married, pregnant, fertile, father, mother, children, age, genetic, birthyear, deathyear"
function ngr(x) 
	if x == nil then 
		return ""
	elseif 'table' == type(x) then
		return _.reduce(x, function(acc,k)
			if acc == nil then
				return "" .. k
			else
				return acc .. "&" .. k
			end
		end,"")
	else 
		return tostring(x) 
	end 
end
function person_to_csv(x)
	return ngr(x.id) .. ","
	 .. ngr(x.givennym) .. ","
	 .. ngr(x.patronym) .. "," 
	 .. ngr(x.gender) .. "," 
	 ..  ngr(x.alive) .. "," 
	 .. ngr(x.married) .. "," 
	 ..  ngr(x.pregnant) .. "," 
	 ..  ngr(x.fertile) .. "," 
	 .. ngr(x.father) .. "," 
	 .. ngr(x.mother) .. "," 
	 .. ngr(x.children) .. "," 
	 ..  ngr(x.age) .. "," 
	 .. ngr(x.genetic) .. "," 
	 ..  ngr(x.birthyear) .. "," 
	 .. ngr(x.deathyear)
end
local f = assert(io.open("geneology.csv", "w"))
f:write(csv_header)
_.each(people, function(x) f:write("\n" .. person_to_csv(x)) end)
f.close()

--Draw graphs
local g
--Perform living population geneology graphviz
g = assert(io.open("family_tree.viz", "w"))
g:write("strict digraph G {compound=true;overlap=scale;")
g:write("\n\tsubgraph cluster_matrilineal {")
_.each( people, function(x)
	if x.alive then
		if x.mother then
			local fathername = people[x.father].givennym .. "." .. people[x.father].patronym
			if not people[x.mother].alive then
				local mothername = people[x.mother].givennym .. "." .. people[x.mother].patronym
				g:write("\n\t\t"..x.mother.." [color=gray,shape=circle,label=\""..mothername.."("..people[x.mother].age..")\"]")
			end
			if not people[x.father].alive then
				g:write("\n\t\t"..x.father.." [color=gray,shape=square,label=\""..fathername.."("..people[x.father].age..")\"]")
				g:write("\n\t\t".. x.father .. "->" .. x.mother .. " [color=red]")
			end
			g:write("\n\t\t".. x.mother .. "->" .. x.id .. " [color=blue]")
		end
		local shape
		if x.gender == "M" then shape = "square" else shape = "circle" end
		local myname = x.givennym.."."..x.patronym
		g:write("\n\t\t" .. x.id .. " [color=blue,shape="..shape..",label=\""..myname.."("..x.age..")\"]")
	end
end)
g:write("\n\t}")
g:write("\n\tsubgraph cluster_patrilineal {")
_.each( people, function(x)
	if x.alive then 
		if x.married and x.gender == "M" then
			g:write("\n\t\t".. x.id .. "->" .. x.spouse .. " [color=red]")
			if not people[x.spouse].alive then
				local spousename = people[x.spouse].givennym .. "." .. people[x.spouse].patronym
				g:write("\n\t\t" .. x.spouse .. " [color=gray,shape=circle,label=\""..spousename.."("..people[x.spouse].age..")\"]")
			end
		end
	end
end)
g:write("\n\t}")
g:write("\n}")
g.close()

--Sample a living person and show their full lineage
for i = 1, sample_people do
	g = assert(io.open("sample_person_"..i..".viz", "w"))
	g:write("strict digraph G {compound=true; overlap=scale;")
	g:write("\n\tsubgraph cluster_ancestors {")
		local sample = _.sample(_.filter(people, function(x) return x.alive end))
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
		local shape
		if sample.gender == "M" then shape = "square" else shape = "circle" end
		local myname = sample.givennym.."."..sample.patronym
		g:write("\n\t\t" .. sample.id .. " [color=orange,shape="..shape..",label=\""..myname.."("..sample.age..")\"]")
		addParents(sample,1)
		addChildren(sample)
	g:write("\n\t}")
	g:write("\n}")
	g.close()
end



