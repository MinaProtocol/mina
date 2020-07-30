open Core_kernel
open Async_kernel
module Work = Transaction_snark_work.Statement
module Ledger_proof = Ledger_proof
module Work_info = Transaction_snark_work.Info
open Network_peer

module Rejected = struct
  [%%versioned
  module Stable = struct
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

  let unsafe_apply (pool : Pool.t) (t : t Envelope.Incoming.t) =
    let {Envelope.Incoming.data= diff; sender} = t in
    let is_local = match sender with Local -> true | _ -> false in
    let to_or_error = function
      | `Statement_not_referenced ->
          Error (`Other (Error.of_string "statement not referenced"))
      | `Added ->
          Ok (diff, ())
    in
    match diff with
    | Add_solved_work (work, ({Priced_proof.proof; fee} as p)) -> (
        let reject_and_log_if_local reason =
          if is_local then (
            Logger.trace (Pool.get_logger pool) ~module_:__MODULE__
              ~location:__LOC__
              "Rejecting locally generated snark work $work: $reason"
              ~metadata:
                [("work", Work.compact_json work); ("reason", `String reason)] ;
            Deferred.return (Error (`Locally_generated (diff, ()))) )
          else Deferred.return (Error (`Other (Error.of_string reason)))
        in
        let check_and_add () =
          match%map
            Pool.verify_and_act pool ~work:(work, p)
              ~sender:(Envelope.Incoming.sender t)
          with
          | Ok () ->
              Pool.add_snark ~is_local pool ~work ~proof ~fee |> to_or_error
          | Error e ->
              Error (`Other e)
        in
        match Pool.request_proof pool work with
        | None ->
            check_and_add ()
        | Some {fee= {fee= prev; _}; _} -> (
          match Currency.Fee.compare fee.fee prev with
          | -1 ->
              check_and_add ()
          | 0 ->
              reject_and_log_if_local "fee equal to cheapest work we have"
          | 1 ->
              reject_and_log_if_local "fee higher than cheapest work we have"
          | _ ->
              failwith "compare didn't return -1, 0, or 1!" ) )
end
