open Core_kernel
open Async_kernel
open Module_version
module Work = Transaction_snark_work.Statement
module Ledger_proof = Ledger_proof
module Work_info = Transaction_snark_work.Info

module Make (Transition_frontier : T) (Pool : Intf.Snark_resource_pool_intf) :
  Intf.Snark_pool_diff_intf with type resource_pool := Pool.t = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          | Add_solved_work of
              Transaction_snark_work.Statement.Stable.V1.t
              * Ledger_proof.Stable.V1.t One_or_two.Stable.V1.t
                Priced_proof.Stable.V1.t
        [@@deriving bin_io, compare, sexp, to_yojson, version]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "snark_pool_diff"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted *)
  type t = Stable.Latest.t =
    | Add_solved_work of
        Work.Stable.V1.t
        * Ledger_proof.Stable.V1.t One_or_two.t Priced_proof.Stable.V1.t
  [@@deriving compare, sexp, to_yojson]

  let compact_json = function
    | Add_solved_work (work, {proof= _; fee= {fee; prover}}) ->
        `Assoc
          [ ("work_ids", Work.compact_json work)
          ; ("fee", Currency.Fee.to_yojson fee)
          ; ("prover", Signature_lib.Public_key.Compressed.to_yojson prover) ]

  let summary = function
    | Stable.V1.Add_solved_work (work, {proof= _; fee}) ->
        Printf.sprintf
          !"Snark_pool_diff for work %s added with fee-prover %s"
          (Yojson.Safe.to_string @@ Work.compact_json work)
          (Yojson.Safe.to_string @@ Coda_base.Fee_with_prover.to_yojson fee)

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

  let apply (pool : Pool.t) (t : t Envelope.Incoming.t) :
      t Or_error.t Deferred.t =
    let open Deferred.Or_error.Let_syntax in
    let {Envelope.Incoming.data= diff; sender} = t in
    let is_local = match sender with Local -> true | _ -> false in
    let to_or_error = function
      | `Statement_not_referenced ->
          Or_error.error_string "statement not referenced"
      | `Added ->
          Ok diff
    in
    match diff with
    | Stable.V1.Add_solved_work (work, ({Priced_proof.proof; fee} as p)) -> (
        let reject_and_log_if_local reason =
          if is_local then
            Logger.warn (Pool.get_logger pool) ~module_:__MODULE__
              ~location:__LOC__
              "Rejecting locally generated snark work $work, %s" reason
              ~metadata:[("work", Work.compact_json work)] ;
          Deferred.return (Or_error.error_string reason)
        in
        let check_and_add () =
          let%bind () =
            Pool.verify_and_act pool ~work:(work, p)
              ~sender:(Envelope.Incoming.sender t)
          in
          Pool.add_snark ~is_local pool ~work ~proof ~fee
          |> to_or_error |> Deferred.return
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
