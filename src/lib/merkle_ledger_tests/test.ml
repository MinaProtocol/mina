open Core
open Test_stubs
module Database = Merkle_ledger.Database
module Ledger = Merkle_ledger.Ledger

let%test_module "Database integration test" =
  ( module struct
    module Depth = struct
      let depth = 4
    end

    module Location = Merkle_ledger.Location.Make (Depth)

    module Inputs = struct
      include Test_stubs.Base_inputs
      module Location = Location
      module Kvdb = In_memory_kvdb
      module Storage_locations = Storage_locations
      module Depth = Depth
    end

    module DB = Database.Make (Inputs)
    module Ledger = Ledger.Make (Inputs)
    module Binary_tree = Binary_tree.Make (Account) (Hash) (Depth)

    let%test_unit "databases have equivalent hash values" =
      let num_accounts = (1 lsl Depth.depth) - 1 in
      let gen_non_zero_balances =
        let open Quickcheck.Generator in
        list_with_length num_accounts Balance.gen
      in
      Quickcheck.test ~trials:5 ~sexp_of:[%sexp_of: Balance.t list]
        gen_non_zero_balances ~f:(fun balances ->
          let public_keys = Key.gen_keys num_accounts in
          let accounts =
            List.map2_exn public_keys balances ~f:Account.create
          in
          DB.with_ledger ~f:(fun db ->
              Ledger.with_ledger ~f:(fun ledger ->
                  let enumerate_dir_combinations max_depth =
                    Sequence.range 0 (max_depth - 1)
                    |> Sequence.fold ~init:[[]] ~f:(fun acc _ ->
                           acc
                           @ List.map acc ~f:(List.cons Direction.Left)
                           @ List.map acc ~f:(List.cons Direction.Right) )
                  in
                  List.iter accounts ~f:(fun account ->
                      let public_key = Account.public_key account in
                      ignore
                      @@ DB.get_or_create_account_exn db public_key account ;
                      ignore
                      @@ Ledger.get_or_create_account_exn ledger public_key
                           account ) ;
                  let binary_tree = Binary_tree.set_accounts accounts in
                  Sequence.iter
                    (enumerate_dir_combinations Depth.depth |> Sequence.of_list)
                    ~f:(fun dirs ->
                      let db_hash =
                        DB.get_inner_hash_at_addr_exn db
                          (DB.Addr.of_directions dirs)
                      in
                      let ledger_hash =
                        Ledger.get_inner_hash_at_addr_exn ledger
                          (Ledger.Addr.of_directions dirs)
                      in
                      let binary_hash =
                        Binary_tree.get_inner_hash_at_addr_exn binary_tree dirs
                      in
                      assert (Hash.equal binary_hash ledger_hash) ;
                      assert (Hash.equal binary_hash db_hash) ) ) ) )
  end )
