local _ = require "lib/shimmed"

local mendel = {}

local genome = {
	{
		chromosome = 1,
		label = "eye_color",
		alleles = {"B","b","c"},
		BB = "black", Bb = "brown", Bc = "brown",
		bB = "brown", bb = "blue",  bc = "hazel",
		cB = "brown", cb = "hazel", cc = "green"
	},
	{
		chromosome = 1,
		label = "hair_color",
		alleles = {"B","b","c"},
		BB = "black", Bb = "dark brown", Bc = "brown",
		bB = "dark brown", bb = "blonde",  bc = "auburn",
		cB = "brown", cb = "auburn", cc = "red"
	},
	{
		chromosome = 1,
		label = "hair_texture",
		alleles = {"B","b","c"},
		BB = "straight", Bb = "straight", Bc = "straight",
		bB = "straight", bb = "curly",  bc = "wavy",
		cB = "straight", cb = "wavy", cc = "afro"
	},
	{
		chromosome = 1,
		label = "eye_shape",
		alleles = {"B","b","c"},
		BB = "monolid", Bb = "downturned", Bc = "upturned",
		bB = "downturned", bb = "almond",  bc = "hooded",
		cB = "upturned", cb = "hooded", cc = "round"
	},
	{
		chromosome = 1,
		label = "nose_bridge",
		alleles = {"B","b","c"},
		BB = "straight", Bb = "straight", Bc = "straight",
		bB = "straight", bb = "convex",  bc = "concave",
		cB = "straight", cb = "concave", cc = "convex"
	},
	{
		chromosome = 1,
		label = "nose_tip",
		alleles = {"A","B","C","D"},
		AA = "flared", AB = "flared", AC = "flared", AD = "flared",
		BA = "flared", BB = "bulbous", BC = "bulbous", BD = "bulbous",
		CA = "flared", CB = "bulbous", CC = "upturned", CD = "upturned",
		DA = "flared", DB = "bulbous", DC = "upturned", DD = "thin"
	},
	{
		chromosome = 1,
		label = "lip_shape",
		alleles = {"B","b","c"},
		BB = "thin", Bb = "thin", Bc = "thin",
		bB = "thin", bb = "wide",  bc = "full",
		cB = "thin", cb = "full", cc = "round"
	},
	{
		chromosome = 1,
		label = "jawline_shape",
		alleles = {"B","b","c"},
		BB = "pointed", Bb = "pointed", Bc = "pointed",
		bB = "pointed", bb = "round",  bc = "round",
		cB = "pointed", cb = "round", cc = "square"
	},
	{
		chromosome = 1,
		label = "hairline_shape",
		alleles = {"B","b"},
		BB = "wide", Bb = "wide",
		bB = "wide", bb = "narrow"
	},
	{
		chromosome = 1,
		label = "facial_aspect",
		alleles = {"B","b"},
		BB = "long", Bb = "oval",
		bB = "oval", bb = "round"
	}
}

function mendel.randomGenome()
	return _.map(genome, function(gene)
		return _.sample(gene.alleles) .. _.sample(gene.alleles)
	end)
end

function mendel.getExpressionOf(trait, person)
	local idx = _.findIndex(genome, function(gene) return gene.label == trait end)
	return genome[idx][person[idx]]
end

function mendel.reproduce(personA, personB)
	--meiosis
	local gameteA = _.map(personA, function(gene)
		local r = math.random(2)
		return string.sub(gene,r,r)
	end)
	local gameteB = _.map(personB, function(gene)
		local r = math.random(2)
		return string.sub(gene,r,r)
	end)
	--fertilization
	return _.map(gameteA, function(alleleA, gene)
		local alleleB = gameteB[gene]
		return alleleA .. alleleB
	end)

end

function mendel.describeFace(name, person)
	local eye_color = mendel.getExpressionOf("eye_color", person)
	local eye_shape = mendel.getExpressionOf("eye_shape", person)
	local hair_color = mendel.getExpressionOf("hair_color", person)
	local hair_texture = mendel.getExpressionOf("hair_texture", person)
	local facial_aspect = mendel.getExpressionOf("facial_aspect", person)
	local jawline_shape = mendel.getExpressionOf("jawline_shape", person)
	local hairline_shape = mendel.getExpressionOf("hairline_shape", person)
	local nose_bridge = mendel.getExpressionOf("nose_bridge", person)
	local nose_tip = mendel.getExpressionOf("nose_tip", person)
	local lip_shape = mendel.getExpressionOf("lip_shape", person)
	return string.format("%s has %s %s eyes and %s %s hair framing a %s face with a %s jawline and %s hairline. Their %s nose has a %s tip over %s lips.",
		name, eye_color, eye_shape, hair_color, hair_texture, facial_aspect, jawline_shape, hairline_shape, nose_bridge, nose_tip, lip_shape)
end

return mendel