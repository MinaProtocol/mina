open Core_kernel
open Currency
open Signature_lib
open Coda_base
module Intf = Intf

module Private_accounts (Accounts : Intf.Private_accounts.S) = struct
  include Accounts

  let accounts =
    let open Lazy.Let_syntax in
    let%map accounts = accounts in
    List.map accounts ~f:(fun {pk; sk; balance} ->
        ( Some sk
        , Account.create
            (Account_id.create pk Token_id.default)
            (Balance.of_formatted_string (Int.to_string balance)) ) )
end

module Public_accounts (Accounts : Intf.Public_accounts.S) = struct
  include Accounts

  let accounts =
    let open Lazy.Let_syntax in
    let%map accounts = Accounts.accounts in
    List.map accounts ~f:(fun {pk; balance; delegate} ->
        let account_id = Account_id.create pk Token_id.default in
        let base_acct = Account.create account_id (Balance.of_int balance) in
        (None, {base_acct with delegate= Option.value ~default:pk delegate}) )
end

(** Generate a ledger using the sample keypairs from [Coda_base] with the given
    balances.
*)
module Balances (Balances : Intf.Named_balances_intf) = struct
  open Intf.Private_accounts

  include Private_accounts (struct
    include Balances

    let accounts =
      let open Lazy.Let_syntax in
      let%map balances = Balances.balances
      and keypairs = Coda_base.Sample_keypairs.keypairs in
      List.mapi balances ~f:(fun i b ->
          {balance= b; pk= fst keypairs.(i); sk= snd keypairs.(i)} )
  end)
end

