# Gazeteer Items

Each element in the gazeteer represents a geographical feature or (particularly) a settlement. The gazeteer provides a standardized enumeration of each place, in order to convey aspects (usually census-like in nature) about points of interest in the atlas.

## Kinds of Values

There are two kinds of Gazeteer items: those that I assign to a location before its coordinates have been assigned, and those done afterwards. These are, respectively, **preassignement* values and **postassignment** values.

## Preassignment Values

Preassignment values are able to be created without a precise knowledge of where the location is. The aim is to programmatically generate these values at random, to simulate a high degree of fidelity in my eventual gazeteer. In using random generation in this way, I can shift a lot of the 'design' work off myself (in terms of manual list-making) and instead riff off of an arbitrary set of locations, making changes as I desire. In particular, this enables me to make broad & sweeping distributional changes and subsequently tune those distributions until I like the 'shape' of the location set. At that point, I can choose a favorite random seed, then hand-tune the rest.

- Population : Total average human population
- Population Rank : World population ranking
- Altitude : Height above sea level, on average, that the location has
- Climate Type : Koppen Classification
- Location Type : General topology of the land (coastal, valley, isthmus, mountain, etc)

## Postassignment Values

Postassignment values require the precise coordinates of the location to be known, and thus tend to be a bit more 'derivative'. For the most part, these are values generated as a byproduct of Atlas work, such as very specific differences in climatological parameters

- Longitude & Latitude
- Monthly temperatures (high/low)
- Monthly precipitation (snow/rain)
- Nearby Cities
- Nearby Points of Interest
- Primary Thoroughfares
- Province

### Cumulative Values

Depending on the placement of each location, meta-locations (such as provinces and urban locations) can be assigned. These values in the gazeteer have to wait until even the postassignment has been done.

- Province
- City
- Top 10 Peaks
- Top 10 Cities`
