rm -r output
mkdir output
lua make.lua 30 100; 
find ./output -name "*.viz" -exec sh -c "cat {} | fdp -T svg -o {}.svg" \;    