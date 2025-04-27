open Core
open Async
open Mina_base
open Worker_proof_cache
module Work = Snark_work_lib

module Impl : Intf.Worker = struct
  module Worker_state = struct
    include Unit

    let create ~constraint_constants:_ ~proof_level () =
      match proof_level with
      | Genesis_constants.Proof_level.Full ->
          failwith "Unable to handle proof-level=Full"
      | Check | No_check ->
          Deferred.unit

    let worker_wait_time = 0.5
  end

  let perform ~state:() ~spec ~prover =
    let open Work.Partitioned in
    let fee = Spec.Poly.fee_of_full spec in
    let message = Mina_base.Sok_message.create ~fee ~prover in
    let sok_digest = Mina_base.Sok_message.digest message in

    let elapsed = Time.Span.zero in
    let data =
      Spec.Poly.map_metric_with_statement
        ~f:(fun statement () ->
          Proof_with_metric.
            { proof =
                Transaction_snark.create
                  ~statement:{ statement with sok_digest }
                  ~proof:(Lazy.force Proof.transaction_dummy)
                |> Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db
            ; elapsed
            } )
        spec
    in
    Deferred.Or_error.return Result.{ data; prover }
end
