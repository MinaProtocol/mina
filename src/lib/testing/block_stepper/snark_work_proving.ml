open Core
open Async

let prove_non_zkapp ~sok_digest (module T : Transaction_snark.S) input
    (w : Transaction_witness.Stable.V2.t) valid_transaction =
  Deferred.Or_error.try_with ~here:[%here] (fun () ->
      T.of_non_zkapp_command_transaction ~statement:{ input with sok_digest }
        { Transaction_protocol_state.Poly.transaction = valid_transaction
        ; block_data = w.protocol_state_body
        ; global_slot = w.block_global_slot
        }
        ~init_stack:w.init_stack
        (unstage (Mina_ledger.Sparse_ledger.handler w.first_pass_ledger)) )
