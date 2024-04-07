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
    path=$(dirname "$dune")

    dune_files=$(find "$path" -name dune -type f)
    dependsOnConfig=$(( grep -oE config.mlh $dune_files >/dev/null && echo true ) || echo false)
    echo "\"$name\":{\"deps\":[\"$deps\"],\"path\":\"$path\",\"dependsOnConfig\":$dependsOnConfig}"
  done
  # TODO extract it automatically
  echo '"archive":{"deps":["mina_signature_kind","archive_cli","mina_version","bounded_types"],"path":"src/app/archive","dependsOnConfig":false}'
  echo '"cli":{"deps":["mina_signature_kind","mina_cli_entrypoint"],"path":"src/app/cli","dependsOnConfig":false}'
  echo '"test_type_equalities":{"deps":["mina_wire_types","currency","snark_params","signature_lib","mina_base","mina_base.import","mina_numbers","block_time","one_or_two","mina_transaction","mina_state","mina_transaction_logic","transaction_snark","transaction_snark_work","ledger_proof","network_pool","consensus","consensus.vrf","protocol_version","genesis_constants","mina_block","sgn","sgn_type","data_hash_lib","kimchi_backend.pasta","kimchi_backend.pasta.basic","kimchi_backend","pickles","pickles.backend","pickles_base","pasta_bindings","blake2","staged_ledger_diff","bounded_types"],"path":"src/lib/mina_wire_types_test","dependsOnConfig":false}'
done | tr "\n" "," | sed 's/^/{/g' | sed 's/,$/}/g'
rm tmp_file
