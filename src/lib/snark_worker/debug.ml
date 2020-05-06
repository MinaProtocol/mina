open Core
open Async

module Inputs = struct
  module Ledger_proof = Ledger_proof.Debug

  module Worker_state = struct
    include Unit

    let create ~proof_level () =
      ( if Genesis_constants.Proof_level.is_compiled proof_level then
        Genesis_constants.Proof_level.(
          failwithf "Bad proof level %s (expected %s)" (to_string proof_level)
            (to_string compiled) ()) ) ;
      match proof_level with
      | Genesis_constants.Proof_level.Full ->
          failwith "Unable to handle proof-level=Full"
      | Check | None ->
          Deferred.unit

    let worker_wait_time = 0.5
  end

  let perform_single () ~message s =
    Ok
      ( ( Snark_work_lib.Work.Single.Spec.statement s
        , Coda_base.Sok_message.digest message )
      , Time.Span.zero )
end

module Worker = Functor.Make (Inputs)
