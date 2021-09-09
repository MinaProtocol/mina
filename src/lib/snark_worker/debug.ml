open Core
open Async

module Inputs = struct
  module Ledger_proof = Ledger_proof.Debug

  module Worker_state = struct
    include Unit

    let create ~constraint_constants:_ ~proof_level () =
      match proof_level with
      | Genesis_constants.Proof_level.Full ->
          failwith "Unable to handle proof-level=Full"
      | Check | None ->
          Deferred.unit

    let worker_wait_time = 0.5
  end

  let perform_single () ~message s =
    Deferred.Or_error.return
      ( ( Snark_work_lib.Work.Single.Spec.statement s
        , Mina_base.Sok_message.digest message )
      , Time.Span.zero )
end
