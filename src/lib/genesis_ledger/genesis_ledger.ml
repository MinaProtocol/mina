open Core_kernel
open Currency
open Signature_lib
open Coda_base
module Intf = Intf

let account_with_timing account_id balance (timing : Intf.Timing.t) =
  match timing with
  | Untimed ->
      Account.create account_id balance
  | Timed t ->
      let initial_minimum_balance =
        Currency.Balance.of_int t.initial_minimum_balance
      in
      let cliff_time = Coda_numbers.Global_slot.of_int t.cliff_time in
      let vesting_increment = Currency.Amount.of_int t.vesting_increment in
      let vesting_period = Coda_numbers.Global_slot.of_int t.vesting_period in
      Account.create_timed account_id balance ~initial_minimum_balance
        ~cliff_time ~vesting_period ~vesting_increment
      |> Or_error.ok_exn

module Private_accounts (Accounts : Intf.Private_accounts.S) = struct
  include Accounts

  let accounts =
    let open Lazy.Let_syntax in
    let%map accounts = accounts in
    List.map accounts ~f:(fun {pk; sk; balance; timing} ->
        let account_id = Account_id.create pk Token_id.default in
        let balance = Balance.of_formatted_string (Int.to_string balance) in
        (Some sk, account_with_timing account_id balance timing) )
end

module Public_accounts (Accounts : Intf.Public_accounts.S) = struct
  include Accounts

  let accounts =
    let open Lazy.Let_syntax in
    let%map accounts = Accounts.accounts in
    List.map accounts ~f:(fun {pk; balance; delegate; timing} ->
        let account_id = Account_id.create pk Token_id.default in
        let balance = Balance.of_int balance in
        let base_acct = account_with_timing account_id balance timing in
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
          { balance= b
          ; pk= fst keypairs.(i)
          ; sk= snd keypairs.(i)
          ; timing= Untimed } )
  end)
end

module Utils = struct
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

  let id_of_account_record (_private_key, account) = Account.identifier account

  let pk_of_account_record (_private_key, account) = Account.public_key account

  let find_account_record_exn ~f accounts =
    List.find_exn accounts ~f:(fun (_, account) -> f account)

  let find_new_account_record_exn_ accounts old_account_pks =
    find_account_record_exn accounts ~f:(fun new_account ->
        not
          (List.mem ~equal:Public_key.Compressed.equal old_account_pks
             (Account.public_key new_account)) )

  let find_new_account_record_exn accounts old_account_pks =
    find_new_account_record_exn_ accounts
      (List.map ~f:Public_key.compress old_account_pks)
end

include Utils

module Make (Inputs : Intf.Ledger_input_intf) : Intf.S = struct
  include Inputs

  (* TODO: #1488 compute this at compile time instead of lazily *)
  let t =
    let open Lazy.Let_syntax in
    let%map ledger, insert_accounts =
      match directory with
      | `Ephemeral ->
          lazy (Ledger.create_ephemeral ~depth (), true)
      | `New ->
          lazy (Ledger.create ~depth (), true)
      | `Path directory_name ->
          lazy (Ledger.create ~directory_name ~depth (), false)
    in
    if insert_accounts then
      List.iter (Lazy.force accounts) ~f:(fun (_, account) ->
          Ledger.create_new_account_exn ledger
            (Account.identifier account)
            account ) ;
    ledger

  include Utils

  let find_account_record_exn ~f =
    find_account_record_exn ~f (Lazy.force accounts)

  let find_new_account_record_exn_ old_account_pks =
    find_new_account_record_exn_ (Lazy.force accounts) old_account_pks

  let find_new_account_record_exn old_account_pks =
    find_new_account_record_exn (Lazy.force accounts) old_account_pks

  let largest_account_exn =
    let error_msg =
      "cannot calculate largest account in genesis ledger: "
      ^ "genesis ledger has no accounts"
    in
    Memo.unit (fun () ->
        List.max_elt (Lazy.force accounts) ~compare:(fun (_, a) (_, b) ->
            Balance.compare a.balance b.balance )
        |> Option.value_exn ?here:None ?error:None ~message:error_msg )

  let largest_account_id_exn =
    Memo.unit (fun () -> largest_account_exn () |> id_of_account_record)

  let largest_account_pk_exn =
    Memo.unit (fun () -> largest_account_exn () |> pk_of_account_record)

  let largest_account_keypair_exn =
    Memo.unit (fun () -> keypair_of_account_record_exn (largest_account_exn ()))
end

module Packed = struct
  type t = (module Intf.S)

  let t ((module L) : t) = L.t

  let depth ((module L) : t) = L.depth

  let accounts ((module L) : t) = L.accounts

  let find_account_record_exn ((module L) : t) = L.find_account_record_exn

  let find_new_account_record_exn_ ((module L) : t) =
    L.find_new_account_record_exn_

  let find_new_account_record_exn ((module L) : t) =
    L.find_new_account_record_exn

  let largest_account_exn ((module L) : t) = L.largest_account_exn ()

  let largest_account_id_exn ((module L) : t) = L.largest_account_id_exn ()

  let largest_account_pk_exn ((module L) : t) = L.largest_account_pk_exn ()

  let largest_account_keypair_exn ((module L) : t) =
    L.largest_account_keypair_exn ()
end

module Of_ledger (T : sig
  val t : Ledger.t Lazy.t

  val depth : int
end) : Intf.S = struct
  include T

  let accounts =
    Lazy.map t
      ~f:(Ledger.foldi ~init:[] ~f:(fun _loc accs acc -> (None, acc) :: accs))

  include Utils

  let find_account_record_exn ~f =
    find_account_record_exn ~f (Lazy.force accounts)

  let find_new_account_record_exn_ old_account_pks =
    find_new_account_record_exn_ (Lazy.force accounts) old_account_pks

  let find_new_account_record_exn old_account_pks =
    find_new_account_record_exn (Lazy.force accounts) old_account_pks

  let largest_account_exn =
    let error_msg =
      "cannot calculate largest account in genesis ledger: "
      ^ "genesis ledger has no accounts"
    in
    Memo.unit (fun () ->
        List.max_elt (Lazy.force accounts) ~compare:(fun (_, a) (_, b) ->
            Balance.compare a.Account.Poly.balance b.Account.Poly.balance )
        |> Option.value_exn ?here:None ?error:None ~message:error_msg )

  let largest_account_id_exn =
    Memo.unit (fun () -> largest_account_exn () |> id_of_account_record)

  let largest_account_pk_exn =
    Memo.unit (fun () -> largest_account_exn () |> pk_of_account_record)

  let largest_account_keypair_exn () =
    failwith "cannot access genesis ledger account private key"
end

let fetch_ledger, register_ledger =
  let ledgers = ref String.Map.empty in
  let register_ledger ((module Ledger : Intf.Named_accounts_intf) as l) =
    ledgers := Map.add_exn !ledgers ~key:Ledger.name ~data:l
  in
  let fetch_ledger name = Map.find !ledgers name in
  (fetch_ledger, register_ledger)

let fetch_ledger_exn name = Option.value_exn (fetch_ledger name)

module Register (Accounts : Intf.Named_accounts_intf) :
  Intf.Named_accounts_intf = struct
  let () = register_ledger (module Accounts)

  include Accounts
end

module Testnet_postake = Register (Balances (Testnet_postake_ledger))

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
