open Core
open Unsigned

module Mdb_d (Depth : Intf.Depth) = struct
  module Balance = struct
    include UInt64
    include Binable.Of_stringable (UInt64)

    let equal x y = UInt64.compare x y = 0
  end

  module Account : sig
    include Intf.Account with type balance := Balance.t

    val gen : t Quickcheck.Generator.t
  end = struct
    type t = {public_key: string; balance: Balance.t} [@@deriving bin_io, eq]

    let empty = {public_key= ""; balance= Balance.zero}

    let balance {balance; _} = balance

    let set_balance {public_key; _} balance = {public_key; balance}

    let public_key {public_key; _} = public_key

    let gen =
      let open Quickcheck.Let_syntax in
      let%bind public_key = String.gen in
      let%map int_balance = Int.gen in
      let nat_balance = abs int_balance in
      let balance = Balance.of_int nat_balance in
      {public_key; balance}
  end

  module Hash = struct
    type t = int [@@deriving bin_io, eq, sexp]

    let empty = 0

    let merge ~height left right = Hashtbl.hash (height, left, right)

    let hash_account : Account.t -> t = Hashtbl.hash
  end

  module In_memory_kvdb : Intf.Key_value_database = struct
    type t = (string, Bigstring.t) Hashtbl.t

    let create ~directory:_ = Hashtbl.create (module String)

    let destroy _ = ()

    let get tbl ~key = Hashtbl.find tbl (Bigstring.to_string key)

    let set tbl ~key ~data =
      Hashtbl.set tbl ~key:(Bigstring.to_string key) ~data

    let delete tbl ~key = Hashtbl.remove tbl (Bigstring.to_string key)
  end

  module In_memory_sdb : Intf.Stack_database = struct
    type t = Bigstring.t list ref

    let create ~filename:_ = ref []

    let destroy _ = ()

    let push ls v = ls := v :: !ls

    let pop ls =
      match !ls with
      | [] -> None
      | h :: t ->
          ls := t ;
          Some h

    let length ls = List.length !ls
  end

  module MT =
    Database.Make (Balance) (Account) (Hash) (Depth) (In_memory_kvdb)
      (In_memory_sdb)

  let with_test_instance f =
    let uuid = Uuid.create () in
    let tmp_dir = "/tmp/merkle_database_test-" ^ Uuid.to_string uuid in
    let key_value_db_dir = Filename.concat tmp_dir "kvdb" in
    let stack_db_file = Filename.concat tmp_dir "sdb" in
    assert (Unix.system ("rm -rf " ^ tmp_dir) = Result.Ok ()) ;
    Unix.mkdir tmp_dir ;
    let mdb = MT.create ~key_value_db_dir ~stack_db_file in
    let cleanup () =
      MT.destroy mdb ;
      assert (Unix.system ("rm -rf " ^ tmp_dir) = Result.Ok ())
    in
    try
      let result = f mdb in
      cleanup () ; result
    with exn -> cleanup () ; raise exn

  exception Error_exception of MT.error

  let exn_of_error err = Error_exception err

  let%test_unit "getting a non existing account returns None" =
    with_test_instance (fun mdb ->
        Quickcheck.test MT.gen_account_key ~f:(fun key ->
            assert (MT.get_account mdb key = None) ) )

  let%test "add and retrieve an account" =
    with_test_instance (fun mdb ->
        let account = Quickcheck.random_value Account.gen in
        assert (MT.set_account mdb account = Ok ()) ;
        let key =
          MT.get_key_of_account mdb account
          |> Result.map_error ~f:exn_of_error
          |> Result.ok_exn
        in
        Account.equal (Option.value_exn (MT.get_account mdb key)) account )

  let%test "accounts are atomic" =
    with_test_instance (fun mdb ->
        let account = Quickcheck.random_value Account.gen in
        assert (MT.set_account mdb account = Ok ()) ;
        let key =
          MT.get_key_of_account mdb account
          |> Result.map_error ~f:exn_of_error
          |> Result.ok_exn
        in
        assert (MT.set_account mdb account = Ok ()) ;
        let key' =
          MT.get_key_of_account mdb account
          |> Result.map_error ~f:exn_of_error
          |> Result.ok_exn
        in
        key = key' && MT.get_account mdb key = MT.get_account mdb key' )

  let%test "accounts can be deleted" =
    with_test_instance (fun mdb ->
        let account = Quickcheck.random_value Account.gen in
        assert (MT.set_account mdb account = Ok ()) ;
        let key =
          MT.get_key_of_account mdb account
          |> Result.map_error ~f:exn_of_error
          |> Result.ok_exn
        in
        assert (Option.is_some (MT.get_account mdb key)) ;
        let account = Account.set_balance account Balance.zero in
        assert (MT.set_account mdb account = Ok ()) ;
        MT.get_account mdb key = None )

  let%test_unit "num_accounts" =
    with_test_instance (fun mdb ->
        let open Quickcheck.Generator in
        let max_accounts = Int.min (1 lsl Depth.depth) (1 lsl 5) in
        let gen_unique_nonzero_balance_accounts n =
          let open Quickcheck.Let_syntax in
          let%bind num_initial_accounts = Int.gen_incl 0 n in
          let%map accounts =
            list_with_length num_initial_accounts Account.gen
          in
          List.filter accounts ~f:(fun account ->
              not (Balance.equal (Account.balance account) Balance.zero) )
          |> List.dedup_and_sort ~compare:(fun account1 account2 ->
                 String.compare
                   (Account.public_key account1)
                   (Account.public_key account2) )
        in
        let accounts =
          Quickcheck.random_value
            (gen_unique_nonzero_balance_accounts (max_accounts / 2))
        in
        let num_initial_accounts = List.length accounts in
        List.iter accounts ~f:(fun account ->
            assert (MT.set_account mdb account = Ok ()) ) ;
        assert (MT.num_accounts mdb = num_initial_accounts) )

  let%test "deleted account keys are reassigned" =
    with_test_instance (fun mdb ->
        let account = Quickcheck.random_value Account.gen in
        let account' = Quickcheck.random_value Account.gen in
        assert (MT.set_account mdb account = Ok ()) ;
        let key =
          MT.get_key_of_account mdb account
          |> Result.map_error ~f:exn_of_error
          |> Result.ok_exn
        in
        let account = Account.set_balance account Balance.zero in
        assert (MT.set_account mdb account = Ok ()) ;
        assert (MT.set_account mdb account' = Ok ()) ;
        MT.get_account mdb key = Some account' )

  let%test_unit "set_inner_hash_at_addr_exn(address,hash); \
                 get_inner_hash_at_addr_exn(address) = hash" =
    let gen_non_empty_directions =
      let open Quickcheck.Generator in
      filter ~f:(Fn.compose not List.is_empty) (Direction.gen_list Depth.depth)
    in
    with_test_instance (fun mdb ->
        Quickcheck.test
          (Quickcheck.Generator.tuple2 gen_non_empty_directions Account.gen)
          ~sexp_of:[%sexp_of : Direction.t List.t * Account.t sexp_opaque] ~f:
          (fun (direction, account) ->
            let hash_account = Hash.hash_account account in
            let address = MT.Addr.of_directions direction in
            MT.set_inner_hash_at_addr_exn mdb address hash_account ;
            let result = MT.get_inner_hash_at_addr_exn mdb address in
            assert (Hash.equal result hash_account) ) )

  let%test_unit "If the entire database is full,\n \
                 set_all_accounts_rooted_at_exn(address,accounts);get_all_accounts_rooted_at_exn(address) \
                 = accounts" =
    with_test_instance (fun mdb ->
        let max_height = Int.min Depth.depth 5 in
        let num_accounts = 1 lsl max_height in
        let initial_accounts =
          Quickcheck.random_value
            (Quickcheck.Generator.list_with_length num_accounts Account.gen)
        in
        List.iter initial_accounts ~f:(fun account ->
            ignore @@ MT.set_account mdb account ) ;
        Quickcheck.test (Direction.gen_list max_height)
          ~sexp_of:[%sexp_of : Direction.t List.t] ~f:(fun directions ->
            let offset =
              List.init (Depth.depth - max_height) ~f:(fun _ -> Direction.Left)
            in
            let padded_directions = List.concat [offset; directions] in
            let address = MT.Addr.of_directions padded_directions in
            let num_accounts =
              1 lsl (Depth.depth - List.length padded_directions)
            in
            let accounts =
              Quickcheck.random_value
                (Quickcheck.Generator.list_with_length num_accounts Account.gen)
            in
            MT.set_all_accounts_rooted_at_exn mdb address accounts ;
            let result = MT.get_all_accounts_rooted_at_exn mdb address in
            assert (List.equal ~equal:Account.equal accounts result) ) )
end

let%test_module "test functor on in memory databases" =
  ( module struct
    module Mdb_d4 = Mdb_d (struct
      let depth = 4
    end)

    module Mdb_d30 = Mdb_d (struct
      let depth = 30
    end)
  end )
