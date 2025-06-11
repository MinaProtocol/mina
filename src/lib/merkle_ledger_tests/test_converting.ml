open Core
open Test_stubs
module Database = Merkle_ledger.Database

module Migrated = struct
  module Account :
    Merkle_ledger.Intf.Account
      with type token_id := Token_id.t
       and type account_id := Account_id.t
       and type balance := Balance.t
       and type t = Mina_base.Account.Unstable.t = struct
    include Mina_base.Account.Unstable

    let token Mina_base.Account.Unstable.{ token_id; _ } = token_id

    let identifier ({ public_key; token_id; _ } : t) =
      Account_id.create public_key token_id
  end

  module Hash = struct
    module T = struct
      type t = Md5.t [@@deriving sexp, hash, compare, bin_io_unversioned, equal]
    end

    include T

    let (eq : (t, Test_stubs.Hash_arg.t) Type_equal.t) = Type_equal.T

    include Codable.Make_base58_check (struct
      type t = T.t [@@deriving bin_io_unversioned]

      let description = "Ledger test hash"

      let version_byte = Base58_check.Version_bytes.ledger_test_hash
    end)

    include Hashable.Make_binable (Test_stubs.Hash_arg)

    (* to prevent pre-image attack,
     * important impossible to create an account such that (merge a b = hash_account account) *)

    let hash_account account =
      Md5.digest_string (Format.sprintf !"0%{sexp: Account.t}" account)

    let merge ~height a b =
      let res =
        Md5.digest_string
          (sprintf "test_ledger_%d:%s%s" height (Md5.to_hex a) (Md5.to_hex b))
      in
      res

    let empty_account = hash_account Account.empty
  end
end

module Inputs_migrated =
  Test_database.Make_inputs (Migrated.Account) (Migrated.Hash)

module type DB_migrated =
  Test_database.Account_Db with type account := Migrated.Account.t

module Db = Database.Make (Test_database.Inputs)
module Db_migrated = Database.Make (Inputs_migrated)

module Db_converting =
  Merkle_ledger.Converting_merkle_tree.Make
    (struct
      type converted_account = Mina_base.Account.Unstable.t

      let convert (account : Mina_base.Account.Stable.Latest.t) =
        { Mina_base.Account.Unstable.public_key = account.public_key
        ; token_id = account.token_id
        ; token_symbol = account.token_symbol
        ; balance = account.balance
        ; nonce = account.nonce
        ; receipt_chain_hash = account.receipt_chain_hash
        ; delegate = account.delegate
        ; voting_for = account.voting_for
        ; timing = account.timing
        ; permissions = account.permissions
        ; zkapp = account.zkapp
        ; unstable_field = account.nonce
        }

      include Test_database.Inputs
    end)
    (Db)
    (Db_migrated)

module Make (Cfg : sig
  val depth : int
end) =
struct
  let with_primary ~f = Db.with_ledger ~f ~depth:Cfg.depth

  let with_migrated ~f = Db_migrated.with_ledger ~f ~depth:Cfg.depth

  let with_instance ~f =
    let db1 = Db.create ~depth:Cfg.depth () in
    let db2 = Db_migrated.create ~depth:Cfg.depth () in
    let ledger = Db_converting.create db1 db2 in
    try
      let result = f ledger in
      Db_converting.close ledger ; result
    with exn -> Db_converting.close ledger ; raise exn

  let existing_account_exn account =
    let action, location = Or_error.ok_exn account in
    match action with
    | `Existed ->
        failwith "Expected to allocate a new account"
    | `Added ->
        location

  let create_new_converting_account_exn mdb account =
    let public_key = Account.identifier account in
    Db_converting.get_or_create_account mdb public_key account
    |> existing_account_exn

  let create_new_primary_account_exn db account =
    let public_key = Account.identifier account in
    Db.get_or_create_account db public_key account |> existing_account_exn

  let random_primary_accounts max_height =
    let num_accounts = 1 lsl max_height in
    Quickcheck.random_value
      (Quickcheck.Generator.list_with_length num_accounts Account.gen)

  let populate_primary_db mdb max_height =
    random_primary_accounts max_height
    |> List.iter ~f:(fun account ->
           let action, location =
             Db.get_or_create_account mdb (Account.identifier account) account
             |> Or_error.ok_exn
           in
           match action with
           | `Added ->
               ()
           | `Existed ->
               Db.set mdb location account )

  let test_section_name =
    Printf.sprintf "In-memory converting db (depth %d)" Cfg.depth

  let test_stack = Stack.create ()

  let add_test ?(speed = `Quick) name f =
    Alcotest.test_case name speed f |> Stack.push test_stack

  let () =
    add_test "add and retrieve an account" (fun () ->
        with_instance ~f:(fun db ->
            let account = Quickcheck.random_value Account.gen in
            let location = create_new_converting_account_exn db account in
            let stored_migrated_account =
              let migrated_db = Db_converting.converting_ledger db in
              Option.value_exn (Db_migrated.get migrated_db location)
            in
            [%test_eq: Account.t]
              (Option.value_exn (Db_converting.get db location))
              account ;
            [%test_eq: Migrated.Account.t] stored_migrated_account
              (Db_converting.convert account) ) )

  let () =
    add_test "add an account, migrate, retrieve" (fun () ->
        with_primary ~f:(fun primary ->
            let account = Quickcheck.random_value Account.gen in
            let location = create_new_primary_account_exn primary account in
            with_migrated ~f:(fun migrated ->
                (* We don't need the actual converting ledger for this test,
                   only the side effect of migration *)
                let _converting =
                  Db_converting.create_with_migration primary migrated
                in
                let stored_migrated_account =
                  Option.value_exn (Db_migrated.get migrated location)
                in
                [%test_eq: Migrated.Account.t] stored_migrated_account
                  (Db_converting.convert account) ) ) )

  let () =
    add_test "create random ledger, migrate, test iteration order" (fun () ->
        with_primary ~f:(fun primary ->
            let depth = Db.depth primary in
            let max_height = Int.min 5 depth in
            populate_primary_db primary max_height ;
            with_migrated ~f:(fun migrated ->
                let _converting =
                  Db_converting.create_with_migration primary migrated
                in
                assert (
                  Db.num_accounts primary = Db_migrated.num_accounts migrated ) ;
                Db.iteri primary ~f:(fun idx primary_account ->
                    let stored_migrated_account =
                      Db_migrated.get_at_index_exn migrated idx
                    in
                    [%test_eq: Migrated.Account.t] stored_migrated_account
                      (Db_converting.convert primary_account) ) ) ) )

  let tests =
    let actual_tests = Stack.fold test_stack ~f:(fun l t -> t :: l) ~init:[] in
    (test_section_name, actual_tests)
end

let tests =
  let module Tests = Make (struct
    let depth = 30
  end) in
  [ Tests.tests ]
