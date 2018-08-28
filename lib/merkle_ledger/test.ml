open Core
open Test_stubs

let%test_module "Database integration test" =
  ( module struct
    module Depth = struct
      let depth = 4
    end

    module DB =
      Database.Make (Balance) (Account) (Hash) (Depth) (In_memory_kvdb)
        (In_memory_sdb)
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
        if List.length dirs = Depth.depth then get_leaf_hash_at_addr db addr
        else get_inner_hash_at_addr_exn db addr
    end)

    module Binary_tree_visualizor = Visualizable_ledger.Make (struct
      include Binary_tree

      type hash = Hash.t [@@deriving sexp, eq]
    end)

    let%test_unit "databases have equivalent hash values" =
      let num_accounts = (1 lsl Depth.depth) - 1 in
      let gen_non_zero_balances =
        let open Quickcheck.Generator in
        list_with_length num_accounts (Int.gen_incl 1 Int.max_value)
      in
      Quickcheck.test ~trials:100 ~sexp_of:[%sexp_of : int list]
        gen_non_zero_balances ~f:(fun balances ->
          let accounts =
            List.mapi balances ~f:(fun account_id balance ->
                Account.create (Int.to_string account_id) balance )
          in
          let db = DB.create ~key_value_db_dir:"" ~stack_db_file:"" in
          let ledger = Ledger.create () in
          let enumerate_dir_combinations max_depth =
            Sequence.range 0 (max_depth - 1)
            |> Sequence.fold ~init:[[]] ~f:(fun acc _ ->
                   acc
                   @ List.map acc ~f:(List.cons Direction.Left)
                   @ List.map acc ~f:(List.cons Direction.Right) )
          in
          List.iteri accounts ~f:(fun i account ->
              assert (DB.set_account db account = Ok ()) ;
              Ledger.set ledger (Int.to_string i) account ) ;
          Ledger.recompute_tree ledger ;
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
              [%test_result : Hash.t] ~expect:binary_hash ledger_hash
                ~message:
                  (sprintf
                     !"Ledger:\n\
                       Expected:\n\
                       %{sexp:Binary_tree_visualizor.tree}\n\n\n \
                       Actual:\n\
                       %{sexp:Ledger_visualizor.tree}"
                     (Binary_tree_visualizor.to_tree binary_tree)
                     (Ledger_visualizor.to_tree ledger)) ;
              [%test_result : Hash.t] ~expect:binary_hash db_hash
                ~message:
                  (sprintf
                     !"Database:\n\
                       Expected:\n\
                       %{sexp:Binary_tree_visualizor.tree}\n\n\n \
                       Actual:\n\
                       %{sexp:DB_visualizor.tree}"
                     (Binary_tree_visualizor.to_tree binary_tree)
                     (DB_visualizor.to_tree db)) ) )
  end )
