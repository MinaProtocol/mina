open Core_kernel

type ('accum, 'final) fold_action =
  | Continue of 'accum
  | Continue_remove of 'accum
  | Stop of 'final
  | Stop_remove of 'final

module Make (Id : Map.Key) (Spec : T) = struct
  type job = (Spec.t, Id.t) Snark_work_lib.With_job_meta.t

  module IdMap = Map.Make (Id)

  type t = job IdMap.t

  let first_job t : job option = IdMap.min_elt t |> Option.map ~f:Tuple2.get2

  let fold_until ~init ~f ~finish t =
    let seq = IdMap.to_sequence ~order:`Increasing_key t in
    let handle_item (acc, retained) (k, v) =
      match f acc v with
      | Continue acc_new ->
          Continue_or_stop.Continue (acc_new, retained)
      | Continue_remove acc_new ->
          Continue (acc_new, IdMap.remove retained k)
      | Stop final ->
          Stop (final, retained)
      | Stop_remove final ->
          Stop (final, IdMap.remove retained k)
    in

    Sequence.fold_until seq ~init:(init, t) ~f:handle_item
      ~finish:(Tuple2.map_fst ~f:finish)

  let add ~id ~job t = IdMap.add ~key:id ~data:job t

  let change ~id ~f t = IdMap.change t id ~f

  let set ~id ~job t = IdMap.set ~key:id ~data:job t

  let find ~id t = IdMap.find t id
end
