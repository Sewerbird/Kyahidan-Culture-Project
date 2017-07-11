luajit make.lua 300 15000; 
find ./output -name "region_map*.viz" -exec cat {} | fdp -T svg -o {}.svg \; 
find ./output -name "town_map*.viz" -exec cat {} | fdp -T svg -o {}.svg \; 
find ./output -name "sample_person*.viz" -exec cat {} | fdp -T svg -o {}.svg \; 