cd ./react_ppx_3/
opam switch create 4.02.3+buckle-master
eval $(opam env)
make
cd ..

rm -rf ./node_modules/react_ppx_3
mkdir -p ./node_modules/react_ppx_3
cp -r ./react_ppx_3/ppx.exe ./node_modules/react_ppx_3/reactjs_jsx_ppx_3
chmod +x ./node_modules/react_ppx_3/reactjs_jsx_ppx_3
