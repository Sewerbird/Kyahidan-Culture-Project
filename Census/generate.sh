rm -r output
mkdir output
luajit make.lua 10 100; 
find ./output -name "*.viz" -exec sh -c "cat {} | fdp -T svg -o {}.svg" \;    
