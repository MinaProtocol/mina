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
  let with_instance ~f =
    let db1 = Db.create ~depth:Cfg.depth () in
    let db2 = Db_migrated.create ~depth:Cfg.depth () in
    let ledger = Db_converting.create db1 db2 in
    try
      let result = f ledger in
      Db_converting.close ledger ; result
    with exn -> Db_converting.close ledger ; raise exn

  let create_new_account_exn mdb account =
    let public_key = Account.identifier account in
    let action, location =
      Db_converting.get_or_create_account mdb public_key account
      |> Or_error.ok_exn
    in
    match action with
    | `Existed ->
        failwith "Expected to allocate a new account"
    | `Added ->
        location

  let test_section_name =
    Printf.sprintf "In-memory converting db (depth %d)" Cfg.depth

  let test_stack = Stack.create ()

  let add_test ?(speed = `Quick) name f =
    Alcotest.test_case name speed f |> Stack.push test_stack

  let () =
    add_test "add and retrieve an account" (fun () ->
        with_instance ~f:(fun db ->
            let account = Quickcheck.random_value Account.gen in
            let location = create_new_account_exn db account in
            let stored_migrated_account =
              let migrated_db = Db_converting.converting_ledger db in
              Option.value_exn (Db_migrated.get migrated_db location)
            in
            [%test_eq: Account.t]
              (Option.value_exn (Db_converting.get db location))
              account ;
            [%test_eq: Migrated.Account.t] stored_migrated_account
              (Db_converting.convert account) ) )

  let tests =
    let actual_tests = Stack.fold test_stack ~f:(fun l t -> t :: l) ~init:[] in
    (test_section_name, actual_tests)
end

let tests =
  let module Tests = Make (struct
    let depth = 30
  end) in
  [ Tests.tests ]
