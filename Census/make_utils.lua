local _ = require 'lib/lodash'
local inspect = require 'lib/inspect'
local mendel = require 'lib/mendel'

local lastnames_path = "data/CSV_Database_of_Last_Names.csv"

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

function get_living_descendents(id, depth, acc)
	local me = lookupPerson(id)
	if acc[depth] == nil then acc[depth] = {} end
	if acc.count == nil then acc.count = 0 end

	if #me.children > 0 then
		_.each(me.children, function(child) 
			if lookupPerson(child).alive then 
				table.insert(acc[depth],child) 
				acc.count = acc.count + 1
			end
			acc = get_living_descendents(child, depth+1, acc) 
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
		genome = mendel.randomGenome(),
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
		genome = mendel.reproduce(mom.genome, dad.genome),
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

function uncgr(x) --turn custom-csv form into lua
	if x == "NULL" then
		return nil
	elseif x == "TRUE" then
		return true
	elseif x == "FALSE" then
		return false
	elseif x == "ETBL" then
		return {}
	elseif 'table' == type(x) then
		return _.map(x, function(e) return uncgr(e) end)
	elseif tonumber(x) ~= nil then
		return tonumber(x)
	else
		return x
	end
end

function cgr(x) --format lua value to custom-csv friendly form
	if x == nil then 
		return "NULL"
	elseif 'boolean' == type(x) then
		return x and "TRUE" or "FALSE"
	elseif 'table' == type(x) then
		local z = _.reduce(x, function(acc,k)
			return acc .. ":" .. k
		end,"")
		if z == "" then z = "ETBL" end
		return z
	elseif tonumber(x) ~= nil then
		return x
	else 
		return tostring(x)
	end
end

function ngr(x) --format lua value to sequel friendly form 
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

function ogr(x)
	local result = {}
	for i = 1, #exported_fields do
		local k = exported_fields[i]
		local v = x[i]
		if k == 'married' or k == 'pregnant' or k == 'fertile' or k == 'alive' or k == 'orphaned' then
			if(v == 0 or v == "" or v == nil or v == 'false' or v == "0") then
				v = false
			else
				v = true
			end
		elseif k == 'widowedBy' or k == 'children' or k == 'genome' or k == 'divorces' then
			local t={} ; i=1
	        for str in string.gmatch(v, "([^"..",".."]+)") do
	        	str = str:gsub('\\[','')
	        	str = str:gsub('\\]','')
	        	if str ~= "" and str ~= "[" and str ~= "]" and str ~= "[]" then
	        		if tonumber(str) ~= nil then
	                	t[i] = tonumber(str)
	                else
	                	t[i] = str
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

local lookup_db = nil
local lookup_cache = nil
local lookup_cache_size = 0
local lookup_cache_maximum_size = 20000

function setupLookup(filename)
	lookup_cache = {} 
	
	if filename then
		lookup_cache = import_people_csv(filename,nil)
	end
	--lookup_db = db 
	--local schema = _.reduce(exported_fields, function(acc, e) 
	--	if acc == "" then return "\""..e.."\"" else return acc .. ", " .. "\""..e.."\"" end
	--end,"")
	--lookup_db:exec(string.format("CREATE TABLE people ( %s )",schema))
	--lookup_db:exec(string.format("CREATE INDEX people_id_idx ON people(id)"))
end

function cacheSize()
	return lookup_cache_size
end

function getWorkingSet()
	return _.map(_.filter(lookup_cache, function(e)
		return e.alive == true
	end), function (e) return e.id end)
	--[[
	for a in db:rows("SELECT id FROM people WHERE alive = 1") do
		table.insert(working_set,a[1])
	end
	]]
end

function pruneCache()
	--print("PERFORMING CACHE PRUNE: " .. lookup_cache_size .. " > " .. lookup_cache_maximum_size)
	--lookup_cache = {}
	--lookup_cache_size = 0
end

function lookupPerson(id)
	if lookup_cache and lookup_cache[id] ~= nil then
		return lookup_cache[id]
	else
		return nil
	end
	--[[
	for a in lookup_db:rows(string.format("SELECT * FROM people WHERE id = %i LIMIT 1", id)) do
		local result = ogr(a)
		lookup_cache[id] = result
		lookup_cache_size = lookup_cache_size + 1
		if lookup_cache_size > lookup_cache_maximum_size then
			pruneCache()
		end
		return result
	end
	]]
end

function modifyPerson(id, key, value)
	if lookup_cache and lookup_cache[id] then
		lookup_cache[id][key] = value
	end
	--[[
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
	--]]
end

function insertPerson(person)
	if lookup_cache and not lookup_cache[person.id] then
		lookup_cache[person.id] = person
		lookup_cache_size = lookup_cache_size + 1
		if lookup_cache_size > lookup_cache_maximum_size then
			pruneCache()
		end
	end
	--[[
	local schema = _.reduce(exported_fields, function(acc, e) 
		if acc == "" then return e else return acc .. ", " .. e end
	end,"")
	local cmd = string.format([[
		INSERT INTO people (%s) 
		VALUES (%i,"%s","%s","%s",%i,%i,%i,%i,%i, %s,%s,%s,%s,%s, "%s","%s","%s",%i,%f,"%s","%s","%s","%s",%i)
	]xx],
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
	--]]
end

function logEvent(logfile, year, type, ...)
	local data = {...}
	logfile:write(ngr(year)..","..ngr(type)..","..ngr(data).."\n")
end

function export_people_csv(path)
	--Perform data dump
	print("Performing census dump to ".. path)
	local f = assert(io.open(path, "w"))
	f:write(_.reduce(exported_fields, function(str, field, i, arr) 
		return i==#arr and str .. field or str .. field .. ","
	end, ""))
	_.each(lookup_cache, function(x,i)
		if math.mod(i,10000) == 0 then print(i .. "/" .. #lookup_cache) end 
		f:write(_.reduce(exported_fields, function(str, field, i, arr) 
			if i == #arr then return str .. cgr(x[field]) end
			return str .. cgr(x[field]) .. "," 
		end,"\n")) end)
	f.close()
end

function import_people_csv(path, filter_fn)
	local csv = assert(io.open(path, "r"))
	local ppl = {}
	for line in csv:lines() do
		local t={}; i=1
		for str in string.gmatch(line, "([^,]+)") do
			local c = nil
			local j = 0
			for k in string.gmatch(str,":") do
				j = 1; break
			end
			if j > 0 then
				c={}
				--array
				for z in string.gmatch(str, "([^:]+)") do
					table.insert(c,uncgr(z))
				end
			else
				--value
				c=uncgr(str)
			end
			t[exported_fields[i]] = c
			i = i + 1
		end
		if filter_fn == nil or (filter_fn ~= nil and filter_fn(t)) then
			table.insert(ppl,t)
		end
	end
	return ppl
end
