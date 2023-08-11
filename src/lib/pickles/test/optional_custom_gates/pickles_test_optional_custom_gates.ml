open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let add_constraint c = assert_ { basic = c; annotation = None }

let add_plonk_constraint c =
  add_constraint
    (Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T c)

let fresh_int i = exists Field.typ ~compute:(fun () -> Field.Constant.of_int i)

let main_xor () =
  add_plonk_constraint
    (Xor
       { in1 = fresh_int 0
       ; in2 = fresh_int 0
       ; out = fresh_int 0
       ; in1_0 = fresh_int 0
       ; in1_1 = fresh_int 0
       ; in1_2 = fresh_int 0
       ; in1_3 = fresh_int 0
       ; in2_0 = fresh_int 0
       ; in2_1 = fresh_int 0
       ; in2_2 = fresh_int 0
       ; in2_3 = fresh_int 0
       ; out_0 = fresh_int 0
       ; out_1 = fresh_int 0
       ; out_2 = fresh_int 0
       ; out_3 = fresh_int 0
       } ) ;
  add_plonk_constraint (Raw { kind = Zero; values = [||]; coeffs = [||] })

module Make_test (Inputs : sig
  val feature_flags : bool Plonk_types.Features.t
end) =
struct
  open Inputs

  let _tag, _cache_handle, proof, Pickles.Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N1)
      ~max_proofs_verified:(module Nat.N0)
      ~name:"optional_custom_gates"
      ~constraint_constants:
        (* TODO(mrmr1993): This was misguided.. Delete. *)
        { sub_windows_per_window = 0
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
      ~choices:(fun ~self:_ ->
        [ { identifier = "main"
          ; prevs = []
          ; main =
              (fun _ ->
                if feature_flags.xor then main_xor () ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags
          }
        ] )
      ()

  module Proof = (val proof)

  let public_input, (), proof =
    Async.Thread_safe.block_on_async_exn (fun () -> prove ())

  let () =
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           Proof.verify [ (public_input, proof) ] ) )
end

module Xor = Make_test (struct
  let feature_flags = Plonk_types.Features.{ none_bool with xor = true }
end)
