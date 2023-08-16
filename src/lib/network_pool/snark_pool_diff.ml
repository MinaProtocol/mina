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
  type t = Mina_wire_types.Network_pool.Snark_pool.Diff_versioned.V2.t =
    | Add_solved_work of Work.t * Ledger_proof.t One_or_two.t Priced_proof.t
    | Empty
  [@@deriving compare, sexp, to_yojson, hash]

  type verified = t [@@deriving compare, sexp, to_yojson]

  let t_of_verified = ident

  type rejected = Rejected.t [@@deriving sexp, yojson]

  let label = Pool.label

  let reject_overloaded_diff _ = ()

  type compact =
    { work : Work.t
    ; fee : Currency.Fee.t
    ; prover : Signature_lib.Public_key.Compressed.t
    }
  [@@deriving yojson, hash]

  let to_compact = function
    | Add_solved_work (work, { proof = _; fee = { fee; prover } }) ->
        Some { work; fee; prover }
    | Empty ->
        None

  let compact_json t = to_compact t |> Option.map ~f:compact_to_yojson

  let empty = Empty

  (* snark pool diffs are not bundled, so size is always 1 *)
  let size _ = 1

  let score = function
    | Add_solved_work (_w, p) ->
        One_or_two.length p.proof
    | Empty ->
        1

  (* Effectively disable rate limitting for purpose of testing  *)
  let max_per_15_seconds = 2000

  let summary = function
    | Add_solved_work (work, { proof = _; fee }) ->
        Printf.sprintf
          !"Snark_pool_diff for work %s added with fee-prover %s"
          (Yojson.Safe.to_string @@ Work.compact_json work)
          (Yojson.Safe.to_string @@ Mina_base.Fee_with_prover.to_yojson fee)
    | Empty ->
        "empty Snark_pool_diff"

  let is_empty _ = false

  let of_result
      (res :
        ( (_, _) Snark_work_lib.Work.Single.Spec.t Snark_work_lib.Work.Spec.t
        , Ledger_proof.t )
        Snark_work_lib.Work.Result.t ) =
    Add_solved_work
      ( One_or_two.map res.spec.instances
          ~f:Snark_work_lib.Work.Single.Spec.statement
      , { proof = res.proofs
        ; fee = { fee = res.spec.fee; prover = res.prover }
        } )

  (** Check whether there is a proof with lower fee in the pool.
      Returns [Ok ()] is the [~fee] would be the lowest in pool.
  *)
  let has_no_lower_fee pool work ~fee ~sender =
    let reject_and_log_if_local reason =
      [%log' trace (Pool.get_logger pool)]
        "Rejecting snark work $work from $sender: $reason"
        ~metadata:
          [ ("work", Work.compact_json work)
          ; ("sender", Envelope.Sender.to_yojson sender)
          ; ( "reason"
            , Error_json.error_to_yojson
              @@ Intf.Verification_error.to_error reason )
          ] ;
      Result.fail reason
    in
    match Pool.request_proof pool work with
    | None ->
        Ok ()
    | Some { fee = { fee = prev; _ }; _ } ->
        let cmp_res = Currency.Fee.compare fee prev in
        if cmp_res < 0 then Ok ()
        else if cmp_res = 0 then
          reject_and_log_if_local Intf.Verification_error.Fee_equal
        else reject_and_log_if_local Intf.Verification_error.Fee_higher

  let verify pool ({ data; sender; _ } as t : t Envelope.Incoming.t) =
    match data with
    | Empty ->
        Deferred.Result.fail
        @@ Intf.Verification_error.Invalid
             (Error.of_string "empty snark pool diff")
    | Add_solved_work (work, ({ Priced_proof.fee; _ } as p)) ->
        let is_local = match sender with Local -> true | _ -> false in
        let open Deferred.Result in
        let verify () =
          Pool.verify_and_act pool ~work:(work, p) ~sender >>| const t
        in
        (*reject higher priced gossiped proofs*)
        if is_local then verify ()
        else
          Deferred.return (has_no_lower_fee pool work ~fee:fee.fee ~sender)
          >>= verify

  (* This is called after verification has occurred.*)
  let unsafe_apply (pool : Pool.t) (t : t Envelope.Incoming.t) =
    let { Envelope.Incoming.data = diff; sender; _ } = t in
    match diff with
    | Empty ->
        Error (`Other (Error.of_string "cannot apply empty snark pool diff"))
    | Add_solved_work (work, { Priced_proof.proof; fee }) -> (
        let is_local = match sender with Local -> true | _ -> false in
        let to_or_error = function
          | `Statement_not_referenced ->
              Error (`Other (Error.of_string "statement not referenced"))
          | `Added ->
              Ok (diff, ())
        in
        match has_no_lower_fee pool work ~fee:fee.fee ~sender with
        | Ok () ->
            let%map.Result accepted, rejected =
              Pool.add_snark ~is_local pool ~work ~proof ~fee |> to_or_error
            in
            (`Accept, accepted, rejected)
        | Error e ->
            if is_local then Error (`Locally_generated (diff, ()))
            else Error (`Other (Intf.Verification_error.to_error e)) )

  type Structured_log_events.t +=
    | Snark_work_received of { work : compact; sender : Envelope.Sender.t }
    [@@deriving
      register_event { msg = "Received Snark-pool diff $work from $sender" }]

  let update_metrics ~logger ~log_gossip_heard
      (Envelope.Incoming.{ data = diff; sender; _ } : t Envelope.Incoming.t)
      valid_cb =
    Mina_metrics.(Counter.inc_one Network.gossip_messages_received) ;
    Mina_metrics.(Gauge.inc_one Network.snark_pool_diff_received) ;
    if log_gossip_heard then
      Option.iter (to_compact diff) ~f:(fun work ->
          [%str_log debug] (Snark_work_received { work; sender }) ) ;
    Mina_metrics.(Counter.inc_one Network.Snark_work.received) ;
    Mina_net2.Validation_callback.set_message_type valid_cb `Snark_work

  let log_internal ?reason ~logger msg = function
    | { Envelope.Incoming.data = Empty; _ } ->
        ()
    | { data = Add_solved_work (work, { fee = { fee; prover }; _ }); sender; _ }
      ->
        let metadata =
          [ ("work_ids", Transaction_snark_work.Statement.compact_json work)
          ; ("fee", Currency.Fee.to_yojson fee)
          ; ("prover", Signature_lib.Public_key.Compressed.to_yojson prover)
          ]
        in
        let metadata =
          match sender with
          | Remote addr ->
              ("sender", `String (Core.Unix.Inet_addr.to_string @@ Peer.ip addr))
              :: metadata
          | Local ->
              metadata
        in
        let metadata =
          Option.value_map reason
            ~f:(fun r -> List.cons ("reason", `String r))
            ~default:ident metadata
        in
        [%log internal] "%s" ("Snark_work_" ^ msg) ~metadata
end
