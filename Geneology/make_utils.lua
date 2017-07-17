local _ = require 'lib/lodash'
local inspect = require 'lib/inspect'
local mendel = require 'mendel'

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

function relatives_by_distance(id, distance, max_distance, breadcrumb)
	local me = lookupPerson(id)

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
				breadcrumb = relatives_by_distance(relative, distance+1, max_distance, breadcrumb) 
			end
		end)
	end

	if distance == 0 then
		return _.keys(breadcrumb)
	end

	return breadcrumb
end

function get_living_housemates(working_set, id)
	local me = lookupPerson(id)
	return _.filter(working_set, function(id) 
		return lookupPerson(id).household == me.household and lookupPerson(id).alive
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
		age = 15,--math.random(10,30),
		genetic = math.random(),
		genome = nil, --mendel.randomGenome(),
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
		genome = nil, --mendel.reproduce(mom.genome, dad.genome),
		birthday = math.random() -- % through year e.g.: 0.088 is evening of February 1st
	}
end

--Utility (Data)

local exported_fields = {
	"id",
	"givennym",
	"patronym",
	"gender",
	"alive",
	"married",
	"pregnant",
	"fertile",
	"orphaned",
	"father",
	"mother",
	"foster",
	"spouse",
	"fetus_is_bastard_of",
	"divorces",
	"children",
	"widowedBy",
	"age",
	"genetic",
	"genome",
	"birthyear",
	"deathyear",
	"household",
	"location"
}

function ngr(x) 
	if x == nil then 
		return "NULL"
	elseif 'boolean' == type(x) then
		return x and 1 or 0
	elseif 'table' == type(x) then
		local z = _.reduce(x, function(acc,k)
			if acc == "" then
				return k
			else
				return acc .. "," .. k
			end
		end,"")
		return "["..z.."]"
	elseif tonumber(x) ~= nil then
		return x
	else 
		return tostring(x)
	end 
end

local lookup_db = nil
local lookup_cache = nil

function setupLookup(db, cache)
	lookup_db = db 
	lookup_cache = cache 

	local schema = _.reduce(exported_fields, function(acc, e) 
		if acc == "" then return "\""..e.."\"" else return acc .. ", " .. "\""..e.."\"" end
	end,"")
	lookup_db:exec(string.format("CREATE TABLE people ( %s )",schema))
end

function lookupPerson(id)
	for a in lookup_db:rows(string.format("SELECT * FROM people WHERE id = %i LIMIT 1", id)) do
		local result = {}
		for i = 1, #exported_fields do
			local k = exported_fields[i]
			local v = a[i]
			if k == 'married' or k == 'pregnant' or k == 'fertile' or k == 'alive' or k == 'orphaned' then
				if(v == 0 or v == "" or v == nil or v == 'false' or v == "0") then
					v = false
				else
					v = true
				end
			elseif k == 'widowedBy' or k == 'children' or k == 'genome' or k == 'divorces' then
				local t={} ; i=1
		        for str in string.gmatch(v, "([^"..".".."]+)") do
		        	str = str:gsub('\\[','')
		        	str = str:gsub('\\]','')
		        	if str ~= "" and str ~= "[" and str ~= "]" and str ~= "[]" then
		        		if tonumber(str) ~= nil then
		                	t[i] = tonumber(str)
		                else
		                	t[i] = tonumber(str)
		                end
		                i = i + 1
		            end
		        end
		        v = t
			end
			if v == "nil" or v == "NULL" or v == "" then
				v = nil
			end
			result[k] = v
		end
		return result
	end
end

function modifyPerson(id, key, value)
	local cmd = ""
	if type(value) == 'number' or type(value) == 'boolean' then
		cmd = string.format("UPDATE people SET %s = %s WHERE id = %i",key,ngr(value),id)
	else
		cmd = string.format("UPDATE people SET %s = '%s' WHERE id = %i",key,ngr(value),id)
	end
	lookup_db:exec(cmd)
	if lookup_db:errcode() > 0 then
		error("ERROR modifying:" .. lookup_db:errmsg())
	end
end

function insertPerson(person)
	local schema = _.reduce(exported_fields, function(acc, e) 
		if acc == "" then return e else return acc .. ", " .. e end
	end,"")
	local cmd = string.format([[
		INSERT INTO people (%s) 
		VALUES (%i,"%s","%s","%s",%i,%i,%i,%i,%i, %s,%s,%s,%s,%s, "%s","%s","%s",%i,%f,"%s","%s","%s","%s",%i)
	]],
		schema,
			person.id,
			person.givennym,
			person.patronym,
			person.gender,
			(person.alive and 1 or 0),
			(person.married and 1 or 0),
			(person.pregnant and 1 or 0),
			(person.fertile and 1 or 0),
			(person.orphaned and 1 or 0),
			person.father or "NULL",
			person.mother or "NULL",
			person.foster or "NULL",
			person.spouse or "NULL",
			person.fetus_is_bastard_of or "NULL",
			ngr(person.divorces),
			ngr(person.children),
			ngr(person.widowedBy),
			person.age,
			person.genetic,
			ngr(person.genome),
			person.birthyear,
			person.deathyear,
			person.household,
			person.location
	)
	lookup_db:exec(cmd)

	if lookup_db:errcode() > 0 then
		error("ERROR " .. lookup_db:errcode() .. ": " .. lookup_db:errmsg())
	end
end

function logEvent(logfile, year, type, ...)
	local data = {...}
	logfile:write(ngr(year)..","..ngr(type)..","..ngr(data).."\n")
end

function export_people_csv(path, people)
	--Perform data dump

	local f = assert(io.open(path, "w"))
	f:write(_.reduce(exported_fields, function(str, field, i, arr) 
		if i == #arr then return str .. "\""..field.."\"" end
		return str .. "\"" .. field .. "\", " 
	end, ""))
	_.each(people, function(x) 
		f:write(_.reduce(exported_fields, function(str, field, i, arr) 
			if i == #arr then return str .. ngr(x[field]) end
			return str .. ngr(x[field]) .. ", " 
		end,"\n")) end)
	f.close()
end
