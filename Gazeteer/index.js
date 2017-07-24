//Requires
var seedrandom = require('seedrandom');
var _ = require('lodash');
var settings = require('./generate_settings.json');
var Canvas = require('canvas')
var fs = require('fs');
var SimplexNoise = require('simplex-noise');
var GIFEncoder = require('gifencoder');

//Parameters
var params = {
  "seed" : 0.7658792829606682,
  "num_locales" : 100,
  "largest_locale_population" : 100000,
  "zipf_population_variability" : 0.05,
  "everest_altitude" : 6000,
  "planetary_radius" : 125,//2000
  "latitudinal_fix" : -Math.PI/6
}

//Set Seed
var rng = seedrandom(params.seed)
var simplex = new SimplexNoise(rng)

//value2d = simplex.noise3D(x, y, z);

generate();
console.log("Seed was "+params.seed)


function generate()
{
  locales = [];

  //Generate Locales
  for(var i = 1; i <= params.num_locales; i++)
  {
    var locale = generate_locale(i);
    locale.climate_description = word_from_pet(locale.pet);
    locales.push(locale);
  }

  arrange_randomly_over_sphere(locales,{});

  console.log(locales);
  var filename = "output.gif";
  var camera = {
    width : 250,
    height : 250,
    projection : 'orthographic',
    lat: Math.PI/2,
    lng: 0.0
  }
  output_gif(filename, camera);
  return locales;
}

function word_from_pet(pet)
{
  if(pet < 0.25) return "really rainy: rain tundra or rain forest"
  else if(pet < 0.5) return "rainy: wet tundra or wet forest"
  else if(pet < 1.0) return "moist: moist tundra or moist forest"
  else if(pet < 2.0) return "humid: dry tundra to dry scrub to dry forest"
  else if(pet < 4.0) return "semiarid: badlands to very dry forest"
  else if(pet < 8.0) return "arid: dry scrub, maybe thorny woodlands"
  else return "superarid: desert"
}

function generate_locale(population_ranking)
{
  var locale_population = Math.floor(params.largest_locale_population / Math.pow(population_ranking,1.07));
  var locale_population_ranking = population_ranking;
  var locale_seed = rng();
  var locale_altitude = Math.floor(rng() * params.everest_altitude);
  var locale_potential_evapotranspiration = Math.pow(2, (rng() * 7 - 3)); //powers of 2 from -3 to 3

  return {
    population : locale_population,
    population_ranking : locale_population_ranking,
    seed : locale_seed,
    altitude : locale_altitude,
    pet : locale_potential_evapotranspiration
  }
}

function arrange_randomly_over_sphere(locales, options)
{
  for(var i = 0; i < locales.length; i ++)
  {
    locales[i].lat = 2 * Math.PI * Math.random();
    locales[i].lng = Math.acos(Math.random());
  }

  return locales;
}

function great_circle_distance(localeA, localeB)
{
  //spherical cosine method
  var φ1 = localeA.lat;
  var φ2 = localeB.lat;
  var Δλ = (localeB.lng-localeA.lng);
  return Math.acos( Math.sin(φ1)*Math.sin(φ2) + Math.cos(φ1)*Math.cos(φ2) * Math.cos(Δλ) ) * params.planetary_radius;
}

function drawPixel(ctx, x, y, r, g, b)
{
  var nr = Math.floor(r * 255)
  var ng = Math.floor(g * 255)
  var nb = Math.floor(b * 255)
  ctx.fillStyle = "rgb("+nr+","+ng+","+nb+")";
  ctx.fillRect(x,y,1,1);
}

