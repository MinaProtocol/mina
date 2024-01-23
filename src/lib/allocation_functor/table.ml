open Core_kernel

(** immutable, serializable statistics derived from allocation data *)
module Allocation_statistics = struct
  (* times represented in ms *)
  type quartiles = { q1 : float; q2 : float; q3 : float; q4 : float }
  [@@deriving yojson]

  let make_quartiles n = { q1 = n; q2 = n; q3 = n; q4 = n }

  let empty_quartiles = make_quartiles 0.0

  type t = { count : int; lifetimes : quartiles } [@@deriving yojson]

  let write_metrics { count; lifetimes } object_id =
    let open Mina_metrics in
    let open Mina_metrics.Object_lifetime_statistics in
    let { q1; q2; q3; q4 } = lifetimes in
    let q x = lifetime_quartile_ms ~name:object_id ~quartile:x in
    Gauge.set (live_count ~name:object_id) (Int.to_float count) ;
    Gauge.set (q `Q1) q1 ;
    Gauge.set (q `Q2) q2 ;
    Gauge.set (q `Q3) q3 ;
    Gauge.set (q `Q4) q4
end

(** mutable data for an object we track allocations of (one exists per object type) *)
module Allocation_data = struct
  (* stops being unique after 2^{30,62} values; perhaps we should use guids instead *)
  type allocation_id = int

  let initial_allocation_id = Int.min_value

  (* indexed queue data structure would be more effecient here, but keeping this simple for now *)
  type t =
    { allocation_times : (allocation_id * Time.t) Queue.t
    ; mutable next_allocation_id : allocation_id
    }

  let create () =
    { allocation_times = Queue.create ()
    ; next_allocation_id = initial_allocation_id
    }

  let register_allocation data =
    let id = data.next_allocation_id in
    Queue.enqueue data.allocation_times (id, Time.now ()) ;
    data.next_allocation_id <- data.next_allocation_id + 1 ;
    id

  (* currently O(n) wrt queue size *)
  let unregister_allocation data id =
    Queue.filter_inplace data.allocation_times ~f:(fun (id', _) -> id = id')

  let compute_statistics { allocation_times; _ } =
    let now = Time.now () in
    let count = Queue.length allocation_times in
    let lifetime_ms_of_time time = Time.Span.to_ms (Time.diff now time) in
    let get_lifetime_ms i =
      lifetime_ms_of_time (snd @@ Queue.get allocation_times i)
    in
    let mean_indices max_len =
      let m = max_len - 1 in
      if m mod 2 = 0 then [ m / 2 ] else [ m / 2; (m / 2) + 1 ]
    in
    let mean offset length =
      let indices =
        mean_indices length |> List.filter ~f:(fun x -> x < count)
      in
      let sum =
        List.fold_left indices ~init:0.0 ~f:(fun acc i ->
            acc +. get_lifetime_ms (count - 1 - (i + offset)) )
      in
      sum /. Int.to_float (List.length indices)
    in
    let lifetimes =
      match count with
      | 0 ->
          Allocation_statistics.empty_quartiles
      | 1 ->
          Allocation_statistics.make_quartiles (get_lifetime_ms 0)
      | _ ->
          let q1 = mean 0 (count / 2) in
          let q2 = mean 0 count in
          let q3_offset = if count mod 2 = 0 then 0 else 1 in
          let q3 = mean ((count / 2) + q3_offset) (count / 2) in
          let q4 = get_lifetime_ms 0 in
          Allocation_statistics.{ q1; q2; q3; q4 }
    in
    Allocation_statistics.{ count; lifetimes }

  let compute_statistics t =
    try compute_statistics t
    with _ ->
      Allocation_statistics.
        { count = 0; lifetimes = Allocation_statistics.make_quartiles 0. }

  let%test_module "Allocation_data unit tests" =
    ( module struct
      open Allocation_statistics

      module Float_compare = Float.Robust_compare.Make (struct
        let robust_comparison_tolerance = 0.04
      end)

      type robust_float = float [@@deriving sexp]

      let compare_robust_float = Float_compare.robustly_compare

      (* time_offsets passed in here should be ordered monotonically (to match real world behavior) *)
      let run_test time_offsets expected_quartiles =
        let now = Time.now () in
        (* ids do not need to be unique in this test *)
        let data =
          { allocation_times =
              Queue.of_list
              @@ List.map (List.rev time_offsets) ~f:(fun offset ->
                     (0, Time.sub now (Time.Span.of_ms offset)) )
          ; next_allocation_id = 0
          }
        in
        let stats = compute_statistics data in
        [%test_eq: int] stats.count (List.length time_offsets) ;
        [%test_eq: robust_float] stats.lifetimes.q1 expected_quartiles.q1 ;
        [%test_eq: robust_float] stats.lifetimes.q2 expected_quartiles.q2 ;
        [%test_eq: robust_float] stats.lifetimes.q3 expected_quartiles.q3 ;
        [%test_eq: robust_float] stats.lifetimes.q4 expected_quartiles.q4

      let%test_unit "quartiles of empty list" =
        run_test [] { q1 = 0.0; q2 = 0.0; q3 = 0.0; q4 = 0.0 }

      let%test_unit "quartiles of singleton list" =
        run_test [ 1.0 ] { q1 = 1.0; q2 = 1.0; q3 = 1.0; q4 = 1.0 }

      let%test_unit "quartiles of 2 element list" =
        run_test [ 1.0; 2.0 ] { q1 = 1.0; q2 = 1.5; q3 = 2.0; q4 = 2.0 }

      let%test_unit "quartiles of 3 element list" =
        run_test [ 1.0; 2.0; 3.0 ] { q1 = 1.0; q2 = 2.0; q3 = 3.0; q4 = 3.0 }

      let%test_unit "quartiles of even list (> 3)" =
        run_test
          [ 1.0; 2.0; 3.0; 4.0; 5.0; 6.0 ]
          { q1 = 2.0; q2 = 3.5; q3 = 5.0; q4 = 6.0 }

      let%test_unit "quartiles of odd list with even split (> 3)" =
        run_test
          [ 1.0; 2.0; 3.0; 4.0; 5.0; 6.0; 7.0 ]
          { q1 = 2.0; q2 = 4.0; q3 = 6.0; q4 = 7.0 }

      let%test_unit "quartiles of odd list with odd split (> 3)" =
        run_test
          [ 1.0; 2.0; 3.0; 4.0; 5.0; 6.0; 7.0; 8.0; 9.0 ]
          { q1 = 2.5; q2 = 5.0; q3 = 7.5; q4 = 9.0 }
    end )
end

(** correlation of allocation data and derived statistics *)
module Allocation_info = struct
  type t = { statistics : Allocation_statistics.t; data : Allocation_data.t }
end

let table = String.Table.create ()

let capture object_id =
  let open Allocation_info in
  let info_opt = String.Table.find table object_id in
  let data_opt = Option.map info_opt ~f:(fun { data; _ } -> data) in
  let data =
    Lazy.(
      force
      @@ Option.value_map data_opt
           ~default:(lazy (Allocation_data.create ()))
           ~f:Lazy.return)
  in
  let allocation_id = Allocation_data.register_allocation data in
  let statistics = Allocation_data.compute_statistics data in
  String.Table.set table ~key:object_id ~data:{ data; statistics } ;
  Allocation_statistics.write_metrics statistics object_id ;
  Mina_metrics.(
    Counter.inc_one (Object_lifetime_statistics.allocated_count ~name:object_id)) ;
  allocation_id

(* release is currently O(n), where n = number of active allocations for this object type; this can be improved by implementing indexed queues (with decent random delete computational complexity) in ocaml *)
let release ~object_id ~allocation_id =
  let open Allocation_info in
  let info = String.Table.find_exn table object_id in
  Allocation_data.unregister_allocation info.data allocation_id ;
  let statistics = Allocation_data.compute_statistics info.data in
  String.Table.set table ~key:object_id ~data:{ info with statistics } ;
  Allocation_statistics.write_metrics statistics object_id ;
  Mina_metrics.(
    Counter.inc_one (Object_lifetime_statistics.collected_count ~name:object_id))

let attach_finalizer object_id obj =
  let allocation_id = capture object_id in
  Gc.Expert.add_finalizer_exn obj (fun _ -> release ~object_id ~allocation_id) ;
  obj

let dump () =
  let open Allocation_info in
  let entries =
    String.Table.to_alist table
    |> List.Assoc.map ~f:(fun { statistics; _ } ->
           Allocation_statistics.to_yojson statistics )
  in
  `Assoc entries
