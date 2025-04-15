open Core
open Async
open Mina_base

module Impl : Worker_impl_intf.Worker_impl = struct
  module Worker_state = struct
    type t = unit

    let create ~constraint_constants:_ ~proof_level () =
      match proof_level with
      | Genesis_constants.Proof_level.Full ->
          failwith "Unable to handle proof-level=Full"
      | Check | No_check ->
          Deferred.unit

    let worker_wait_time = 0.5
  end

  let perform_single () ~message spec :
      (Ledger_proof.t * Time.Span.t) Deferred.Or_error.t =
    (* Use a dummy proof. *)
    let stmt = Rpcs_types.Wire_work.Single.Spec.statement spec in
    let sok_digest = Sok_message.digest message in
    Deferred.Or_error.return
    @@ ( Transaction_snark.create ~statement:{ stmt with sok_digest }
           ~proof:(Lazy.force Proof.transaction_dummy)
       , Time.Span.zero )
end