function latLngToPx_Orthographic(lat, lng, radius, center)
{
  var p_x = (radius * Math.cos(lat) * Math.sin(lng - center.lng)) + orth_cam.width/2 + orth_cam.offsetX;
  var p_y = (radius * (Math.cos(center.lat) * Math.sin(lat) - Math.sin(center.lat) * Math.cos(lat) * Math.cos(lng - center.lng))) + orth_cam.height/2 + orth_cam.offsetY;
  return {
    x : p_x,
    y : p_y
  }
}
function pxToLatLng_Orthographic(x,y, radius, center)
{
  var p = Math.sqrt(Math.pow(x,2) + Math.pow(y,2));
  var c = Math.asin(p/radius)
  var lng = center.lng + Math.atan2(x * Math.sin(c),(p*Math.cos(c)*Math.cos(center.lat)) - (y * Math.sin(c) * Math.sin(center.lat)))
  var lat = Math.asin(Math.cos(c) * Math.sin(center.lat) + ((y * Math.sin(c) * Math.cos(center.lat)) / p))
  if(lng > Math.PI) lng -= Math.PI * 2
  if(lng < -Math.PI) lng += Math.PI * 2
  return {
    lat: lat,
    lng: lng //conversion from -PI<->PI to 0<->2PI coordinate system
  }
}
function getCoordinateInfo(coord)
{
  var x, y, z;
  x = params.planetary_radius * Math.cos(coord.lat + params.latitudinal_fix) * Math.cos(coord.lng)
  y = params.planetary_radius * Math.cos(coord.lat + params.latitudinal_fix) * Math.sin(coord.lng)
  z = params.planetary_radius * Math.sin(coord.lat + params.latitudinal_fix)

  var harmonics = 10;
  var sum = 0;
  for(var i = 0; i < harmonics; i++){
      var rat = Math.pow(2,i)
      var freq = 500/(Math.pow(2,i))
      var h_off = params.planetary_radius * i
      sum += simplex.noise3D(x/freq + h_off, y/freq, z/freq) / (2 * rat)
  }
  var val = sum * (coord.lat>0?coord.lat/(Math.PI/4):0.0);

  return {
    altitude : val * params.everest_altitude
  }
}

function output_gif(filename, camera)
{
  var encoder = new GIFEncoder(camera.width, camera.height);
  // stream the results as they are available into myanimated.gif
  encoder.createReadStream().pipe(fs.createWriteStream(filename));

  encoder.start();
  encoder.setRepeat(0);   // 0 for repeat, -1 for no-repeat
  encoder.setDelay(100);  // frame delay in ms
  encoder.setQuality(10); // image quality. 10 is default.


  var Image = Canvas.Image
  var canvas = new Canvas(camera.width, camera.height)
  var ctx = canvas.getContext('2d');

  for(var i = 0; i < 16; i ++)
  {
    rng = seedrandom(params.seed)
    simplex = new SimplexNoise(rng)
    draw_ortho(ctx, camera);
    encoder.addFrame(ctx);
    camera.lng += (2 * Math.PI / 16)
    ctx.clearRect(0, 0, canvas.width, canvas.height);
  }

  encoder.finish();

}

function output_map(filename, camera)
{
  var Image = Canvas.Image
  var canvas = new Canvas(camera.width, camera.height)
  var ctx = canvas.getContext('2d');

  draw_ortho(ctx, camera);

  fs.writeFile(filename, canvas.toBuffer());
}

function draw_ortho(ctx, camera)
{
  for(var x = 0; x < camera.width; x++)
  {
    for(var y = 0; y < camera.height; y++)
    {
      var coord = pxToLatLng_Orthographic(x-camera.width/2,y-camera.height/2,params.planetary_radius,camera);
      altitude = getCoordinateInfo(coord).altitude
      var val = altitude / params.everest_altitude
      if(val < 0.3 )//30% land coverage
      {
				//Sea ice
        if(coord.lat > Math.PI/2 - Math.PI/8)
          drawPixel(ctx,x,y,1.0,1.0,1.0)
				//Open water
        else
          drawPixel(ctx,x,y,0.1,0.1,0.8);
      }
      else if(!val)
				//Space
        drawPixel(ctx,x,y,0.3,0.3,0.3);
      else
				//Land
        drawPixel(ctx,x,y,val,0.5,val);
    }
  }
}