module Make (Inputs : Intf.Ledger_input_intf) : Intf.S = struct
  include Inputs

  (* TODO: #1488 compute this at compile time instead of lazily *)
  let t =
    let open Lazy.Let_syntax in
    let%map accounts = accounts in
    let ledger =
      match directory with
      | `Ephemeral ->
          Ledger.create_ephemeral ~depth ()
      | `New ->
          Ledger.create ~depth ()
      | `Path directory_name ->
          Ledger.create ~directory_name ~depth ()
    in
    List.iter accounts ~f:(fun (_, account) ->
        Ledger.create_new_account_exn ledger
          (Account.identifier account)
          account ) ;
    ledger

  let find_account_record_exn ~f =
    List.find_exn (Lazy.force accounts) ~f:(fun (_, account) -> f account)

  let find_new_account_record_exn old_account_pks =
    find_account_record_exn ~f:(fun new_account ->
        not
          (List.exists old_account_pks ~f:(fun old_account_pk ->
               Public_key.equal
                 (Public_key.decompress_exn (Account.public_key new_account))
                 old_account_pk )) )

  let keypair_of_account_record_exn (private_key, account) =
    let open Account in
    let sk_error_msg =
      "cannot access genesis ledger account private key "
      ^ "(HINT: did you forget to compile with `--profile=test`?)"
    in
    let pk_error_msg = "failed to decompress a genesis ledger public key" in
    let private_key = Option.value_exn private_key ~message:sk_error_msg in
    let public_key =
      Option.value_exn
        (Public_key.decompress account.Poly.Stable.Latest.public_key)
        ~message:pk_error_msg
    in
    {Keypair.public_key; private_key}

  let largest_account_exn =
    let error_msg =
      "cannot calculate largest account in genesis ledger: "
      ^ "genesis ledger has no accounts"
    in
    Memo.unit (fun () ->
        List.max_elt (Lazy.force accounts) ~compare:(fun (_, a) (_, b) ->
            Balance.compare a.balance b.balance )
        |> Option.value_exn ?here:None ?error:None ~message:error_msg )

  let largest_account_keypair_exn =
    Memo.unit (fun () -> keypair_of_account_record_exn (largest_account_exn ()))
end

module Packed = struct
  type t = (module Intf.S)

  let t ((module L) : t) = L.t

  let depth ((module L) : t) = L.depth

  let accounts ((module L) : t) = L.accounts

  let find_account_record_exn ((module L) : t) = L.find_account_record_exn

  let find_new_account_record_exn ((module L) : t) =
    L.find_new_account_record_exn

  let largest_account_exn ((module L) : t) = L.largest_account_exn

  let largest_account_keypair_exn ((module L) : t) =
    L.largest_account_keypair_exn

  let keypair_of_account_record_exn ((module L) : t) =
    L.keypair_of_account_record_exn
end

module Of_ledger (T : sig
  val t : Ledger.t Lazy.t

  val depth : int
end) : Intf.S = struct
  include T

  let accounts =
    Lazy.map t
      ~f:(Ledger.foldi ~init:[] ~f:(fun _loc accs acc -> (None, acc) :: accs))

  let find_account_record_exn ~f =
    List.find_exn (Lazy.force accounts) ~f:(fun (_, account) -> f account)

  let find_new_account_record_exn old_account_pks =
    find_account_record_exn ~f:(fun new_account ->
        not
          (List.exists old_account_pks ~f:(fun old_account_pk ->
               Public_key.equal
                 (Public_key.decompress_exn (Account.public_key new_account))
                 old_account_pk )) )

  let keypair_of_account_record_exn _ =
    failwith "cannot access genesis ledger account private key"

  let largest_account_exn =
    let error_msg =
      "cannot calculate largest account in genesis ledger: "
      ^ "genesis ledger has no accounts"
    in
    Memo.unit (fun () ->
        List.max_elt (Lazy.force accounts) ~compare:(fun (_, a) (_, b) ->
            Balance.compare a.Account.Poly.balance b.Account.Poly.balance )
        |> Option.value_exn ?here:None ?error:None ~message:error_msg )

  let largest_account_keypair_exn () =
    failwith "cannot access genesis ledger account private key"
end

let fetch_ledger, register_ledger =
  let ledgers = ref String.Map.empty in
  let register_ledger ((module Ledger : Intf.Named_accounts_intf) as l) =
    ledgers := Map.add_exn !ledgers ~key:Ledger.name ~data:l
  in
  let fetch_ledger name = Map.find_exn !ledgers name in
  (fetch_ledger, register_ledger)

module Register (Accounts : Intf.Named_accounts_intf) :
  Intf.Named_accounts_intf = struct
  let () = register_ledger (module Accounts)

  include Accounts
end

module Testnet_postake = Register (Public_accounts (Testnet_postake_ledger))

module Testnet_postake_many_producers = Register (Balances (struct
  let name = "testnet_postake_many_producers"

  let balances =
    lazy
      (let high_balances = List.init 50 ~f:(Fn.const 5_000_000) in
       let low_balances = List.init 10 ~f:(Fn.const 1_000) in
       high_balances @ low_balances)
end))

module Test = Register (Balances (Test_ledger))
module Fuzz = Register (Balances (Fuzz_ledger))
module Release = Register (Balances (Release_ledger))

module Unit_test_ledger = Make (struct
  include Test

  let directory = `Ephemeral

  let depth =
    Genesis_constants.Constraint_constants.for_unit_tests.ledger_depth
end)

let for_unit_tests : Packed.t = (module Unit_test_ledger)

module Integration_tests = struct
  module Delegation = Register (Balances (struct
    let name = "test_delegation"

    let balances =
      lazy [0 (* delegatee *); 0 (* placeholder *); 5_000_000 (* delegator *)]
  end))

  module Five_even_stakes = Register (Balances (struct
    let name = "test_five_even_stakes"

    let balances =
      lazy [1_000_000; 1_000_000; 1_000_000; 1_000_000; 1_000_000; 1_000]
  end))

  module Split_two_stakes = Register (Balances (struct
    let name = "test_split_two_stakers"

    let balances =
      lazy
        (let high_balances = List.init 2 ~f:(Fn.const 5_000_000) in
         let low_balances = List.init 16 ~f:(Fn.const 1_000) in
         high_balances @ low_balances)
  end))

  module Three_even_stakes = Register (Balances (struct
    let name = "test_three_even_stakes"

    let balances = lazy [1_000_000; 1_000_000; 1_000_000; 1000; 1000; 1000]
  end))
end
