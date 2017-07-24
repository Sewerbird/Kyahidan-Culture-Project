luajit graph.lua "output/census.csv" 10

cat output/town_map_Aville.viz | dot -T svg -o town_map_Aville.svg
cat output/town_map_Burb.viz | dot -T svg -o town_map_Burb.svg
cat output/town_map_Chamlet.viz | dot -T svg -o town_map_Chamlet.svg

find ./output -name "town_map_*.viz" -exec sh -c "cat {} | fdp -T svg -o {}.svg" \;
find ./output -name "sample_person_*.viz" -exec sh -c "cat {} | dot -T svg -o {}.svg" \;
