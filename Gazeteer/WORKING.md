# Gazeteer Working Document

Here I store preparatory thoughts about the Gazeteer, specifically recording my processes.

## What does a Gazeteer Contain?

~~February 4 2016

Well, based on wikipedia, at the very least a publication called the 'World Gazeteer' has the following:

> **The World Gazetteer**
> - for a given city it gives the country, province, population (incorrect for some countries), coordinates, population rank among all towns within the country (incorrect for some countries)
> - for each country it gives a map and table of provinces with area and population, a map of cities, an alphabetical table of cities, and a table of top cities – tables can be sorted by a column of choice
> - for each province it gives an alphabetical table of cities.
> - Contains 2,900,000 towns outside the US. For a given country and town it gives coordinates, altitude, weather forecast, and a map showing the position of the town with respect to topography and borders and bodies of water (not with respect to other towns); it also lists towns which are very nearby, within 3 km, with direction.

I really like the last point there: not only does it give 'by the numbers' bits like the altitude and location, it gives a climatological forecast and a **topological** arrangement. This is particularly of note because I plan to generate the gazeteer before my atlas: so at that point where I'm laying the cities down on the map, I'll need very specific criterion for their placement. Although I anticipate a couple rounds of manual tweaking, it would be very cool if I had some supporting software which would highlight candidate locations in my world on a map, for ease of placement.

So, I definitely want to add those kind of topological constraints into my procedural generation of locations.
