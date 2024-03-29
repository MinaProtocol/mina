deps_expr='\(\s*libraries\s\s*([^\)]*)\)'
name_expr='\(\s*public_name\s\s*([^\)]*)\)'
{ find src/{app,lib,test} -mindepth 2 -name dune; echo src/config/dune; echo src/libp2p_ipc/dune; } | while read dune; do
  sed 's/;.*$//g' "$dune" | tr "\n" " " | sed -r 's%\(\s*re_export\s\s*([^\)]*)\s*\)%\1%g' > tmp_file

  IFS=';' read -ra names < <( grep -oE "$name_expr" tmp_file | sed -r "s/$name_expr/\1/g" | tr "\n" ';')
  IFS=';' read -ra depss < <( grep -oE "$deps_expr" tmp_file | sed -r "s/$deps_expr/\1/g" | sed 's/\s*$//g' | sed 's/\s\s*/\",\"/g' | tr "\n" ';')

  ix=0
  for name in "${names[@]}"; do
    deps="${depss[$ix]}"
    ix=$((ix+1))
    echo "\"$name\":{\"deps\":[\"$deps\"],\"path\":\"$(dirname "$dune")\"}"
  done
  # TODO extract it automatically
  echo '"cli":{"deps":["mina_signature_kind","mina_cli_entrypoint"],"path":"src/app/cli"}'
done | tr "\n" "," | sed 's/^/{/g' | sed 's/,$/}/g'
rm tmp_file
