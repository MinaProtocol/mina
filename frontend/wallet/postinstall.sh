# Note this is hacked to work on Mac using a prebuild binary
# If you want it to work on a different platform, run `make` in react_ppx_3 dir
# and copy the executable to ./node_modules/react_ppx_3/reactjs_jsx_ppx_3

rm -rf ./node_modules/react_ppx_3
mkdir -p ./node_modules/react_ppx_3
cp -r ./react_ppx_3/ppx.darwin ./node_modules/react_ppx_3/reactjs_jsx_ppx_3
chmod +x ./node_modules/react_ppx_3/reactjs_jsx_ppx_3
