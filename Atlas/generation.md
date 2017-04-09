# Generation

At first we'll start with a geometrically simple landmass to base off of. This is a polar landmass made of two 'pie segments' radiating from the pole.

The first pie segment is 5π/3 radians and fills land above the 60th latitude paralell The second pie segment fills up the remaining π/3, but extends down to the 30th latitude parallel.

This simple landmass has been chosen because it covers about 11% of the planet (whose radius is 5067 kilometers), interrupts ocean currents enough to direct warm water northward, and a desire to have a single continent.

Assuming we desire roughly 1000 samples of the northern hemisphere to lie within this landmass (thus defining 1000 locations on the continent), each sample should (on average) be about 69 kilometers from the next point, yielding (roughly) 70 square kilometers per point, which seems a suitable scale for a gazeteer. Random sampling of the hemisphere's surface implies that roughly 6000 samples are needed.

The algorithm for determining the point-cloud associated with Kyahida follows thus:

```javascript
  var coords = [];
  var kyahida_lat_1 = Math.PI / 3;
  var kyahida_lat_2 = Math.PI / 6;
  var kyahida_lng_2 = Math.PI / 3;

  for(var i = 0; i < 6000; i ++)
  {
    var lat = 2 * Math.PI * Math.random();
    var lng = Math.acos(Math.random());

    if(lat < kyahida_lat_1 || (lat < kyahida_lat_2 && lng < kyahida_lng_2))
    {
      coords.push({lat: lat, lng: lng})
    }
  }

  console.log("Kyahidan regions (", coords.length,"):",coords);
```

Kyahida covers six percent of the planet. (Like Africa does Earth)

Planet has radius of 5000 km

This means Kyahida is roughly 20 million square kilometers

This puts it about the 2/3rds of Africa's size; Australia + Europe; or a smushed Antarctica + Australia

Kyahida can be thought of as a polar 'disk' section with an equator-reaching extension. The disk is about the size of Australia, the rest being in the extension.

Africa, and by analogy Kyahida, reaches over 70 degrees latitude. Kyahida is conceptually a squished/morphed Africa: assuming Kyahida's "pole" is roughly low-mid-saharan, that means Kyahida's land-bound polar disk reaches down 20 degrees from the pole (70 degrees North).

The rest of Kyahida extends down 30 degrees from this lower extent, meaning the southernmost extent of kyahida is about 40 degrees North. This stretches down to about 30 degrees North since Kyahida is a bit skinnier than Africa (more of the mass is in the 'extension' than Africa's southern half).

Initial landmass shape is determined by the following algorithm:

  - There are 20x one-million quare kilometer discs, centered on points on the globe.
  - Disks are placed so that their spherical projections do not overlap (projected towards the center of the planet)
  - The first disk is placed on the North Pole
  - Six disks are placed adjacent such that they 'pack' the first disk on all sides
  - A second ring is formed around these, but only touching half of them
  - This results in 13 disks being placed: this is the polar disk of Kyahida
  - 7 more disks are placed adjectent to this second ring at lower latitudes to reach 30*N.
  - Remaining disks are placed sideways to 'fatten' this extension.
  - This is the general shape of Kyahida

One degree of latitude's distance is 1/360 * 2 * pi * planet radius = 88km

Roughly, that means one disk of 1 million square kilometers means

  1,000,000 = pi * x^2    ==>   x = sqrt (1,000,000/pi)   ==>  x = 564

Meaning a disk has a radius of 564, thus a diameter of 1250, and thus 15 degrees of latitudinal extent

So,

  disk 1 (polar seed) = -82.5N to 82.5N
  disk 2 (pole ring) = -67.5N to 67.5N
  disk 3 (half-cap) = 52.5N from 40W to 40E
  disk 4 (extension) = 30.5N from 20W to 20E


