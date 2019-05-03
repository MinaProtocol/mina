open Core

module Sequence_number = struct
  type t = int [@@deriving sexp]
end

module Job_status = struct
  type t = Todo | Done [@@deriving sexp]
end

module Base = struct
  type 'd t =
    | Empty
    | Full of {job: 'd; seq_no: Sequence_number.t; status: Job_status.t}
  [@@deriving sexp]
end

module Merge = struct
  type 'a t =
    | Empty
    | Lcomp of 'a
    | Rcomp of 'a
    | Bcomp of
        { left: 'a
        ; right: 'a
        ; seq_no: Sequence_number.t
        ; status: Job_status.t }
  [@@deriving sexp]
end

(*All Todo jobs*)
module Available_job = struct
  type ('a, 'd) t = Base of 'd | Merge of 'a * 'a [@@deriving sexp]
end

(*New jobs to be added*)
module New_job = struct
  type ('a, 'd) t = Base of 'd | Merge of 'a [@@deriving sexp]
end

module Tree = struct
  type ('a, 'd) t =
    | Leaf of 'd
    | Node of {depth: int; value: 'a; sub_tree: ('a * 'a, 'd * 'd) t}
  [@@deriving sexp]

  let rec map_depth : type a b c d.
      fa:(int -> a -> b) -> fd:(d -> c) -> (a, d) t -> (b, c) t =
   fun ~fa ~fd tree ->
    match tree with
    | Leaf d ->
        Leaf (fd d)
    | Node {depth; value; sub_tree} ->
        Node
          { depth
          ; value= fa depth value
          ; sub_tree=
              map_depth
                ~fa:(fun i (x, y) -> (fa i x, fa i y))
                ~fd:(fun (x, y) -> (fd x, fd y))
                sub_tree }

  let update_level :
         ('b, 'c) New_job.t list
      -> level:int
      -> sequence_no:int
      -> ('a, 'd) t
      -> ('a, 'd) t =
   fun completed_jobs ~level ~sequence_no:seq_no tree ->
    let add_merges jobs cur_depth cur_job =
      (*match level with
    | 0 -> (*root*)
    | _ ->*)
      if cur_depth = level - 1 then
        match (jobs, cur_job) with
        | [], e ->
            e
        | New_job.Merge a :: Merge b :: _, Merge.Empty ->
            Merge.Bcomp {left= a; right= b; seq_no; status= Job_status.Todo}
        | Merge b :: _, Lcomp a ->
            Bcomp {left= a; right= b; seq_no; status= Job_status.Todo}
        | [Merge a], Empty ->
            Lcomp a
        | _ ->
            failwith "Invalid job"
      else cur_job
    in
    let add_bases jobs cur_job =
      match (jobs, cur_job) with
      | [], e ->
          e
      | New_job.Base d :: _, Base.Empty ->
          Base.Full {job= d; seq_no; status= Job_status.Todo}
      | _ ->
          failwith "Invalid job"
    in
    let right_jobs jobs depth = List.take jobs (Int.pow 2 depth) in
    let left_jobs jobs depth = List.drop jobs (Int.pow 2 depth) in
    let completed_jobs = List.rev completed_jobs in
    let rec go : type a d.
           fa:(('b, 'c) New_job.t list -> int -> a -> a)
        -> fd:(('b, 'c) New_job.t list -> d -> d)
        -> (a, d) t
        -> (a, d) t =
     fun ~fa ~fd t ->
      match t with
      | Leaf d ->
          Leaf (fd completed_jobs d)
      | Node {depth; value; sub_tree} ->
          let value' = fa completed_jobs depth value in
          Node
            { depth
            ; value= value'
            ; sub_tree=
                go
                  ~fa:(fun jobs i (a, b) ->
                    ( fa (left_jobs jobs depth) i a
                    , fa (right_jobs jobs depth) i b ) )
                  ~fd:(fun jobs (x, y) ->
                    (fd (left_jobs jobs depth) x, fd (right_jobs jobs depth) y)
                    )
                  sub_tree }
    in
    go ~fa:add_merges ~fd:add_bases tree

  let map : type a b c d. fa:(a -> b) -> fd:(d -> c) -> (a, d) t -> (b, c) t =
   fun ~fa ~fd tree -> map_depth tree ~fd ~fa:(fun _ -> fa)

  let rec fold_depth : type a c d.
         fa:(int -> a -> c)
      -> fd:(d -> c)
      -> f:(c -> c -> c)
      -> init:c
      -> (a, d) t
      -> c =
   fun ~fa ~fd ~f ~init:acc t ->
    match t with
    | Leaf d ->
        f acc (fd d)
    | Node {depth; value; sub_tree} ->
        let acc' =
          fold_depth ~f
            ~fa:(fun i (x, y) -> f (fa i x) (fa i y))
            ~fd:(fun (x, y) -> f (fd x) (fd y))
            ~init:acc sub_tree
        in
        f acc' (fa depth value)

  let fold : type a c d.
      fa:(a -> c) -> fd:(d -> c) -> f:(c -> c -> c) -> init:c -> (a, d) t -> c
      =
   fun ~fa ~fd ~f ~init t -> fold_depth t ~init ~fa:(fun _ -> fa) ~fd ~f

  (*TODO:update a layer |> map multiple trees; Think about how this can be done with all new trees (feels like that is going to be easier)*)

  let jobs_on_level :
      depth:int -> level:int -> ('a, 'd) t -> ('b, 'c) Available_job.t list =
   fun ~depth ~level tree ->
    if level = depth then
      fold ~init:[] ~f:List.append
        ~fa:(fun _ -> [])
        ~fd:(fun d ->
          match d with
          | Base.Empty ->
              []
          | Full {job; _} ->
              [Available_job.Base job] )
        tree
    else
      fold_depth ~init:[] ~f:List.append
        ~fa:(fun i a ->
          if i = level then
            match a with
            | Merge.Bcomp {left; right; status= Todo; _} ->
                [Available_job.Merge (left, right)]
            | _ ->
                []
          else [] )
        ~fd:(fun _ -> [])
        tree

  (*TODO: valid the struture after each operation*)
  (*let complete_job_on_level : type a d. depth:int -> level:int -> (a, d) tree -> (a, d) tree option = 
  fun ~depth ~level tree ->
  let updated_tree = 
    if level = depth then 
      map_depth
        ~fa:(fun i a -> if i = (level -1) then   )
        ~fd:(fun d -> [Job.Base d])
        tree
    else
      foldi ~init:[] ~f:List.append
        ~fa:(fun i a -> if i=level then [Job.Merge a] else [])
        ~fd:(fun _ -> [])
        tree*)

  let of_data : type a d. d list -> (a, d) t =
   fun _ -> failwith "create a perfect tree with empty merge nodes"

  let to_data : ('a, 'd) t -> int -> ('b, 'c) Available_job.t list =
   fun tree max_base_jobs ->
    let depth = Int.ceil_log2 max_base_jobs + 1 in
    jobs_on_level ~level:depth ~depth tree
end

(*This struture works well because we always complete all the nodes on a specific level before proceeding to the next level*)

type ('a, 'd) t =
  { trees: ('a Merge.t, 'd Base.t) Tree.t list (*use non empty list*)
  ; acc: (int * ('a * 'd list)) option
        (*last emitted proof and the corresponding transactions*)
  ; next_base_pos: int
        (*All new base jobs will start from the first tree in the list*)
  ; recent_tree_data: 'd list
  ; other_trees_data: 'd list list
        (*Keeping track of all the transactions corresponding to a proof returned*)
  ; curr_job_seq_no: int (*Sequence number for the jobs added every block*)
  ; max_base_jobs: int (*transaction_capacity_log_2*)
  ; delay: int }
[@@deriving sexp]

let create : max_base_jobs:int -> delay:int -> ('a, 'd) t =
 fun ~max_base_jobs ~delay ->
  let build_tree =
    let rec go : type a d. int -> a -> d -> (a, d) Tree.t =
     fun depth merge base ->
      if depth >= Int.ceil_log2 max_base_jobs then Leaf base
      else
        let sub_tree = go (depth + 1) (merge, merge) (base, base) in
        Node {depth; value= merge; sub_tree}
    in
    go 0 Merge.Empty Base.Empty
  in
  let trees =
    List.map
      (List.init
         (((Int.ceil_log2 max_base_jobs + 1) * (delay + 1)) + 1)
         ~f:Fn.id)
      ~f:(fun _ -> build_tree)
  in
  { trees
  ; acc= None
  ; next_base_pos= 0
  ; recent_tree_data= []
  ; other_trees_data= []
  ; curr_job_seq_no= 0
  ; max_base_jobs
  ; delay }

(*let rec pair_to_list : type a. a list -> ('b*'b) -> ('b -> a) -> a list= 
  fun lst p f ->
  match p with 
    | None, None -> lst
    | (Some x, Some y) -> (f (Some y)) :: (f (Some x)) :: lst
    | (x,y) -> (pair_to_list [] x f) @ (pair_to_list [] y f) @ lst

let rec leaves : type a d. (a, d) tree -> d = fun tree ->
 match tree with
  | Base x -> x
  | Merge (_, rest) -> leaves rest*)

let work_to_do : ('a, 'd) Tree.t list -> int -> ('b, 'c) Available_job.t list =
 fun trees max_base_jobs ->
  let depth = Int.ceil_log2 max_base_jobs in
  (*let work_trees = List.take (List.filteri trees ~f:(fun i _ -> Core.printf !"%d mod %d = %d\n%!" i delay (i%delay); i % delay = delay-1)) (depth+1) in*)
  assert (List.length trees = depth + 1) ;
  List.concat_mapi trees ~f:(fun i tree ->
      Tree.jobs_on_level ~depth ~level:(depth - i) tree )

(*let to_list : type a d. (a, d) t -> (a, d) Available_job.t list =
   fun t ->
    List.concat_map t.trees ~f:(fun tree ->
        Tree.fold ~init:[] ~f:List.append
          ~fa:(fun a -> [Available_job.Merge a])
          ~fd:(fun d -> [Available_job.Base d])
          tree )*)

let all_work : type a d. (a, d) t -> (a, d) Available_job.t list =
 fun t ->
  let depth = Int.ceil_log2 t.max_base_jobs in
  let rec go trees work_list delay =
    if List.length trees = depth + 1 then
      let work = work_to_do trees t.max_base_jobs |> List.rev in
      work @ work_list
    else
      let work_trees =
        List.take
          (List.filteri trees ~f:(fun i _ -> i % delay = delay - 1))
          (depth + 1)
      in
      let work = work_to_do work_trees t.max_base_jobs |> List.rev in
      let remaining_trees =
        List.filteri trees ~f:(fun i _ -> i % delay <> delay - 1)
      in
      go remaining_trees (work @ work_list) (max 2 (delay - 1))
  in
  let work_list = go (List.tl_exn t.trees) [] (t.delay + 1) in
  let current_leaves = Tree.to_data (List.hd_exn t.trees) t.max_base_jobs in
  List.rev_append work_list current_leaves

let work_for_current_tree : type a d. (a, d) t -> (a, d) Available_job.t list =
 fun t ->
  let delay = t.delay + 1 in
  let depth = Int.ceil_log2 t.max_base_jobs in
  let work_trees =
    List.take
      (List.filteri (List.tl_exn t.trees) ~f:(fun i _ -> i % delay = delay - 1))
      (depth + 1)
  in
  work_to_do work_trees t.max_base_jobs

(*let add_work : type a d. (a, d) t -> (a merge, d base) Available_job.t list *)
(*let add_data ~data state = 
  if List.length data > state.max_base_jobs then Or_error.error_string "data exceeded the max length"
  else*)

let%test_unit "test tree" =
  let t : (int, int) t = create ~max_base_jobs:4 ~delay:2 in
  Core.printf !"tree %{sexp: (int, int) t}\n %!" t ;
  let trees' : (int Merge.t, int Base.t) Tree.t list =
    List.mapi
      ~f:(fun j tree ->
        Tree.map_depth
          ~fa:(fun i _ -> Merge.Lcomp (i + j))
          ~fd:(fun _ -> Base.Full {job= j; seq_no= 1; status= Job_status.Todo})
          tree )
      t.trees
  in
  Core.printf
    !"tree %{sexp: (int Merge.t, int Base.t) Tree.t list}\n\n %!"
    trees' ;
  let sum =
    Tree.fold (List.hd_exn trees') ~init:0 ~f:( + )
      ~fd:(fun x -> match x with Base.Empty -> 0 | Full {job; _} -> job)
      ~fa:(fun m ->
        match m with
        | Merge.Empty ->
            0
        | Lcomp a | Rcomp a ->
            a
        | Bcomp {left; right; _} ->
            left + right )
  in
  Core.printf !"sum %{sexp: int}\n %!" sum ;
  let t' : (int, int) t = {t with trees= trees'} in
  let job_list = all_work t' in
  Core.printf
    !"all jobs %{sexp: (int, int) Available_job.t list}\n\n %!"
    job_list ;
  let job_list = work_for_current_tree t' in
  Core.printf
    !"for current tree %{sexp: (int, int) Available_job.t list}\n\n %!"
    job_list ;
  ()
