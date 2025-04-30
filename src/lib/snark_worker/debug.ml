open Core
open Async
open Mina_base
module Work = Snark_work_lib

module Impl : Intf.Worker = struct
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

  let perform ~state:() ~spec ~sok_digest =
    let Work.Work.Spec.{ instances; _ } = spec in
    let process (single_spec : Work.Selector.Single.Spec.Stable.Latest.t) =
      let statement = Work.Work.Single.Spec.statement single_spec in
      (* NOTE: use a dummy proof *)
      let proof =
        Transaction_snark.create
          ~statement:{ statement with sok_digest }
          ~proof:(Lazy.force Proof.transaction_dummy)
      in
      let tag =
        match single_spec with
        | Work.Work.Single.Spec.Transition _ ->
            `Transition
        | Work.Work.Single.Spec.Merge _ ->
            `Merge
      in
      (proof, Time.Span.zero, tag)
    in
    One_or_two.map ~f:process instances |> Deferred.Or_error.return
end
