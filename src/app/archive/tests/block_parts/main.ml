open Core_kernel

(* A mainnet block of version 3, and the hashes of its transactions in the
   mainnet archive dump `mainnet-archive-dump-2026-10-01_0000`, in sequence
   order: a zkApp command, four signed commands, a coinbase of 720 MINA and a
   fee transfer. *)
let v3_block_file =
  "../../../../lib/mina_block/tests/mainnet-545000-3NKc1wHM45SweeqiCZyNwmNJQnT4vjzJmeCYkG83YqXNgDPY57ZD.json"

let archived_hashes =
  [ "5Jv6nCoABLcAsszC4kyFvEy3g6PXS5htvfM9JrGv2vPGERE11N8H"
  ; "5JvGVjyaCDWmyrgw6G9GWYhNaHftMAqUNe6PX2k8wfYYVpGDydDC"
  ; "5JusDQDoH4GfZpD19eRNJmW4vbFwToR7ja12FEMtAbL9Q9dpDk6D"
  ; "5JuNyBCfHpx8XkCMA7ox4i5mVdRudPGHSy7CmYW9SFqp5QJz9rUb"
  ; "5JuEnYjGNm9f4w2MQ3rjhGc7QubsonB7taTUxCsPzv5QVTiCGRCM"
  ; "5JuAhCCNJGjzLY1XXLKU128eLmg2JPYXeaVGiEi7hNqwJmdHnW3N"
  ; "5JtWGo6cd9DcVZ418YfW99eFTzHisZV7wUNCxcrXj31ciKQuqViy"
  ]

let v3_transactions_match_archive () =
  let (module G) = Genesis_constants.profiled () in
  let block =
    Mina_block.Precomputed.Versioned.of_yojson
      (Yojson.Safe.from_file v3_block_file)
    |> Result.ok_or_failwith
  in
  let parts =
    Archive_lib.Block_parts.of_precomputed
      ~constraint_constants:G.constraint_constants
      ~proof_cache_db:(Proof_cache_tag.create_identity_db ())
      block
  in
  let transactions = Lazy.force parts.transactions in
  let hashes =
    List.concat_map transactions ~f:(fun { data; _ } ->
        match data with
        | Command { hash; _ } | Coinbase { hash; _ } ->
            [ hash ]
        | Fee_transfer { hashes; _ } ->
            hashes )
  in
  [%test_eq: string list] archived_hashes
    (List.map hashes ~f:Mina_transaction.Transaction_hash.to_base58_check) ;
  List.iter transactions ~f:(fun { data; _ } ->
      match data with
      | Coinbase { coinbase; _ } ->
          [%test_eq: Currency.Amount.t]
            (Currency.Amount.of_mina_int_exn 720)
            (Mina_base.Coinbase.amount coinbase)
      | Command _ | Fee_transfer _ ->
          () )

let () =
  Alcotest.run "Block parts"
    [ ( "version 3"
      , [ Alcotest.test_case "transactions match the archive's" `Quick
            v3_transactions_match_archive
        ] )
    ]
