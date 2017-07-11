# Family generation

For family trees I'll decide if I'm going to create them from ancestors or from descendents. I intend to use population pyramids to randomly generated at least one cohort. If I start from the eldest I'll trace their family tree downwards; if I start from the children of the population of trays up to their parents. The principal difficulty in creating a useful set of such people and the relationships is modeling statistically their marriages, their deaths, their childlessness, homosexuality, raiding/raping, polygamy, adoptions, infidelities and so on: capturing the messy family structures caused by the work of life.

My initial approach will be to generate a large number of intact extended nuclear families. Then I will apply some merging operations across these family trees stochastically according to the probability functions I decide for each phenomenon. For example I think it would work to model a man who has fathered many families perhaps via raiding by defining a Peretto distribution of number of families men have across the population: if I figured that the most ignominious bastard had 50 women bear children to him over his career then I can define a power law that has most men have only one family but then a large spike of men on one end of the distribution with a few more. Once I have the number of such men defined, I can perform a concomitant number of merge operations on the intact family trees, Setting the father to the guy who gets around.

I would also like to model adoptions. I think unnatural way to do this would be to run this step of generation after I had run untimely deaths that results in children without parents. For a certain adoption rate, I can move the children on to another intact family.

Because I am only modeling a slice of current living people I do not intend to significantly model new marriages nor great ancestor commonality. These more extended ties, such as cousin and grand cousin, I will leave for later. This is because, at this point in time, these families do not have geographical context: in principle I could kind of put them wherever I want. In fact, this is part of the point: I want a population that I can tweak and change the shape of and only later be obligated to put them in an ecological scenario. I am proceeding from a perspective that, when I randomly generated towns in a location, at that time we'll have certain needs of certain professions Anthony graphics. These families that I'm generating Will be a bunch of custom Lego bricks used to assemble approximately the town desired.

To proceed properly I need at least a few things:
	I needed a basic person generator
	I need a new representation of family trees
	I need to define operations over one or more family trees
	I need to be able to query my population and see their relations in a convenient manner
	I need to be able to create my populations Family trees for certain topological features

Here I define "household".
	Coordinates a family unit into relationships
	Requires at least one individual
	Household can be the result of the marriage
	Depending on the age, fertility and livelihood of the marriage partners, a number of children are associated with the household.
	The age of each individual in a household is tracked: these ages impose a restriction on what positions in the household the individual is valid for. These restrictions aren't many however: they primarily enforce logical constraints like being younger than your parents or being young/old enough to give birth

## frisco undo

## first go

––step one: define initial full size