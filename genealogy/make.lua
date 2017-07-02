--Imports
local inspect = require 'inspect'
local _ = require 'shimmed'

--Configuration

local years_to_simulate = 500
local summary_period = 1
local male_female_population_ratio = 0.47 / 0.53
local seed_cohort_population = 1000
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
local seed_cohort = {}
for i = 1, seed_cohort_population do
	table.insert(seed_cohort, random_person(i,i))
end

--Simulate
for year = 1, years_to_simulate do

	--Do Aging
	local deaths = 0
	local survivals = 0
	seed_cohort = _.map(seed_cohort, function (x)
		if not x.alive then return x end
		local age = x.age
		if (age >= infanthood_age and age < childhood_age and math.random() < infant_yearly_death_chance)
		or (age >= childhood_age  and age < pubescent_age and math.random() < child_yearly_death_chance)
		or (age >= pubescent_age and age < adulthood_age and math.random() < pubescent_yearly_death_chance)
		or (age >= adulthood_age and age < elder_age and math.random() < adult_yearly_death_chance)
		or (age >= elder_age and math.random() < elder_yearly_death_chance) then
			x.alive = false
			x.deathyear = year
			if seed_cohort[x.mother] and seed_cohort[x.mother].alive then
				seed_cohort[x.mother].dead_children = seed_cohort[x.mother].dead_children + 1
			end
			if seed_cohort[x.father] and seed_cohort[x.father].alive  then
				seed_cohort[x.father].dead_children = seed_cohort[x.father].dead_children + 1
			end
			deaths = deaths + 1
		else
			x.age = x.age + 1
			survivals = survivals +1
		end
		return x
	end)



	--Do Marriage
	local marriages = 0
	local brides = _.filter(seed_cohort, function(x) 
				return x.alive 
				and not x.married
				and x.age >= adulthood_age and x.age < elder_age 
				and x.gender == "F"
				and x.age < spinster_age
				and math.random() < marriage_market_eligibility_chance 
			end)
	local grooms = _.filter(seed_cohort, function(x) 
				return x.alive 
				and not x.married
				and x.age >= adulthood_age and x.age < elder_age 
				and x.gender == "M"
				and math.random() < marriage_market_eligibility_chance 
			end)
	local new_marriages = {}
	if #brides > 0 and #grooms > 0 then
		table.sort(brides, function(a,b) return a.genetic < b.genetic end)
		table.sort(grooms, function(a,b) return a.genetic < b.genetic end)
		for i = 1, #brides do
			if grooms[i] then
				-- incest taboo
				bridemother = brides[i].mother
				bridefather = brides[i].father
				groommother = grooms[i].mother
				groomfather = grooms[i].father
				if not(
					(bridemother and groommother and (bridemother == groommother)) or
					(bridefather and groomfather and (bridefather == groomfather))) then

					new_marriages[brides[i].id] = grooms[i].id
					new_marriages[grooms[i].id] = brides[i].id
					marriages = marriages + 1
				else
					print("Siblings were paired, but denied to marry each other, obviously")
				end
			end
		end
	end
	seed_cohort = _.map(seed_cohort, function(x) 
		if new_marriages[x.id] then
			x.married = true
			x.spouse = new_marriages[x.id]
			if groom_joins_bride_household and x.gender == "M" then 
				x.household = seed_cohort[new_marriages[x.id]].household
			elseif bride_joins_groom_household and x.gender == "F" then
				x.household = seed_cohort[new_marriages[x.id]].household
			end
		end
		return x
	end)

	-- Handle Birth & Pregnancy
	local births = 0
	local pregnancies = 0
	local new_babies = {}
	seed_cohort = _.map(seed_cohort, function(x)
		if x.alive 
		and x.gender == "F" 
		and x.pregnant then
			local baby = baby_person(x,seed_cohort[x.spouse])
			baby.id = #seed_cohort+1
			table.insert(seed_cohort, baby)
			table.insert(seed_cohort[baby.mother].children, baby.id)
			table.insert(seed_cohort[baby.father].children, baby.id)
			--table.insert(new_babies, baby)
			x.pregnant = false
			births = births + 1
		elseif x.alive 
		and x.married 
		and x.gender == "F"
		and x.age < menopause_age
		and x.pregnant == false
		and seed_cohort[x.spouse].alive 
		and math.random() < married_reproduction_chance then
			x.pregnant = true
			pregnancies = pregnancies + 1
		end

		return x
	end)

	-- Yearly Stat Collection
	if year % summary_period == 0 then 
		local patronyms = {}
		local live_stats = _.reduce(seed_cohort, function(acc, x) 
			acc.total = acc.total+1
			if x.alive then 
				acc.alive = acc.alive + 1
				if x.gender == "M" then
					acc.male = acc.male + 1
				else
					acc.female = acc.female + 1
				end
				if x.married then
					if seed_cohort[x.spouse].alive then
						acc.married = acc.married + 1
					else
						acc.widowed = acc.widowed + 1
					end
				elseif x.age >= adulthood_age then
					acc.unmarried = acc.unmarried + 1
				elseif x.age < adulthood_age and x.age >= childhood_age then
					acc.kids = acc.kids + 1
				elseif x.age < childhood_age then
					acc.infants = acc.infants + 1
				end

				acc.alive_genetic = acc.alive_genetic + x.genetic
				if patronyms[x.patronym] == nil then patronyms[x.patronym] = 1
				else patronyms[x.patronym] = patronyms[x.patronym] + 1 end
			else
				acc.dead = acc.dead+1
			end
			return acc
		end, {total = 0, dead = 0, alive = 0, male = 0, female = 0, married = 0, widowed = 0, unmarried = 0, kids = 0, infants = 0, max_parented = 0, parents = 0, alive_genetic = 0, total_dead_children = 0, parents_with_dead_children = 0, surviving_patronyms = 0})

		local keyset={}
		local n=0

		for k,v in pairs(patronyms) do
		  n=n+1
		  keyset[n]=k
		end

		print("YEAR " .. year .. " -- " .. 
			"total:" .. live_stats.total .. 
			" alive:" .. live_stats.alive .. 
			" births:" .. births .. 
			" deaths:" .. deaths 
			--" dead:" .. live_stats.dead .. 
			--" male:" .. live_stats.male .. 
			--" female:" .. live_stats.female .. 
			--" married:" .. live_stats.married .. 
			--" widowed:" .. live_stats.widowed .. 
			--" unmarried:" .. live_stats.unmarried .. 
			--" kids:" .. live_stats.kids ..
			--" infants:" .. live_stats.infants ..
			--" survivals:" .. survivals .. 
			--" marriages:" .. marriages .. 
			--" pregnancies:" .. pregnancies .. 
			--" max_parented:" .. live_stats.max_parented ..
			--" parents:" .. live_stats.parents ..
			--" avg.clutch:" .. (live_stats.children/live_stats.parents) .. 
			--" avg.genetic:" .. (live_stats.alive_genetic/live_stats.alive) ..
			--" parents_with_dead_children" .. live_stats.parents_with_dead_children .. 
			--" avg.dead_children:" .. (live_stats.total_dead_children/live_stats.parents_with_dead_children) ..
			--" avg.live_children:" .. ((live_stats.children/live_stats.parents) - (live_stats.total_dead_children/live_stats.parents_with_dead_children))
			)
	end
	--]]
