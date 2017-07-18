rm -r output
mkdir output
lua make.lua 100 10000; 
find ./output -name "*.viz" -exec sh -c "cat {} | fdp -T svg -o {}.svg" \;    