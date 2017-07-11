local _ = require 'lib/shimmed'

local lastnames_path = "CSV_Database_of_Last_Names.csv"

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

--Utility Functions (Generation)

function get_living_descendents(people, id, depth, acc)
	local me = people[id]
	if acc[depth] == nil then acc[depth] = {} end
	if acc.count == nil then acc.count = 0 end

	if #me.children > 0 then
		_.each(me.children, function(child) 
			if people[child].alive then 
				table.insert(acc[depth],child) 
				acc.count = acc.count + 1
			end
			acc = get_living_descendents(people, child, depth+1, acc) 
		end)
	end
	return acc
end

function relatives_by_distance(people, id, distance, max_distance, breadcrumb)
	local me = people[id]

	local outbound = _.flatten({ me.mother, me.father, me.children })
	local recurse = {}

	if distance < max_distance then
		_.each(outbound, function(relative) 
			if breadcrumb[relative] == nil then
				_.each(outbound, function(r) 
					if breadcrumb[r] == nil then 
						breadcrumb[r] = true 
					end
				end)
				breadcrumb = relatives_by_distance(people, relative, distance+1, max_distance, breadcrumb) 
			end
		end)
	end

	if distance == 0 then
		return _.keys(breadcrumb)
	end

	return breadcrumb
end

function get_living_housemates(people, working_set, id)
	local me = people[id]
	return _.filter(working_set, function(id) 
		return people[id].household == me.household and people[id].alive
	end)
end


function random_person(new_id, location_id, household_id)
	return {
		id = new_id,
		gender = math.random() > 0.5 and "F" or "M",
		alive = true,
		married = false,
		pregnant = false,
		fetus_is_bastard_of = nil,
		is_bastard_of = nil,
		fertile = true,
		orphaned = false,
		father = nil,
		mother = nil,
		foster = nil,
		children = {},
		divorces = {},
		widowedBy = {},
		age = math.random(10,30),
		genetic = math.random(),
		givennym = alphabet[math.random(1,26)],
		patronym = lastnames[math.random(1,#lastnames)],
		household = household_id,
		location = location_id,
		birthyear = -10,
		birthday = math.random(), -- % through year e.g.: 0.088 is evening of February 1st
		deathyear = nil
	}
end

function baby_person(mom,dad)
	return {
		gender = math.random() > 0.5 and "F" or "M",
		alive = true,
		married = false,
		pregnant = false,
		fetus_is_bastard_of = nil,
		is_bastard_of = nil,
		fertile = true,
		orphaned = false,
		father = dad.id,
		mother = mom.id,
		foster = nil,
		household = mom.household,
		location = mom.location,
		children = {},
		divorces = {},
		widowedBy = {},
		age = 0,
		givennym = alphabet[math.random(1,26)],
		patronym = dad.patronym,
		genetic = (dad.genetic + mom.genetic + math.random())/3,
		birthday = math.random() -- % through year e.g.: 0.088 is evening of February 1st
	}
end

--Utility (Data)

function export_people_csv(path, people)
	--Perform data dump
	local exported_fields = {
		"id",
		"givennym",
		"patronym",
		"gender",
		"alive",
		"married",
		"pregnant",
		"fertile",
		"father",
		"mother",
		"foster",
		"children",
		"widowedBy",
		"age",
		"genetic",
		"birthyear",
		"deathyear",
		"household",
		"location"
	}

	local function ngr(x) 
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

	local f = assert(io.open(path, "w"))
	f:write(_.reduce(exported_fields, function(str, field, i, arr) 
		if i == #arr then return str .. field end
		return str .. field .. ", " 
	end, ""))
	_.each(people, function(x) 
		f:write(_.reduce(exported_fields, function(str, field, i, arr) 
			if i == #arr then return str .. ngr(x[field]) end
			return str .. ngr(x[field]) .. ", " 
		end,"\n")) end)
	f.close()
end