end

--Perform data dump
local csv_header = "id, name, gender, alive, married, pregnant, fertile, father, mother, children, age, genetic, birthyear, deathyear"
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
	return ngr(x.id) .. "," .. ngr(x.givennym) .. "." .. ngr(x.patronym) .. "," .. ngr(x.gender) .. "," ..  ngr(x.alive) .. "," .. ngr(x.married) .. "," ..  ngr(x.pregnant) .. "," ..  ngr(x.fertile) .. "," .. ngr(x.father) .. "," .. ngr(x.mother) .. "," .. ngr(x.children) .. "," ..  ngr(x.age) .. "," .. ngr(x.genetic) .. "," ..  ngr(x.birthyear) .. "," .. ngr(x.deathyear)
end
local f = assert(io.open("geneology.csv", "w"))
_.each(seed_cohort, function(x) f:write("\n" .. person_to_csv(x)) end)
f.close()

--Draw graphs
local g
--Perform living population geneology graphviz
g = assert(io.open("family_tree.viz", "w"))
g:write("strict digraph G {compound=true;overlap=scale;")
g:write("\n\tsubgraph cluster_matrilineal {")
_.each( seed_cohort, function(x)
	if x.alive then
		if x.mother then
			local fathername = seed_cohort[x.father].givennym .. "." .. seed_cohort[x.father].patronym
			if not seed_cohort[x.mother].alive then
				local mothername = seed_cohort[x.mother].givennym .. "." .. seed_cohort[x.mother].patronym
				g:write("\n\t\t"..x.mother.." [color=gray,shape=circle,label=\""..mothername.."("..seed_cohort[x.mother].age..")\"]")
			end
			if not seed_cohort[x.father].alive then
				g:write("\n\t\t"..x.father.." [color=gray,shape=square,label=\""..fathername.."("..seed_cohort[x.father].age..")\"]")
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
_.each( seed_cohort, function(x)
	if x.alive then 
		if x.married and x.gender == "M" then
			g:write("\n\t\t".. x.id .. "->" .. x.spouse .. " [color=red]")
			if not seed_cohort[x.spouse].alive then
				local spousename = seed_cohort[x.spouse].givennym .. "." .. seed_cohort[x.spouse].patronym
				g:write("\n\t\t" .. x.spouse .. " [color=gray,shape=circle,label=\""..spousename.."("..seed_cohort[x.spouse].age..")\"]")
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
		local sample = _.sample(_.filter(seed_cohort, function(x) return x.alive end))
		local parent_depth = 6
		function addParents(x,level)
			if level > parent_depth then return end
			if x.mother then
				local mothername = seed_cohort[x.mother].givennym .. "." .. seed_cohort[x.mother].patronym
				local isalive
				if seed_cohort[x.mother].alive then isalive = "blue" else isalive = "gray" end
				g:write("\n\t\t" .. x.mother .. " [shape=circle,color="..isalive..",label=\""..mothername.."("..seed_cohort[x.mother].age..")\"]")
				g:write("\n\t\t" .. x.mother .. "->" .. x.id .. " [color=blue]")
				addParents(seed_cohort[x.mother],level+1)
			end
			if x.father then
				local fathername = seed_cohort[x.father].givennym .. "." .. seed_cohort[x.father].patronym
				local isalive
				if seed_cohort[x.father].alive then isalive = "blue" else isalive = "gray" end
				g:write("\n\t\t" .. x.father .. " [shape=square,color="..isalive..",label=\""..fathername.."("..seed_cohort[x.father].age..")\"]")
				g:write("\n\t\t" .. x.father .. "->" .. x.id .. " [color=red]")
				addParents(seed_cohort[x.father],level+1)
			end
		end
		function addChildren(x)
			_.each(x.children, function(c)
				local child = seed_cohort[c]
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



