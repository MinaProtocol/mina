open Core_kernel
open Mina_base

module Account_info () = struct
  let keypair = Quickcheck.random_value Signature_lib.Keypair.gen

  let public_key = Signature_lib.Public_key.compress keypair.public_key

  let token_id = Token_id.default

  let account_id = Account_id.create public_key token_id
end

module Circuits (Account_info : sig
  val public_key : Signature_lib.Public_key.Compressed.t
end) =
struct
  open Account_info
  open Pickles.Impls.Step
  open Pickles_types

  let constraint_constants =
    { Snark_keys_header.Constraint_constants.sub_windows_per_window = 0
    ; ledger_depth = 0
    ; work_delay = 0
    ; block_window_duration_ms = 0
    ; transaction_capacity = Log_2 0
    ; pending_coinbase_depth = 0
    ; coinbase_amount = Unsigned.UInt64.of_int 0
    ; supercharged_coinbase_factor = 0
    ; account_creation_fee = Unsigned.UInt64.of_int 0
    ; fork = None
    }

  let feature_flags =
    { Plonk_types.Features.none_bool with
      rot = true
    ; xor = true
    ; range_check0 = true
    ; range_check1 = true
    ; foreign_field_add = true
    ; foreign_field_mul = true
    }

  let tag, _cache_handle, proof, Pickles.Provers.[ prove ] =
    Zkapps_examples.compile ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N1)
      ~max_proofs_verified:(module Nat.N0)
      ~name:"custom gates" ~constraint_constants
      ~choices:(fun ~self:_ ->
        [ { identifier = "main"
          ; prevs = []
          ; main =
              Zkapps_examples.wrap_main
                ~public_key:
                  (Signature_lib.Public_key.Compressed.var_of_t public_key)
                (fun _account_update ->
                  Pickles_optional_custom_gates_circuits.main_body
                    ~feature_flags () )
          ; feature_flags
          }
        ] )
      ()

  module Proof = (val proof)
end

let%test_module "Zkapp with optional custom gates" =
  ( module struct
    let () = Backtrace.elide := false

    module Account_info = Account_info ()

    module Circuits = Circuits (Account_info)

    let account_update =
      lazy (fst (Async.Thread_safe.block_on_async_exn (fun () -> Circuits.prove ())))

    open Transaction_snark_tests.Util

    let initialize_ledger ledger =
      let balance =
        let open Currency.Balance in
        let add_amount x y = add_amount y x in
        zero
        |> add_amount (Currency.Amount.of_nanomina_int_exn 500)
        |> Option.value_exn
      in
      let account = Account.create Account_info.account_id balance in
      let _, loc =
        Ledger.get_or_create_account ledger Account_info.account_id account
        |> Or_error.ok_exn
      in
      loc

    let%test_unit "Generate a zkapp using a combination of optional custom gates" =
      ignore ((Lazy.force account_update) : _ Zkapp_command.Call_forest.Tree.t)

    let%test_unit "Zkapp using a combination of optional custom gates verifies"
        =
      let account_update = Lazy.force account_update in
      let account_updates =
        []
        |> Zkapp_command.Call_forest.cons_tree account_update
        |> Zkapp_command.Call_forest.cons
             (Zkapps_examples.Deploy_account_update.full ~access:Either
                Account_info.public_key Account_info.token_id
                (Pickles.Side_loaded.Verification_key.of_compiled Circuits.tag) )
      in
      test_zkapp_command account_updates ~fee_payer_pk:Account_info.public_key
        ~signers:
          [| (Account_info.public_key, Account_info.keypair.private_key) |]
        ~initialize_ledger
        ~finalize_ledger:(fun _ _ -> ())
  end )
