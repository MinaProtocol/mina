open Core

module Sequence_number = struct
  type t = int [@@deriving sexp]
end

module Job_status = struct
  type t = Todo | Done [@@deriving sexp]
end

module Base = struct
  type 'd base =
    | Dummy (*initial dummy values*)
    | Empty
    | Full of {job: 'd; seq_no: Sequence_number.t; status: Job_status.t}
  [@@deriving sexp]

  type 'd t =
    int * 'd base
    (*number of jobs that can be added to this tree, call it "weight" maybe?*)
  [@@deriving sexp]
end

module Merge = struct
  type 'a merge =
    | Dummy (*initial dummy values*)
    | Empty
    | Lcomp of 'a
    | Rcomp of 'a
    | Bcomp of
        { left: 'a
        ; right: 'a
        ; seq_no: Sequence_number.t
        ; status: Job_status.t }
  [@@deriving sexp]

  type 'a t = int * 'a merge (*jobs required*) [@@deriving sexp]
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

  let update :
         ('b, 'c) New_job.t list
      -> update_level:int
      -> sequence_no:int
      -> ('a, 'd) t
      -> ('a, 'd) t =
   fun completed_jobs ~update_level ~sequence_no:seq_no tree ->
    let add_merges jobs cur_level (weight, m) =
      (*match level with
    | 0 -> (*root*)
    | _ ->*)
      (*TODO: assert that the number of jobs is <= weight*)
      Core.printf !"add merges: job count %d\n%!" (List.length jobs) ;
      let reset_weight a =
        match a with
        | 0, Merge.Empty ->
            (*add new weights for the level[level-1] since  those are the next jobs we would be expecting*)
            (Int.pow 2 (update_level - 1 - cur_level), Merge.Empty)
        | _ ->
            a
      in
      if cur_level = update_level - 1 then
        let new_weight, m' =
          match (jobs, m) with
          | [], e ->
              (weight, e)
          | [New_job.Merge a; Merge b], Merge.Empty ->
              ( weight - 2
              , Merge.Bcomp {left= a; right= b; seq_no; status= Job_status.Todo}
              )
          | [Merge a], Empty ->
              (weight - 1, Lcomp a)
          | [Merge b], Lcomp a ->
              ( weight - 1
              , Bcomp {left= a; right= b; seq_no; status= Job_status.Todo} )
          | [Base _], Empty ->
              (weight - 1, Empty)
          | [Base _; Base _], Empty ->
              (weight - 2, Empty)
          | _ ->
              failwith "Invalid merge job (level-1)"
        in
        reset_weight (new_weight, m')
      else if cur_level = update_level then
        match (jobs, m) with
        | [_], Bcomp ({status= Job_status.Todo; _} as x) ->
            (weight - 1, Merge.Bcomp {x with status= Job_status.Done})
        | [], Empty | [], Dummy ->
            (weight, m)
        | _ ->
            failwith "Invalid merge job"
      else if cur_level < update_level - 1 then
        let new_weight = weight - List.length jobs in
        reset_weight (new_weight, m)
      else (weight, m)
    in
    let add_bases jobs (weight, d) =
      (*TODO: assert: jobs here should be a singleton list*)
      Core.printf !"add bases: job count %d\n%!" (List.length jobs) ;
      match (jobs, d) with
      | [], e ->
          (weight, e)
      | [New_job.Base d], Base.Empty ->
          (weight - 1, Base.Full {job= d; seq_no; status= Job_status.Todo})
      | _ ->
          failwith "Invalid base job"
    in
    (*let completed_jobs = List.rev completed_jobs in*)
    let rec go : type a d.
           fa:(('b, 'c) New_job.t list -> int -> a -> a)
        -> fd:(('b, 'c) New_job.t list -> d -> d)
        -> weight_a:(a -> int)
        -> weight_d:(d -> int)
        -> jobs:('b, 'c) New_job.t list
        -> (a, d) t
        -> (a, d) t =
     fun ~fa ~fd ~weight_a ~weight_d ~jobs t ->
      match t with
      | Leaf d ->
          Core.printf
            !"leaf job_count %d weight d %d\n"
            (List.length completed_jobs)
            (weight_d d) ;
          Leaf (fd jobs d)
      | Node {depth; value; sub_tree} ->
          Core.printf
            !"merge job_count %d weight a %d depth%d\n"
            (List.length completed_jobs)
            (weight_a value) depth ;
          let jobs = List.take jobs (weight_a value) in
          let value' = fa jobs depth value in
          Node
            { depth
            ; value= value'
            ; sub_tree=
                go
                  ~fa:(fun _ i (x, y) ->
                    ( fa (List.take jobs (weight_a x)) i x
                    , fa
                        (List.take (List.drop jobs (weight_a x)) (weight_a y))
                        i y ) )
                  ~fd:(fun _ (x, y) ->
                    ( fd (List.take jobs (weight_d x)) x
                    , fd
                        (List.take (List.drop jobs (weight_d x)) (weight_d y))
                        y ) )
                  ~weight_a:(fun (x, _y) -> weight_a x)
                  ~weight_d:(fun (x, _y) -> weight_d x)
                  ~jobs sub_tree }
    in
    go ~fa:add_merges ~fd:add_bases tree ~weight_a:fst ~weight_d:fst
      ~jobs:completed_jobs

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
          | _weight, Base.Full {job; _} ->
              [Available_job.Base job]
          | _ ->
              [] )
        tree
    else
      fold_depth ~init:[] ~f:List.append
        ~fa:(fun i a ->
          if i = level then
            match a with
            | _weight, Merge.Bcomp {left; right; status= Todo; _} ->
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

  let rec view_tree : type a d.
      (a, d) t -> show_a:(a -> string) -> show_d:(d -> string) -> string =
   fun tree ~show_a ~show_d ->
    match tree with
    | Leaf d ->
        sprintf !"Leaf %s\n" (show_d d)
    | Node {value; sub_tree; _} ->
        let curr = sprintf !"Node %s\n" (show_a value) in
        let subtree =
          view_tree sub_tree
            ~show_a:(fun (x, y) -> sprintf !"%s  %s" (show_a x) (show_a y))
            ~show_d:(fun (x, y) -> sprintf !"%s  %s" (show_d x) (show_d y))
        in
        curr ^ subtree
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

let create_tree_for_level ~level ~depth ~merge ~base =
  let rec go : type a d. int -> (int -> a) -> d -> (a, d) Tree.t =
   fun d fmerge base ->
    if d >= depth then Leaf base
    else
      let sub_tree = go (d + 1) (fun i -> (fmerge i, fmerge i)) (base, base) in
      Node {depth= d; value= fmerge d; sub_tree}
  in
  let base_weight = if level = -1 then 0 else 1 in
  go 0
    (fun d ->
      let weight = if level = -1 then 0 else Int.pow 2 level / Int.pow 2 d in
      (weight, merge) )
    (base_weight, base)

let create_tree ~depth =
  create_tree_for_level ~level:depth ~depth ~merge:Merge.Empty ~base:Base.Empty

let create : max_base_jobs:int -> delay:int -> ('a, 'd) t =
 fun ~max_base_jobs ~delay ->
  let depth = Int.ceil_log2 max_base_jobs in
  let new_tree = create_tree_for_level ~depth in
  let trees =
    List.map
      (List.init ((Int.ceil_log2 max_base_jobs + 1) * (delay + 1)) ~f:Fn.id)
      ~f:(fun _ ->
        new_tree ~level:(-1) ~merge:Merge.Dummy ~base:Base.Dummy
        (*depth -(i/(delay+1))*) )
  in
  let next_tree = create_tree ~depth in
  { trees= next_tree :: trees
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

let update : type a d.
    data:d list -> completed_jobs:a list -> (a, d) t -> (a, d) t =
 fun ~data ~completed_jobs t ->
  assert (List.length data <= t.max_base_jobs) ;
  assert (List.length completed_jobs <= (2 * t.max_base_jobs) - 1) ;
  let delay = t.delay + 1 in
  let depth = Int.ceil_log2 t.max_base_jobs in
  let new_base_jobs = List.map data ~f:(fun j -> New_job.Base j) in
  let new_merge_jobs = List.map completed_jobs ~f:(fun j -> New_job.Merge j) in
  let jobs_required = function
    | Tree.Node {value; _} ->
        fst value
    | Leaf _ ->
        1
  in
  let next_seq = t.curr_job_seq_no + 1 in
  Core.printf !"adding new merges \n%!" ;
  let updated_trees_merge, _remaining_merge_jobs =
    List.foldi (List.tl_exn t.trees) ~init:([], new_merge_jobs)
      ~f:(fun i (trees, jobs) tree ->
        if i % delay = delay - 1 then
          let tree' =
            Tree.update
              (List.take jobs (jobs_required tree))
              ~update_level:(depth - (i / delay))
              ~sequence_no:next_seq tree
          in
          (tree' :: trees, List.drop jobs (jobs_required tree))
        else (tree :: trees, jobs) )
  in
  Core.printf !"adding new bases \n%!" ;
  let updated_trees_base =
    Tree.update new_base_jobs ~update_level:depth ~sequence_no:next_seq
      (List.hd_exn t.trees)
  in
  { t with
    trees= updated_trees_base :: List.rev updated_trees_merge
  ; curr_job_seq_no= next_seq }

let%test_unit "test tree" =
  let t : (int, int) t = create ~max_base_jobs:4 ~delay:2 in
  Core.printf !"tree %{sexp: (int, int) t}\n %!" t ;
  let trees' : (int Merge.t, int Base.t) Tree.t list =
    List.mapi
      ~f:(fun j tree ->
        Tree.map_depth
          ~fa:(fun i _ ->
            ( Int.pow 2 i
            , Merge.Bcomp
                {left= i; right= j; seq_no= 0; status= Job_status.Todo} ) )
          ~fd:(fun _ ->
            (1, Base.Full {job= j; seq_no= 1; status= Job_status.Todo}) )
          tree )
      t.trees
  in
  Core.printf
    !"tree %{sexp: (int Merge.t, int Base.t) Tree.t list}\n\n %!"
    trees' ;
  let sum =
    Tree.fold (List.hd_exn trees') ~init:0 ~f:( + )
      ~fd:(fun x ->
        match x with
        | _, Base.Empty | _, Base.Dummy ->
            0
        | _, Full {job; _} ->
            job )
      ~fa:(fun m ->
        match m with
        | _, Merge.Empty | _, Dummy ->
            0
        | _, Lcomp a | _, Rcomp a ->
            a
        | _, Bcomp {left; right; _} ->
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

let view_int_trees (tree : (int Merge.t, int Base.t) Tree.t) =
  let show_status = function Job_status.Done -> "D" | Todo -> "T" in
  let show_a a =
    match snd a with
    | Merge.Bcomp {seq_no; status; _} ->
        sprintf "(Bo %d %s)" seq_no (show_status status)
    | Lcomp _ ->
        "L"
    | Rcomp _ ->
        "R"
    | Empty ->
        "E"
    | Dummy ->
        "D"
  in
  let show_d d =
    match snd d with
    | Base.Dummy ->
        "D"
    | Base.Empty ->
        "E"
    | Base.Full {seq_no; status; _} ->
        sprintf "(Ba %d %s)" seq_no (show_status status)
  in
  Tree.view_tree tree ~show_a ~show_d

let%test_unit "test tree" =
  let t : (int, int) t = create ~max_base_jobs:8 ~delay:1 in
  Core.printf !"init tree %{sexp: (int, int) t}\n %!" t ;
  Core.printf !"trees\n%s\n%!"
    (String.concat (List.map t.trees ~f:view_int_trees)) ;
  let _t' =
    List.fold ~init:t (List.init 10 ~f:Fn.id) ~f:(fun t' _ ->
        let data = List.init 8 ~f:Fn.id in
        let work = work_for_current_tree t' in
        let new_merges =
          List.map work ~f:(fun job ->
              match job with Base i -> i | Merge (i, j) -> i + j )
        in
        let t' = update ~data ~completed_jobs:new_merges t' in
        Core.printf !"tree %{sexp: (int, int) t}\n %!" t' ;
        Core.printf !"trees\n%s\n%!"
          (String.concat ~sep:"\n" (List.map t'.trees ~f:view_int_trees)) ;
        t' )
  in
  ()
