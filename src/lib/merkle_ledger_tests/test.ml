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
    module DB =
      Database.Make (Key) (Account) (Hash) (Depth) (Location) (In_memory_kvdb)
        (In_memory_sdb)
        (Storage_locations)
    module Ledger = Ledger.Make (Key) (Account) (Hash) (Depth)
    module Binary_tree = Binary_tree.Make (Account) (Hash) (Depth)

    module DB_visualizor = Visualizable_ledger.Make (struct
      include DB

      type hash = Hash.t [@@deriving sexp, eq]

      let max_depth = Depth.depth

      let get_inner_hash_at_addr_exn db dirs =
        get_inner_hash_at_addr_exn db (Addr.of_directions dirs)
    end)

    module Ledger_visualizor = Visualizable_ledger.Make (struct
      include Ledger

      type hash = Hash.t [@@deriving sexp, eq]

      let max_depth = Depth.depth

      let get_inner_hash_at_addr_exn db dirs =
        let addr = Addr.of_directions dirs in
        if List.length dirs = Depth.depth then
          For_tests.get_leaf_hash_at_addr db addr
        else get_inner_hash_at_addr_exn db addr
    end)

    module Binary_tree_visualizor = Visualizable_ledger.Make (struct
      include Binary_tree

      type hash = Hash.t [@@deriving sexp, eq]
    end)

    let check_hash (type t1 t2)
        (module L1 : Visualizable_ledger.S
          with type t = t1 and type hash = Hash.t)
        (module L2 : Visualizable_ledger.S
          with type t = t2 and type hash = Hash.t) (l1, h1) (l2, h2) =
      if not (Hash.equal h1 h2) then
        failwithf
          !"\n Expected:\n%{sexp:L1.tree}\n\n\n Actual:\n%{sexp:L2.tree}"
          (L1.to_tree l1) (L2.to_tree l2) ()

    let%test_unit "databases have equivalent hash values" =
      let num_accounts = (1 lsl Depth.depth) - 1 in
      let gen_non_zero_balances =
        let open Quickcheck.Generator in
        list_with_length num_accounts (Int.gen_incl 1 Int.max_value)
      in
      Quickcheck.test ~sexp_of:[%sexp_of: int list] gen_non_zero_balances
        ~f:(fun balances ->
          let accounts =
            List.mapi balances ~f:(fun account_id balance ->
                Account.create (Int.to_string account_id) balance )
          in
          let db = DB.create () in
          let ledger = Ledger.create () in
          let enumerate_dir_combinations max_depth =
            Sequence.range 0 (max_depth - 1)
            |> Sequence.fold ~init:[[]] ~f:(fun acc _ ->
                   acc
                   @ List.map acc ~f:(List.cons Direction.Left)
                   @ List.map acc ~f:(List.cons Direction.Right) )
          in
          List.iter accounts ~f:(fun ({public_key; _} as account) ->
              ignore @@ DB.get_or_create_account_exn db public_key account ;
              ignore
              @@ Ledger.get_or_create_account_exn ledger public_key account ) ;
          let binary_tree = Binary_tree.set_accounts accounts in
          Sequence.iter
            (enumerate_dir_combinations Depth.depth |> Sequence.of_list)
            ~f:(fun dirs ->
              let db_hash =
                DB.get_inner_hash_at_addr_exn db (DB.Addr.of_directions dirs)
              in
              let ledger_hash =
                Ledger.get_inner_hash_at_addr_exn ledger
                  (Ledger.Addr.of_directions dirs)
              in
              let binary_hash =
                Binary_tree.get_inner_hash_at_addr_exn binary_tree dirs
              in
              check_hash
                (module Binary_tree_visualizor)
                (module Ledger_visualizor)
                (binary_tree, binary_hash) (ledger, ledger_hash) ;
              check_hash
                (module Binary_tree_visualizor)
                (module DB_visualizor)
                (binary_tree, binary_hash) (db, db_hash) ) )
  end )
