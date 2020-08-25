open Core_kernel
open Async_kernel
module Work = Transaction_snark_work.Statement
module Ledger_proof = Ledger_proof
module Work_info = Transaction_snark_work.Info
open Network_peer

module Rejected = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t = unit [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, yojson]
end

module Make
    (Transition_frontier : T)
    (Pool : Intf.Snark_resource_pool_intf
            with type transition_frontier := Transition_frontier.t) :
  Intf.Snark_pool_diff_intf with type resource_pool := Pool.t = struct
  type t =
    | Add_solved_work of Work.t * Ledger_proof.t One_or_two.t Priced_proof.t
  [@@deriving compare, sexp, to_yojson]

  type rejected = Rejected.t [@@deriving sexp, yojson]

  type compact =
    { work: Work.t
    ; fee: Currency.Fee.t
    ; prover: Signature_lib.Public_key.Compressed.t }
  [@@deriving yojson]

  let to_compact = function
    | Add_solved_work (work, {proof= _; fee= {fee; prover}}) ->
        {work; fee; prover}

  let compact_json t = compact_to_yojson (to_compact t)

  let summary = function
    | Add_solved_work (work, {proof= _; fee}) ->
        Printf.sprintf
          !"Snark_pool_diff for work %s added with fee-prover %s"
          (Yojson.Safe.to_string @@ Work.compact_json work)
          (Yojson.Safe.to_string @@ Coda_base.Fee_with_prover.to_yojson fee)

  let is_empty _ = false

  let of_result
      (res :
        ( ('a, 'b, 'c) Snark_work_lib.Work.Single.Spec.t
          Snark_work_lib.Work.Spec.t
        , Ledger_proof.t )
        Snark_work_lib.Work.Result.t) =
    Add_solved_work
      ( One_or_two.map res.spec.instances
          ~f:Snark_work_lib.Work.Single.Spec.statement
      , {proof= res.proofs; fee= {fee= res.spec.fee; prover= res.prover}} )

  let has_lower_fee pool work ~fee ~sender =
    let reject_and_log_if_local reason =
      [%log' trace (Pool.get_logger pool)]
        "Rejecting snark work $work from $sender: $reason"
        ~metadata:
          [ ("work", Work.compact_json work)
          ; ("sender", Envelope.Sender.to_yojson sender)
          ; ("reason", `String reason) ] ;
      Or_error.error_string reason
    in
    match Pool.request_proof pool work with
    | None ->
        Ok ()
    | Some {fee= {fee= prev; _}; _} -> (
      match Currency.Fee.compare fee prev with
      | -1 ->
          Ok ()
      | 0 ->
          reject_and_log_if_local "fee equal to cheapest work we have"
      | 1 ->
          reject_and_log_if_local "fee higher than cheapest work we have"
      | _ ->
          failwith "compare didn't return -1, 0, or 1!" )

  let verify pool ({data; sender} : t Envelope.Incoming.t) =
    let (Add_solved_work (work, ({Priced_proof.fee; _} as p))) = data in
    let is_local = match sender with Local -> true | _ -> false in
    let verify () = Pool.verify_and_act pool ~work:(work, p) ~sender in
    (*reject higher priced gossiped proofs*)
    if is_local then verify ()
    else
      match has_lower_fee pool work ~fee:fee.fee ~sender with
      | Ok () ->
          verify ()
      | _ ->
          return false

  (* This is called after verification has occurred.*)
  let unsafe_apply (pool : Pool.t) (t : t Envelope.Incoming.t) =
    let {Envelope.Incoming.data= diff; sender} = t in
    let is_local = match sender with Local -> true | _ -> false in
    let to_or_error = function
      | `Statement_not_referenced ->
          Error (`Other (Error.of_string "statement not referenced"))
      | `Added ->
          Ok (diff, ())
    in
    Deferred.return
      (let (Add_solved_work (work, {Priced_proof.proof; fee})) = diff in
       let add_to_pool () =
         Pool.add_snark ~is_local pool ~work ~proof ~fee |> to_or_error
       in
       match has_lower_fee pool work ~fee:fee.fee ~sender with
       | Ok () ->
           add_to_pool ()
       | Error e ->
           if is_local then Error (`Locally_generated (diff, ()))
           else Error (`Other e))
end
