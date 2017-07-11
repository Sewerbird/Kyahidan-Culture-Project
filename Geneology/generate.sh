rm -r output
mkdir output
luajit make.lua 100 1500; 
find ./output -name "*.viz" -exec sh -c "cat {} | fdp -T svg -o {}.svg" \;    