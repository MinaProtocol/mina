(* This is half work to be merged into a Two of type _ One_or_two.t *)

open Core_kernel
module Work = Snark_work_lib

type half = [ `First | `Second ] [@@deriving equal]

type submitted_half = [ `First | `Second | `One ] [@@deriving equal]

type t =
  { spec : Work.Spec.Single.t One_or_two.t
  ; single_result : (Work.Result.Single.t * half) option
  ; sok_message : Mina_base.Sok_message.t
  }

type merge_outcome =
  | Pending of t
  | Done of Work.Result.Combined.t
  | HalfMismatch of { submitted_half : submitted_half; in_pool : half }
  | NoSuchHalf of
      { submitted_half : submitted_half
      ; spec : Work.Spec.Single.t One_or_two.t
      }

let merge_single_result (in_pool : t)
    ~(submitted_result : (unit, Ledger_proof.Cached.t) Work.Result.Single.Poly.t)
    ~(submitted_half : submitted_half) : merge_outcome =
  let { spec; single_result; sok_message = { prover; fee } } = in_pool in
  match single_result with
  | None -> (
      match (spec, submitted_half) with
      | `One spec, `One ->
          let submitted_result =
            Work.Result.Single.Poly.map ~f_spec:Fn.id
              ~f_proof:Ledger_proof.Cached.read_proof_from_disk submitted_result
          in
          let Work.Result.Single.Poly.{ proof; _ } = submitted_result in
          let statements = `One (Work.Spec.Single.Poly.statement spec) in
          Done
            ( statements
            , Mina_wire_types.Network_pool_priced_proof.V1.
                { proof = `One proof; fee = { fee; prover } } )
      | `Two (spec, _), (`First as submitted_half)
      | `Two (_, spec), (`Second as submitted_half) ->
          Pending
            { in_pool with
              single_result =
                Some ({ submitted_result with spec }, submitted_half)
            }
      | (`One _ as spec), ((`First | `Second) as submitted_half) ->
          NoSuchHalf { submitted_half; spec }
      | (`Two _ as spec), (`One as submitted_half) ->
          NoSuchHalf { submitted_half; spec } )
  | Some (in_pool_result, in_pool_half) -> (
      match (spec, submitted_half) with
      | _, `One ->
          HalfMismatch { submitted_half; in_pool = in_pool_half }
      | (`One _ as spec), ((`First | `Second) as submitted_half) ->
          NoSuchHalf { submitted_half; spec }
      | `Two (_, spec), (`Second as submitted_half)
      | `Two (spec, _), (`First as submitted_half) ->
          assert (not (equal_half in_pool_half submitted_half)) ;
          let submitted_result =
            Work.Result.Single.Poly.map ~f_spec:(const spec)
              ~f_proof:Ledger_proof.Cached.read_proof_from_disk submitted_result
          in
          let in_pool_result =
            Work.Result.Single.Poly.map ~f_spec:Fn.id
              ~f_proof:Ledger_proof.Cached.read_proof_from_disk in_pool_result
          in
          let results =
            match submitted_half with
            | `First ->
                `Two (submitted_result, in_pool_result)
            | `Second ->
                `Two (in_pool_result, submitted_result)
          in
          let statements =
            One_or_two.map
              ~f:(fun result -> Work.Spec.Single.Poly.statement result.spec)
              results
          in
          let proof = One_or_two.map ~f:(fun result -> result.proof) results in
          Done
            ( statements
            , Mina_wire_types.Network_pool_priced_proof.V1.
                { proof; fee = { fee; prover } } ) )
