open Core
open Async

module Inputs = struct
  module Ledger_proof = Ledger_proof.Debug

  module Worker_state = struct
    include Unit

    let create () = Deferred.unit

    let worker_wait_time = 0.5
  end

  let perform_single () ~message s =
    Ok
      ( ( Snark_work_lib.Work.Single.Spec.statement s
        , Coda_base.Sok_message.digest message )
      , Time.Span.zero )
end

module Worker = Functor.Make (Inputs)
