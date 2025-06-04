(* This is partial work to be combined into a Snark_work_lib.Result.Combined.t *)

open Core_kernel

type half = [ `First | `Second ] [@@deriving equal]

type submitted_half = [ `First | `Second | `One ]

type t =
  | Spec_only of
      { spec : Snark_work_lib.Selector.Single.Spec.t One_or_two.t
      ; sok_message : Mina_base.Sok_message.t
      }
  | One_of_two of
      { other_spec : Snark_work_lib.Selector.Single.Spec.t
      ; sok_message : Mina_base.Sok_message.t
      ; in_pool_half : half
      ; in_pool_result : Snark_work_lib.Result.Single.t
      }

type merge_outcome =
  | Pending of t
  | Done of Snark_work_lib.Result.Combined.t
  | HalfAlreadyInPool
  | StructureMismatch of
      { spec : Snark_work_lib.Selector.Single.Spec.t One_or_two.t }

let finalize_one ~submitted_result ~spec ~fee ~prover =
  let submitted_result =
    Snark_work_lib.Result.Single.Poly.map ~f_spec:Fn.id
      ~f_proof:Ledger_proof.Cached.read_proof_from_disk submitted_result
  in
  let Snark_work_lib.Result.Single.Poly.{ proof; _ } = submitted_result in
  let statements =
    `One (Snark_work_lib.Selector.Single.Spec.Poly.statement spec)
  in
  Done
    ( statements
    , Mina_wire_types.Network_pool_priced_proof.V1.
        { proof = `One proof; fee = { fee; prover } } )

let finalize_two ~submitted_result ~other_spec ~in_pool_result ~submitted_half
    ~fee ~prover =
  let submitted_result =
    Snark_work_lib.Result.Single.Poly.map ~f_spec:(const other_spec)
      ~f_proof:Ledger_proof.Cached.read_proof_from_disk submitted_result
  in
  let in_pool_result =
    Snark_work_lib.Result.Single.Poly.map ~f_spec:Fn.id
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
      ~f:(fun result ->
        Snark_work_lib.Selector.Single.Spec.Poly.statement result.spec )
      results
  in
  let proof = One_or_two.map ~f:(fun result -> result.proof) results in
  Done
    ( statements
    , Mina_wire_types.Network_pool_priced_proof.V1.
        { proof; fee = { fee; prover } } )

let merge_single_result (current : t)
    ~(submitted_result :
       (unit, Ledger_proof.Cached.t) Snark_work_lib.Result.Single.Poly.t )
    ~(submitted_half : submitted_half) : merge_outcome =
  match (current, submitted_half) with
  | Spec_only { spec = `One spec; sok_message = { fee; prover } }, `One ->
      finalize_one ~submitted_result ~spec ~fee ~prover
  | ( Spec_only { spec = `Two (spec, other_spec); sok_message }
    , (`First as submitted_half) )
  | ( Spec_only { spec = `Two (other_spec, spec); sok_message }
    , (`Second as submitted_half) ) ->
      Pending
        (One_of_two
           { other_spec
           ; sok_message
           ; in_pool_half = submitted_half
           ; in_pool_result = { submitted_result with spec }
           } )
  | ( One_of_two
        { other_spec
        ; in_pool_half
        ; in_pool_result
        ; sok_message = { fee; prover }
        }
    , ((`First | `Second) as submitted_half) ) ->
      if equal_half in_pool_half submitted_half then HalfAlreadyInPool
      else
        finalize_two ~submitted_result ~other_spec ~in_pool_result
          ~submitted_half ~fee ~prover
  | Spec_only { spec = `One _ as spec; _ }, (`First | `Second)
  | Spec_only { spec = `Two _ as spec; _ }, `One ->
      StructureMismatch { spec }
  | One_of_two { in_pool_half; in_pool_result; other_spec; _ }, `One ->
      let spec =
        match in_pool_half with
        | `First ->
            `Two (in_pool_result.spec, other_spec)
        | `Second ->
            `Two (other_spec, in_pool_result.spec)
      in
      StructureMismatch { spec }
