open Core

type ('accum, 'final) fold_action =
  | Continue of 'accum
  | Continue_remove of 'accum
  | Stop of 'final
  | Stop_remove of 'final

module Make (Id : Map.Key) (Spec : T) = struct
  type job = (Spec.t, Id.t) Snark_work_lib.With_job_meta.t

  module IdMap = Map.Make (Id)

  type t = job IdMap.t

  let peek t : job option = IdMap.min_elt t |> Option.map ~f:Tuple2.get2

  let fold_until ~init ~f ~finish t =
    let processed_items = Queue.create () in
    let rec seq_fold_until acc seq =
      match Sequence.next seq with
      | Some ((k, v), seq_new) -> (
          match f acc v with
          | Continue acc_new ->
              Queue.enqueue processed_items (k, v) ;
              seq_fold_until acc_new seq_new
          | Continue_remove acc_new ->
              seq_fold_until acc_new seq_new
          | Stop final ->
              let map_new =
                Array.append
                  (Queue.to_array processed_items)
                  (Sequence.to_array seq)
                |> IdMap.of_sorted_array_unchecked
              in
              (final, map_new)
          | Stop_remove final ->
              let map_new =
                Array.append
                  (Queue.to_array processed_items)
                  (Sequence.to_array seq_new)
                |> IdMap.of_sorted_array_unchecked
              in
              (final, map_new) )
      | None ->
          let map_new =
            Queue.to_array processed_items |> IdMap.of_sorted_array_unchecked
          in
          (finish acc, map_new)
    in
    let seq = IdMap.to_sequence ~order:`Increasing_key t in
    seq_fold_until init seq

  let attempt_add ~id ~job t = IdMap.add ~key:id ~data:job t

  let change ~id ~f t = IdMap.change t id ~f

  let set ~id ~job t = IdMap.set ~key:id ~data:job t

  let find ~id t = IdMap.find t id
end
