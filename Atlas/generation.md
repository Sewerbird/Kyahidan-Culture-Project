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

