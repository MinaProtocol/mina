(* The pending coinbase structure can be laid out as a ring of exactly
   [max_trees] stacks, one per scan state tree, with a single [current]
   pointer. This relies on the following properties of the scan state, which
   these tests check by driving a model ring alongside a real scan state:

   - a proof is only emitted when the scan state holds [max_trees] trees, and
     the emitted tree is always the oldest, at ring slot [current + 1];
   - a new tree is only allocated into a slot that is already empty, either
     because it was never used (before the scan state first fills) or because
     its tree has already emitted;
   - pops and allocations are independent events: a proof may be emitted in a
     block that does not fill the current tree, and a tree may be allocated in
     a block that emits no proof.
*)

open Core_kernel
open Parallel_scan

let job_done (job : (int, int) Available_job.t) : int =
  match job with Base i -> i | Merge (i, j) -> i + j

(* Work is bought in bundles of at most two jobs, grouped within each tree's
   job list, and a block's bundles are always a prefix of the bundles for the
   next update. *)
let work_bundles state =
  List.concat_map (jobs_for_next_update state) ~f:(fun jobs ->
      List.chunks_of jobs ~length:2 )

type slot = Empty | Stack of int list

type ring = { slots : slot array; mutable current : int }

let ring_create ~size =
  let slots = Array.create ~len:size Empty in
  slots.(0) <- Stack [] ; { slots; current = 0 }

let ring_next ring i = (i + 1) mod Array.length ring.slots

(* The occupied slots, oldest first, starting just after [current]. *)
let ring_trees ring =
  let size = Array.length ring.slots in
  List.filter_map
    (List.init size ~f:(fun i -> ring.slots.((ring.current + 1 + i) mod size)))
    ~f:(function Empty -> None | Stack data -> Some data)

type counts =
  { mutable pops_with_advance : int
  ; mutable pops_without_advance : int
  ; mutable advances_without_pop_after_fill : int
  }

let counts =
  { pops_with_advance = 0
  ; pops_without_advance = 0
  ; advances_without_pop_after_fill = 0
  }

type mode = Full_throughput | Required_work | Eager_work | Random_work

let mode_of_int i =
  match i mod 4 with
  | 0 ->
      Full_throughput
  | 1 ->
      Required_work
  | 2 ->
      Eager_work
  | _ ->
      Random_work

(* Candidate [(data_count, jobs)] choices for a block, most interesting first.
   A block that bought less than [jobs_for_slots] worth of work in the past can
   leave later blocks needing more than [jobs_for_slots] to free a tree, so the
   fallbacks mirror a block producer's: buy all available work, then include
   fewer transactions. The last candidate, an empty block, is always
   accepted. *)
let candidates state ~max_base_jobs (mode, a, b) =
  let bundles = work_bundles state in
  let required data_count =
    List.concat (jobs_for_slots state ~slots:data_count)
  in
  let take k = List.concat (List.take bundles k) in
  let data_count =
    match mode with
    | Full_throughput ->
        max_base_jobs
    | Required_work | Eager_work | Random_work ->
        a mod (max_base_jobs + 1)
  in
  let preferred =
    match mode with
    | Full_throughput | Required_work ->
        []
    | Eager_work ->
        [ (data_count, take (List.length bundles)) ]
    | Random_work ->
        [ (data_count, take (b mod (List.length bundles + 1))) ]
  in
  let all_work = take (List.length bundles) in
  preferred
  @ [ (data_count, required data_count) ]
  @ List.init (data_count + 1) ~f:(fun i -> (data_count - i, all_work))
  @ [ (0, []) ]

let run ~max_base_jobs ~delay steps =
  let size = max_trees (empty ~max_base_jobs ~delay) in
  let ring = ring_create ~size in
  let next_data = ref 0 in
  let filled_once = ref false in
  let apply state (data_count, jobs) =
    let data = List.init data_count ~f:(fun i -> !next_data + i) in
    Result.ok (update ~data ~completed_jobs:(List.map jobs ~f:job_done) state)
    |> Option.map ~f:(fun res -> (data, res))
  in
  let (_ : (int, int) State.t) =
    List.fold steps ~init:(empty ~max_base_jobs ~delay) ~f:(fun state step ->
        let trees_before = List.length (pending_data state) in
        let current_space = fst (partition_if_overflowing state).first in
        let data, (emitted, state') =
          List.find_map_exn
            (candidates state ~max_base_jobs step)
            ~f:(apply state)
        in
        next_data := !next_data + List.length data ;
        let advance = List.length data >= current_space in
        (* Pop. *)
        Option.iter emitted ~f:(fun (_, emitted_data) ->
            [%test_eq: int] trees_before size ;
            let oldest = ring_next ring ring.current in
            ( match ring.slots.(oldest) with
            | Stack popped ->
                [%test_eq: int list] popped emitted_data
            | Empty ->
                failwith "proof emitted for an empty ring slot" ) ;
            ring.slots.(oldest) <- Empty ;
            if advance then
              counts.pops_with_advance <- counts.pops_with_advance + 1
            else counts.pops_without_advance <- counts.pops_without_advance + 1 ) ;
        if trees_before = size then filled_once := true ;
        (* Fill the current tree, then allocate the next one. *)
        let data1, data2 = List.split_n data current_space in
        ( match ring.slots.(ring.current) with
        | Stack existing ->
            ring.slots.(ring.current) <- Stack (existing @ data1)
        | Empty ->
            failwith "current ring slot is empty" ) ;
        if advance then (
          let next = ring_next ring ring.current in
          ( match ring.slots.(next) with
          | Empty ->
              ()
          | Stack _ ->
              failwith "tree allocated into an occupied ring slot" ) ;
          ring.slots.(next) <- Stack data2 ;
          ring.current <- next ;
          if Option.is_none emitted && !filled_once then
            counts.advances_without_pop_after_fill <-
              counts.advances_without_pop_after_fill + 1 ) ;
        [%test_eq: int list list] (ring_trees ring) (pending_data state') ;
        state' )
  in
  ()

let step_gen =
  Quickcheck.Generator.(
    tuple3
      (map (Int.gen_incl 0 3) ~f:mode_of_int)
      (Int.gen_incl 0 1000) (Int.gen_incl 0 1000))

(* A run uses a single mode for most of its blocks, so that long stretches of
   e.g. eager work actually occur, with occasional blocks of other modes. *)
let steps_gen ~length =
  let open Quickcheck.Generator.Let_syntax in
  let%bind base_mode = Int.gen_incl 0 3 >>| mode_of_int in
  let%map steps =
    Quickcheck.Generator.list_with_length length
      (let%map mode, a, b = step_gen and switch = Int.gen_incl 0 9 in
       ((if switch = 0 then mode else base_mode), a, b) )
  in
  steps

let%test_module "pending coinbase ring invariants" =
  ( module struct
    let%test_unit "scan state trees map onto a ring of max_trees slots" =
      Quickcheck.test ~trials:200
        Quickcheck.Generator.(
          tuple3 (Int.gen_incl 0 3) (Int.gen_incl 0 2) (steps_gen ~length:300))
        ~f:(fun (log2, delay, steps) ->
          run ~max_base_jobs:(Int.pow 2 log2) ~delay steps ) ;
      (* The ring design depends on pops and allocations being separable, so
         make sure both orders were exercised. *)
      assert (counts.pops_with_advance > 0) ;
      assert (counts.pops_without_advance > 0) ;
      assert (counts.advances_without_pop_after_fill > 0)
  end )
