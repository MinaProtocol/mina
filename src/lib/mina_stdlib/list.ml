open Core_kernel
include List

module Length = struct
  type 'a t = ('a list, int) Sigs.predicate2

  let equal l len = Caml.List.compare_length_with l len = 0

  let unequal l len = Caml.List.compare_length_with l len <> 0

  let gte l len = Caml.List.compare_length_with l len >= 0

  let gt l len = Caml.List.compare_length_with l len > 0

  let lte l len = Caml.List.compare_length_with l len <= 0

  let lt l len = Caml.List.compare_length_with l len < 0

  module Compare = struct
    let ( = ) = equal

    let ( <> ) = unequal

    let ( >= ) = gte

    let ( > ) = gt

    let ( <= ) = lte

    let ( < ) = lt
  end
end

(** [process_separately] splits the list in two, and applies transformations
  * to both parts, then it merges the list back in the same order it was originally.
  * [process_left] and [process_right] are expected to return the same number
  * of elements processed in the same order.
  *)
let process_separately
    (type input left right left_output right_output output_item final_output)
    ~(partitioner : input -> (left, right) Either.t)
    ~(process_left : left list -> left_output)
    ~(process_right : right list -> right_output)
    ~(finalizer :
          left_output
       -> right_output
       -> f:(output_item list -> output_item list -> output_item list)
       -> final_output ) (input : input list) : final_output =
  let input_with_indices = List.mapi input ~f:(fun idx el -> (idx, el)) in
  let lefts, rights =
    List.partition_map input_with_indices ~f:(fun (idx, el) ->
        match partitioner el with
        | First x ->
            First (idx, x)
        | Second y ->
            Second (idx, y) )
  in
  let batch_process_snd ~f = Fn.compose (Tuple2.map_snd ~f) List.unzip in
  let lefts_idx, lefts_processed = batch_process_snd ~f:process_left lefts in
  let rights_idx, rights_processed =
    batch_process_snd ~f:process_right rights
  in

  finalizer lefts_processed rights_processed
    ~f:(fun left_materialized right_materialized ->
      let left_materialized_indexed =
        List.zip_exn lefts_idx left_materialized
      in
      let right_materialized_indexed =
        List.zip_exn rights_idx right_materialized
      in
      List.merge left_materialized_indexed right_materialized_indexed
        ~compare:(fun (left_idx, _) (right_idx, _) ->
          Int.compare left_idx right_idx )
      |> List.map ~f:snd )

let%test_module "process_separately" =
  ( module struct
    let%test "negate negative, div positive by 2" =
      let partitioner x = if x < 0 then First x else Second x in
      let process_left = List.map ~f:Int.neg in
      let process_right lst =
        let safe_div a b = match b with 0 -> None | x -> Some (a / b) in
        List.map ~f:(fun e -> safe_div e 2) lst |> Option.all
      in
      let finalizer left right_m ~f =
        match right_m with None -> [] | Some right -> f left right
      in
      process_separately ~partitioner ~process_left ~process_right ~finalizer
        [ -1; -3; -5; 4; -99; 8; 10 ]
      |> List.equal Int.equal [ 1; 3; 5; 2; 99; 4; 5 ]
  end )
