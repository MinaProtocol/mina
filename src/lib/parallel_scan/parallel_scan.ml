open Core_kernel

module Sequence_no = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = int [@@deriving sexp, bin_io, version]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp]
end

module Sequence_number = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = int [@@deriving sexp, bin_io, version]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp]
end

(*Each node on the tree is viewed as a job that needs to be completed. When a job is completed, it creates a new "Todo" job and marks the old job as "Done"*)
module Job_status = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Todo | Done [@@deriving sexp, bin_io, version]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t = Todo | Done [@@deriving sexp]

  let to_string = function Todo -> "Todo" | Done -> "Done"
end

(*number of jobs that can be added to this tree. This number corresponding to a specific level of the tree. New jobs received is distributed across the tree based on this number. *)
module Weight = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = int [@@deriving sexp, bin_io, version]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp]
end

(*Base Job: Proving new transactions*)
module Base = struct
  module Job = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type 'd t =
            | Empty
            | Full of
                { job: 'd
                ; seq_no: Sequence_number.Stable.V1.t
                ; status: Job_status.Stable.V1.t }
          [@@deriving sexp, bin_io, version]
        end

        include T
      end

      module Latest = V1
    end

    type 'd t = 'd Stable.Latest.t =
      | Empty
      | Full of
          { job: 'd
          ; seq_no: Sequence_number.Stable.V1.t
          ; status: Job_status.Stable.V1.t }
    [@@deriving sexp]
  end

  module Stable = struct
    module V1 = struct
      module T = struct
        type 'd t = Weight.Stable.V1.t * 'd Job.Stable.V1.t
        [@@deriving sexp, bin_io, version]
      end

      include T
    end

    module Latest = V1
  end

  type 'd t = 'd Stable.Latest.t [@@deriving sexp]
end

(* Merge Job: Merging two proofs*)
module Merge = struct
  module Job = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type 'a t =
            | Empty
            | Part of 'a (*Only the left component of the job is available yet since we always complete the jobs from left to right*)
            | Full of
                { left: 'a
                ; right: 'a
                ; seq_no: Sequence_number.Stable.V1.t
                      (*Update no, for debugging*)
                ; status: Job_status.Stable.V1.t }
          [@@deriving sexp, bin_io, version]
        end

        include T
      end

      module Latest = V1
    end

    type 'a t = 'a Stable.Latest.t =
      | Empty
      | Part of 'a
      | Full of
          { left: 'a
          ; right: 'a
          ; seq_no: Sequence_number.Stable.V1.t
          ; status: Job_status.Stable.V1.t }
    [@@deriving sexp]
  end

  module Stable = struct
    module V1 = struct
      module T = struct
        type 'a t =
          (Weight.Stable.V1.t * Weight.Stable.V1.t) * 'a Job.Stable.V1.t
        [@@deriving sexp, bin_io, version]
      end

      include T
    end

    module Latest = V1
  end

  type 'a t = 'a Stable.Latest.t [@@deriving sexp]
end

(*All the jobs on a tree that can be done. Base.Full and Merge.Bcomp*)
module Available_job = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('a, 'd) t = Base of 'd | Merge of 'a * 'a [@@deriving sexp]
      end

      include T
    end

    module Latest = V1
  end

  type ('a, 'd) t = ('a, 'd) Stable.Latest.t = Base of 'd | Merge of 'a * 'a
  [@@deriving sexp]
end

(*New jobs to be added (including new transactions or new merge jobs)*)
module New_job = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('a, 'd) t = Base of 'd | Merge of 'a [@@deriving sexp]
      end

      include T
    end

    module Latest = V1
  end

  type ('a, 'd) t = ('a, 'd) Stable.Latest.t = Base of 'd | Merge of 'a
  [@@deriving sexp]
end

(*Space available and number of jobs required to enqueue data*)
module Space_partition = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = {first: int * int; second: (int * int) option}
        [@@deriving sexp, bin_io, version]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t = {first: int * int; second: (int * int) option}
  [@@deriving sexp]
end

module Job_view = struct
  module Node = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type 'a t = Base of 'a option | Merge of 'a option * 'a option
          [@@deriving sexp, bin_io, version]
        end

        include T
      end

      module Latest = V1
    end

    type 'a t = 'a Stable.Latest.t =
      | Base of 'a option
      | Merge of 'a option * 'a option
    [@@deriving sexp]
  end

  module Stable = struct
    module V1 = struct
      module T = struct
        type 'a t =
          { position: int
          ; seq_no: Sequence_number.Stable.V1.t
          ; status: Job_status.Stable.V1.t
          ; value: 'a Node.Stable.V1.t }
        [@@deriving sexp, bin_io, version]
      end

      include T
    end

    module Latest = V1
  end

  type 'a t = 'a Stable.Latest.t [@@deriving sexp]
end

module Hash = struct
  type t = Digestif.SHA256.t
end

module Tree = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('a, 'd) t =
          | Leaf of 'd
          | Node of {depth: int; value: 'a; sub_tree: ('a * 'a, 'd * 'd) t}
        [@@deriving sexp, bin_io, version]
      end

      include T
    end

    module Latest = V1
  end

  type ('a, 'd) t = ('a, 'd) Stable.Latest.t =
    | Leaf of 'd
    | Node of {depth: int; value: 'a; sub_tree: ('a * 'a, 'd * 'd) t}
  [@@deriving sexp]

  (*Eg: Tree depth = 3

    Node M
    |
    Node (M,M)
    |
    Node ((M,M),(M,M))
    |
    Leaf (((B,B),(B,B)),((B,B),(B,B))) 
   *)

  (*mapi where i is the level of the tree*)
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

  let map : type a b c d. fa:(a -> b) -> fd:(d -> c) -> (a, d) t -> (b, c) t =
   fun ~fa ~fd tree -> map_depth tree ~fd ~fa:(fun _ -> fa)

  (* foldi where i is the cur_level*)
  module Make_foldable (M : Monad.S) = struct
    let rec fold_depth_until' : type a c d e.
           fa:(int -> c -> a -> (c, e) Continue_or_stop.t M.t)
        -> fd:(c -> d -> (c, e) Continue_or_stop.t M.t)
        -> init:c
        -> (a, d) t
        -> (c, e) Continue_or_stop.t M.t =
     fun ~fa ~fd ~init:acc t ->
      let open Container.Continue_or_stop in
      let open M.Let_syntax in
      match t with
      | Leaf d ->
          fd acc d
      | Node {depth; value; sub_tree} -> (
          match%bind fa depth acc value with
          | Continue acc' ->
              fold_depth_until'
                ~fa:(fun i acc (x, y) ->
                  match%bind fa i acc x with
                  | Continue r ->
                      fa i r y
                  | x ->
                      M.return x )
                ~fd:(fun acc (x, y) ->
                  match%bind fd acc x with
                  | Continue r ->
                      fd r y
                  | x ->
                      M.return x )
                ~init:acc' sub_tree
          | x ->
              M.return x )

    let fold_depth_until : type a c d e.
           fa:(int -> c -> a -> (c, e) Continue_or_stop.t M.t)
        -> fd:(c -> d -> (c, e) Continue_or_stop.t M.t)
        -> init:c
        -> finish:(c -> e M.t)
        -> (a, d) t
        -> e M.t =
     fun ~fa ~fd ~init ~finish t ->
      let open M.Let_syntax in
      match%bind fold_depth_until' ~fa ~fd ~init t with
      | Continue result ->
          finish result
      | Stop e ->
          M.return e
  end

  module Foldable_ident = Make_foldable (Monad.Ident)

  let fold_depth : type a c d.
      fa:(int -> c -> a -> c) -> fd:(c -> d -> c) -> init:c -> (a, d) t -> c =
   fun ~fa ~fd ~init t ->
    Foldable_ident.fold_depth_until
      ~fa:(fun i acc a -> Continue (fa i acc a))
      ~fd:(fun acc d -> Continue (fd acc d))
      ~init ~finish:Fn.id t

  let fold : type a c d.
      fa:(c -> a -> c) -> fd:(c -> d -> c) -> init:c -> (a, d) t -> c =
   fun ~fa ~fd ~init t -> fold_depth t ~init ~fa:(fun _ -> fa) ~fd

  let fold_until : type a c d e.
         fa:(c -> a -> (c, e) Continue_or_stop.t)
      -> fd:(c -> d -> (c, e) Continue_or_stop.t)
      -> init:c
      -> finish:(c -> e)
      -> (a, d) t
      -> e =
   fun ~fa ~fd ~init ~finish t ->
    Foldable_ident.fold_depth_until ~fa:(fun _ -> fa) ~fd ~init ~finish t

  (*List of things that map to a specific level on the tree*)
  module Data_list = struct
    module T = struct
      type 'a t = Single of 'a | Double of ('a * 'a) t [@@deriving sexp]
    end

    type ('a, 'b) tree = ('a, 'b) t

    include T

    let rec split : type a. a t -> (a -> a * a) -> (a * a) t =
     fun lst f ->
      match lst with
      | Single a ->
          Single (f a)
      | Double t ->
          let sub = split t (fun (x, y) -> (f x, f y)) in
          Double sub

    let rec merge : type a. a t -> a t -> (a * a) t =
     fun lst1 lst2 ->
      match (lst1, lst2) with
      | Single a, Single b ->
          Single (a, b)
      | Double a, Double b ->
          Double (merge a b)
      | _ ->
          failwith "Cannot merge the two data lists"

    let rec fold : type a b. a t -> f:(b -> a -> b) -> init:b -> b =
     fun t ~f ~init ->
      match t with
      | Single a ->
          f init a
      | Double a ->
          fold a ~f:(fun acc (a, b) -> f (f acc a) b) ~init

    let rec of_tree : type a b c d.
           c t
        -> (a, d) tree
        -> weight_a:(a -> b * b)
        -> weight_d:(d -> b * b)
        -> f_split:(b * b -> c -> c * c)
        -> on_level:int
        -> c t =
     fun job_list tree ~weight_a ~weight_d ~f_split ~on_level ->
      match tree with
      | Node {depth; value; sub_tree} ->
          if depth = on_level then job_list
          else
            let l, r = weight_a value in
            let new_job_list = split job_list (f_split (l, r)) in
            Double
              (of_tree new_job_list sub_tree
                 ~weight_a:(fun (a, b) -> (weight_a a, weight_a b))
                 ~weight_d:(fun (a, b) -> (weight_d a, weight_d b))
                 ~f_split:(fun ((x1, y1), (x2, y2)) (a, b) ->
                   (f_split (x1, y1) a, f_split (x2, y2) b) )
                 ~on_level)
      | Leaf b ->
          Double (split job_list (f_split (weight_d b)))

    let of_list_and_tree lst tree on_level =
      of_tree (Single lst) tree ~weight_a:fst
        ~weight_d:(fun d -> (fst d, 0))
        ~f_split:(fun (l, r) a -> (List.take a l, List.take (List.drop a l) r))
        ~on_level

    (*Just the nested data*)
    let to_data : type a. a t -> a =
     fun t ->
      let rec go : type a. a t -> a * a =
       fun data_list ->
        match data_list with Single a -> (a, a) | Double js -> fst (go js)
      in
      fst @@ go t
  end

  (*
    a -> 'a Merge.t
    b -> New_job.t Data_list.t
    c -> weight
    d -> 'd Base.t
    e -> 'a (final proof)
    fa, fb are to update the nodes with new jobs and mark old jobs to "Done"*)
  let rec update_split : type a b c d e.
         fa:(b -> int -> a -> a * e option)
      -> fd:(b -> d -> d)
      -> weight_a:(a -> c * c)
      -> jobs:b Data_list.t
      -> jobs_split:(c * c -> b -> b * b)
      -> (a, d) t
      -> (a, d) t * e option =
   fun ~fa ~fd ~weight_a ~jobs ~jobs_split t ->
    match t with
    | Leaf d ->
        (Leaf (fd (Data_list.to_data jobs) d), None)
    | Node {depth; value; sub_tree} ->
        let weight_left_subtree, weight_right_subtree = weight_a value in
        (*update the jobs at the current level*)
        let value', scan_result = fa (Data_list.to_data jobs) depth value in
        (*split the jobs for the next level*)
        let new_jobs_list =
          Data_list.split jobs
            (jobs_split (weight_left_subtree, weight_right_subtree))
        in
        (*get the updated subtree*)
        let sub, _ =
          update_split
            ~fa:(fun (b, b') i (x, y) ->
              let left = fa b i x in
              let right = fa b' i y in
              ((fst left, fst right), Option.both (snd left) (snd right)) )
            ~fd:(fun (b, b') (x, x') -> (fd b x, fd b' x'))
            ~weight_a:(fun (a, b) -> (weight_a a, weight_a b))
            ~jobs_split:(fun (x, y) (a, b) -> (jobs_split x a, jobs_split y b))
            ~jobs:new_jobs_list sub_tree
        in
        (Node {depth; value= value'; sub_tree= sub}, scan_result)

  let rec update_merge : type a b d.
         fa:((b * b) Data_list.t -> a -> a * b Data_list.t)
      -> fd:(d -> d * b Data_list.t)
      -> (a, d) t
      -> (a, d) t * b Data_list.t =
   fun ~fa ~fd t ->
    match t with
    | Leaf d ->
        let new_base, count_list = fd d in
        (Leaf new_base, count_list)
    | Node {depth; value; sub_tree} ->
        (*get the updated subtree*)
        let sub, counts =
          update_merge
            ~fa:(fun b (x, y) ->
              let b1, b2 = Data_list.to_data b in
              let left, count1 = fa (Single b1) x in
              let right, count2 = fa (Single b2) y in
              let count = Data_list.merge count1 count2 in
              ((left, right), count) )
            ~fd:(fun (x, y) ->
              let left, count1 = fd x in
              let right, count2 = fd y in
              let count = Data_list.merge count1 count2 in
              ((left, right), count) )
            sub_tree
        in
        let value', count_list = fa counts value in
        (Node {depth; value= value'; sub_tree= sub}, count_list)

  let update :
         ('b, 'c) New_job.t list
      -> update_level:int
      -> sequence_no:int
      -> depth:int
      -> ('a, 'd) t
      -> ('a, 'd) t * 'b option =
   fun completed_jobs ~update_level ~sequence_no:seq_no ~depth:_ tree ->
    let add_merges (jobs : ('b, 'c) New_job.t list) cur_level (weight, m) =
      let left, right = weight in
      if cur_level = update_level - 1 then
        (*Create new jobs from the completed ones*)
        let new_weight, m' =
          match (jobs, m) with
          | [], e ->
              (weight, e)
          | [New_job.Merge a; Merge b], Merge.Job.Empty ->
              ( (left - 1, right - 1)
              , Full {left= a; right= b; seq_no; status= Job_status.Todo} )
          | [Merge a], Empty ->
              ((left - 1, right), Part a)
          | [Merge b], Part a ->
              ( (left, right - 1)
              , Full {left= a; right= b; seq_no; status= Job_status.Todo} )
          | [Base _], Empty ->
              (*Depending on whether this is the first or second of the two base jobs*)
              let weight =
                if left = 0 then (left, right - 1) else (left - 1, right)
              in
              (weight, m)
          | [Base _], Part _ ->
              (*This should not happen because of 2:1 jobs-data invariant of the tree*)
              failwith "Invalid base jobs when merge on level-1 is part"
          | [Base _; Base _], Empty ->
              ((left - 1, right - 1), m)
          | _ ->
              failwith "Invalid merge job (level-1)"
        in
        ((new_weight, m'), None)
      else if cur_level = update_level then
        (*Mark completed jobs as Done*)
        match (jobs, m) with
        | [Merge a], Full ({status= Job_status.Todo; _} as x) ->
            let new_job = Merge.Job.Full {x with status= Job_status.Done} in
            let scan_result, weight' =
              if cur_level = 0 then (Some a, (0, 0)) else (None, weight)
            in
            ((weight', new_job), scan_result)
        | [], m ->
            ((weight, m), None)
        | _ ->
            failwith "Invalid merge job"
      else if cur_level < update_level - 1 then
        (*Update the job count for all the level above*)
        match jobs with
        | [] ->
            ((weight, m), None)
        | _ ->
            let jobs_sent_left = min (List.length jobs) left in
            let jobs_sent_right =
              min (List.length jobs - jobs_sent_left) right
            in
            let new_weight =
              (left - jobs_sent_left, right - jobs_sent_right)
            in
            ((new_weight, m), None)
      else ((weight, m), None)
    in
    let add_bases jobs (weight, d) =
      match (jobs, d) with
      | [], e ->
          (weight, e)
      | [New_job.Base d], Base.Job.Empty ->
          (weight - 1, Base.Job.Full {job= d; seq_no; status= Job_status.Todo})
      | [New_job.Merge _], Full b ->
          (weight, Full {b with status= Job_status.Done})
      | _ ->
          failwith "Invalid base job"
    in
    let jobs = Data_list.Single completed_jobs in
    update_split ~fa:add_merges ~fd:add_bases tree ~weight_a:fst ~jobs
      ~jobs_split:(fun (l, r) a -> (List.take a l, List.take (List.drop a l) r))

  let reset_weights : ('a, 'd) t -> ('a, 'd) t =
   fun tree ->
    let f_base base =
      match base with
      | _weight, Base.Job.Full {status= Job_status.Todo; _} ->
          ((1, snd base), Data_list.Single (1, 0))
      | _ ->
          ((0, snd base), Single (0, 0))
    in
    let f_merge lst m =
      let (l1, r1), (l2, r2) = Data_list.to_data lst in
      match m with
      | (_, _), Merge.Job.Full {status= Job_status.Todo; _} ->
          (((1, 0), snd m), Data_list.Single (1, 0))
      | _ ->
          (((l1 + r1, l2 + r2), snd m), Single (l1 + r1, l2 + r2))
    in
    fst (update_merge ~fa:f_merge ~fd:f_base tree)

  let jobs_on_level :
      depth:int -> level:int -> ('a, 'd) t -> ('b, 'c) Available_job.t list =
   fun ~depth ~level tree ->
    fold_depth ~init:[]
      ~fa:(fun i acc a ->
        match (i = level, a) with
        | true, (_weight, Merge.Job.Full {left; right; status= Todo; _}) ->
            Available_job.Merge (left, right) :: acc
        | _ ->
            acc )
      ~fd:(fun acc d ->
        match (level = depth, d) with
        | true, (_weight, Base.Job.Full {job; status= Todo; _}) ->
            Available_job.Base job :: acc
        | _ ->
            acc )
      tree
    |> List.rev

  let hash : ('a, 'd) t -> fa:('a -> string) -> fd:('d -> string) -> string =
   fun t ~fa ~fd ->
    fold ~init:"" ~fa:(fun acc a -> acc ^ fa a) ~fd:(fun acc d -> acc ^ fd d) t

  let to_jobs : ('a, 'd) t -> ('b, 'c) Available_job.t list =
   fun tree ->
    fold ~init:[]
      ~fa:(fun acc a ->
        match a with
        | _weight, Merge.Job.Full {left; right; status= Todo; _} ->
            Available_job.Merge (left, right) :: acc
        | _ ->
            acc )
      ~fd:(fun acc d ->
        match d with
        | _weight, Base.Job.Full {job; status= Todo; _} ->
            Available_job.Base job :: acc
        | _ ->
            acc )
      tree
    |> List.rev

  let leaves : ('a, 'b) t -> 'd list =
   fun tree ->
    fold_depth ~init:[]
      ~fa:(fun _ _ _ -> [])
      ~fd:(fun acc d ->
        match d with _, Base.Job.Full {job; _} -> job :: acc | _ -> acc )
      tree
    |> List.rev

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

  let required_job_count = function
    | Node {value= (l, r), _; _} ->
        l + r
    | Leaf b ->
        fst b
end

(*This struture works well because we always complete all the nodes on a specific level before proceeding to the next level*)
module T = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('a, 'd) t =
          { trees:
              ('a Merge.Stable.V1.t, 'd Base.Stable.V1.t) Tree.Stable.V1.t
              Non_empty_list.Stable.V1.t
                (*use non empty list*)
          ; acc: ('a * 'd list) option
                (*last emitted proof and the corresponding transactions*)
          ; recent_tree_data: 'd list
          ; other_trees_data: 'd list list
                (*Keeping track of all the transactions corresponding to a proof returned*)
          ; curr_job_seq_no: int
                (*Sequence number for the jobs added every block*)
          ; max_base_jobs: int (*transaction_capacity_log_2*)
          ; delay: int }
        [@@deriving sexp, bin_io, version]
      end

      include T
    end

    module Latest = V1
  end

  type ('a, 'd) t = ('a, 'd) Stable.Latest.t =
    { trees:
        ('a Merge.Stable.V1.t, 'd Base.Stable.V1.t) Tree.Stable.V1.t
        Non_empty_list.Stable.V1.t
    ; acc: ('a * 'd list) option
          (*last emitted proof and the corresponding transactions*)
    ; recent_tree_data: 'd list
    ; other_trees_data: 'd list list
    ; curr_job_seq_no: int
    ; max_base_jobs: int
    ; delay: int }
  [@@deriving sexp]

  let create_tree_for_level ~level ~depth ~merge ~base =
    let rec go : type a d. int -> (int -> a) -> d -> (a, d) Tree.t =
     fun d fmerge base ->
      if d >= depth then Leaf base
      else
        let sub_tree =
          go (d + 1) (fun i -> (fmerge i, fmerge i)) (base, base)
        in
        Node {depth= d; value= fmerge d; sub_tree}
    in
    let base_weight = if level = -1 then 0 else 1 in
    go 0
      (fun d ->
        let weight =
          if level = -1 then (0, 0)
          else
            let x = Int.pow 2 level / Int.pow 2 (d + 1) in
            (x, x)
        in
        (weight, merge) )
      (base_weight, base)

  let create_tree ~depth =
    create_tree_for_level ~level:depth ~depth ~merge:Merge.Job.Empty
      ~base:Base.Job.Empty

  let empty : type a d. max_base_jobs:int -> delay:int -> (a, d) t =
   fun ~max_base_jobs ~delay ->
    let depth = Int.ceil_log2 max_base_jobs in
    let first_tree = create_tree ~depth in
    { trees= Non_empty_list.singleton first_tree
    ; acc= None
    ; recent_tree_data= []
    ; other_trees_data= []
    ; curr_job_seq_no= 0
    ; max_base_jobs
    ; delay }

  let delay : type a d. (a, d) t -> int = fun t -> t.delay

  let max_base_jobs : type a d. (a, d) t -> int = fun t -> t.max_base_jobs
end

module type State_intf = sig
  type ('a, 'd) t

  val empty : max_base_jobs:int -> delay:int -> ('a, 'd) t

  val max_base_jobs : ('a, 'd) t -> int

  val delay : ('a, 'd) t -> int
end

module type State_monad_intf = functor (State : State_intf) -> sig
  include Monad.S3

  val run_state :
       ('b, 'a, 'd) t
    -> state:('a, 'd) State.t
    -> ('b * ('a, 'd) State.t) Or_error.t

  val eval_state : ('b, 'a, 'd) t -> state:('a, 'd) State.t -> 'b Or_error.t

  val exec_state :
    ('b, 'a, 'd) t -> state:('a, 'd) State.t -> ('a, 'd) State.t Or_error.t

  val get : (('a, 'd) State.t, 'a, 'd) t

  val put : ('a, 'd) State.t -> (unit, 'a, 'd) t

  val error_if : bool -> message:string -> (unit, _, _) t
end

module Make_state_monad : State_monad_intf =
functor
  (State : State_intf)
  ->
  struct
    module T = struct
      type ('a, 'd) state = ('a, 'd) State.t

      type ('b, 'a, 'd) t = ('a, 'd) state -> ('b * ('a, 'd) state) Or_error.t

      let return : type a b d. b -> (b, a, d) t = fun a s -> Ok (a, s)

      let bind
          (*: type a b c d. (b, a, d) t -> f: (b -> (c, a, d) t) -> (c, a, d) t = fun*)
          m ~f = function
        | s ->
            let open Or_error.Let_syntax in
            let%bind a, s' = m s in
            f a s'

      let map = `Define_using_bind
    end

    include T
    include Monad.Make3 (T)

    let get : type a d. ((a, d) state, a, d) t = function s -> Ok (s, s)

    let put (*: type a d. (a, d) state -> (unit, a, d) t = fun*) s = function
      | _ ->
          Ok ((), s)

    let run_state : type a b d.
        (b, a, d) t -> state:(a, d) state -> (b * (a, d) state) Or_error.t =
     fun t ~state -> t state

    let error_if : type a d. bool -> message:string -> (unit, a, d) t =
     fun b ~message ->
      if b then fun _ -> Or_error.error_string message else return ()

    let eval_state : type a b d.
        (b, a, d) t -> state:(a, d) state -> b Or_error.t =
     fun t ~state ->
      let open Or_error.Let_syntax in
      let%map b, _ = run_state t ~state in
      b

    let exec_state : type a b d.
        (b, a, d) t -> state:(a, d) state -> (a, d) state Or_error.t =
     fun t ~state ->
      let open Or_error.Let_syntax in
      let%map _, s = run_state t ~state in
      s
  end

module State = struct
  include T
  module Hash = Hash

  let hash {trees; acc; max_base_jobs; curr_job_seq_no; delay; _} fa fd =
    let h = ref (Digestif.SHA256.init ()) in
    let add_string s = h := Digestif.SHA256.feed_string !h s in
    Non_empty_list.iter trees ~f:(fun tree ->
        let w_to_string (l, r) = Int.to_string l ^ Int.to_string r in
        let fa = function
          | w, Merge.Job.Empty ->
              w_to_string w ^ "Empty"
          | w, Merge.Job.Full {left; right; status; seq_no} ->
              w_to_string w ^ "Full" ^ fa left ^ fa right
              ^ Int.to_string seq_no
              ^ Job_status.to_string status
          | w, Merge.Job.Part j ->
              w_to_string w ^ "Part" ^ fa j
        in
        let fd = function
          | w, Base.Job.Empty ->
              Int.to_string w ^ "Empty"
          | w, Base.Job.Full {job; status; seq_no} ->
              Int.to_string w ^ "Full" ^ fd job
              ^ Job_status.to_string status
              ^ Int.to_string seq_no
        in
        add_string (Tree.hash tree ~fa ~fd) ) ;
    let acc_string =
      Option.value_map acc ~default:"None" ~f:(fun (a, d_lst) ->
          fa a ^ List.fold ~init:"" d_lst ~f:(fun acc d -> acc ^ fd d) )
    in
    add_string acc_string ;
    add_string (Int.to_string curr_job_seq_no) ;
    add_string (Int.to_string max_base_jobs) ;
    add_string (Int.to_string delay) ;
    Digestif.SHA256.get !h

  module Make_foldable (M : Monad.S) = struct
    module Tree_foldable = Tree.Make_foldable (M)

    let fold_chronological_until :
           ('a, 'd) t
        -> init:'acc
        -> fa:('c -> 'a Merge.t -> ('c, 'stop) Continue_or_stop.t M.t)
        -> fd:('c -> 'd Base.t -> ('c, 'stop) Continue_or_stop.t M.t)
        -> finish:('acc -> 'stop M.t)
        -> 'stop M.t =
     fun t ~init ~fa ~fd ~finish ->
      let open M.Let_syntax in
      let open Container.Continue_or_stop in
      let work_trees = Non_empty_list.rev t.trees |> Non_empty_list.to_list in
      let rec go acc = function
        | [] ->
            M.return (Continue acc)
        | tree :: trees -> (
            match%bind
              Tree_foldable.fold_depth_until'
                ~fa:(fun _ -> fa)
                ~fd ~init:acc tree
            with
            | Continue r ->
                go r trees
            | Stop e ->
                M.return (Stop e) )
      in
      match%bind go init work_trees with
      | Continue r ->
          finish r
      | Stop e ->
          M.return e
  end

  module Foldable_ident = Make_foldable (Monad.Ident)

  let fold_chronological t ~init ~fa ~fd =
    let open Container.Continue_or_stop in
    Foldable_ident.fold_chronological_until t ~init
      ~fa:(fun acc a -> Continue (fa acc a))
      ~fd:(fun acc d -> Continue (fd acc d))
      ~finish:Fn.id
end

include T
module State_monad = Make_state_monad (T)

(* TODO: Reset the sequence number starting from 1
   If [997;997;998;998;998;999;999] is sequence number of the current
   available jobs
   then [1;1;2;2;2;3;3] will be the new sequence numbers of the same jobs *)
(*let reset_seq_no t =
  let open Or_error.Let_syntax in
  let seq_no_at x =
    match Ring_buffer.read_i t.jobs x with
    | Job.Base (Some (_, s)) ->
        Ok s
    | Merge (Bcomp (_, _, s)) ->
        Ok s
    | _ ->
        Or_error.error_string (sprintf "Expecting a completed job at %d" x)
  in
  let job_with_new_seq x seq_no =
    match Ring_buffer.read_i t.jobs x with
    | Job.Base (Some (d, _)) ->
        Ok (Job.Base (Some (d, seq_no)))
    | Merge (Bcomp (a1, a2, _)) ->
        Ok (Merge (Bcomp (a1, a2, seq_no)))
    | _ ->
        Or_error.error_string (sprintf "Expecting a completed job at %d" x)
  in
  let first_seq_no =
    match Queue.peek t.stateful_work_order with
    | None ->
        Ok 1
    | Some x ->
        seq_no_at x
  in
  Queue.fold ~init:(Ok 0) t.stateful_work_order ~f:(fun cur_seq index ->
      let%bind seq_no =
        Or_error.bind cur_seq ~f:(fun _ -> seq_no_at index)
      in
      let%bind offset = first_seq_no in
      let new_seq_no = seq_no - offset + 1 in
      let%map () =
        Or_error.bind (job_with_new_seq index new_seq_no)
          ~f:(fun updated_job -> update_cur_job t updated_job index)
      in
      new_seq_no )
end*)

let max_trees : type a d. (a, d) t -> int =
 fun t -> ((Int.ceil_log2 t.max_base_jobs + 1) * (t.delay + 1)) + 1

let work_to_do : type a d.
       (a Merge.t, d Base.t) Tree.t list
    -> max_base_jobs:int
    -> (a, d) Available_job.t list =
 fun trees ~max_base_jobs ->
  let depth = Int.ceil_log2 max_base_jobs in
  List.concat_mapi trees ~f:(fun i tree ->
      Tree.jobs_on_level ~depth ~level:(depth - i) tree )

(*work on all the level and all the trees*)
let all_work : type a d. (a, d) t -> (a, d) Available_job.t list list =
 fun t ->
  let depth = Int.ceil_log2 t.max_base_jobs in
  let work trees = List.concat_map trees ~f:(fun tree -> Tree.to_jobs tree) in
  let rec go trees work_list delay =
    if List.length trees < delay then
      let work = work trees in
      work :: work_list
    else
      let work_trees =
        List.take
          (List.filteri trees ~f:(fun i _ -> i % delay = delay - 1))
          (depth + 1)
      in
      let work = work work_trees in
      let remaining_trees =
        List.filteri trees ~f:(fun i _ -> i % delay <> delay - 1)
      in
      go remaining_trees (work :: work_list) (max 2 (delay - 1))
  in
  let work_list = go (Non_empty_list.tail t.trees) [] (t.delay + 1) in
  let current_leaves = Tree.to_jobs (Non_empty_list.head t.trees) in
  List.rev_append work_list [current_leaves]

let work : type a d.
       (a Merge.t, d Base.t) Tree.t list
    -> delay:int
    -> max_base_jobs:int
    -> (a, d) Available_job.t list =
 fun trees ~delay ~max_base_jobs ->
  let depth = Int.ceil_log2 max_base_jobs in
  let work_trees =
    List.take
      (List.filteri trees ~f:(fun i _ -> i % delay = delay - 1))
      (depth + 1)
  in
  work_to_do work_trees ~max_base_jobs

let work_for_current_tree = function
  | t ->
      let delay = t.delay + 1 in
      work (Non_empty_list.tail t.trees) ~max_base_jobs:t.max_base_jobs ~delay

let work_for_next_update : type a d.
    (a, d) t -> data_count:int -> (a, d) Available_job.t list list =
 fun t ~data_count ->
  let delay = t.delay + 1 in
  let current_tree_space =
    Tree.required_job_count (Non_empty_list.head t.trees)
  in
  let set1 =
    work (Non_empty_list.tail t.trees) ~max_base_jobs:t.max_base_jobs ~delay
  in
  let count = min data_count t.max_base_jobs in
  if current_tree_space < count then
    let set2 =
      List.take
        (work
           (Non_empty_list.to_list t.trees)
           ~max_base_jobs:t.max_base_jobs ~delay)
        ((count - current_tree_space) * 2)
    in
    [set1; set2]
  else [set1]

let free_space_on_current_tree t =
  let tree = Non_empty_list.head t.trees in
  Tree.required_job_count tree

let cons b bs =
  Option.value_map (Non_empty_list.of_list_opt bs)
    ~default:(Non_empty_list.singleton b) ~f:(fun bs ->
      Non_empty_list.cons b bs )

let append bs bs' =
  Option.value_map (Non_empty_list.of_list_opt bs') ~default:bs ~f:(fun bs' ->
      Non_empty_list.append bs bs' )

let add_merge_jobs : completed_jobs:'a list -> (_, 'a, _) State_monad.t =
 fun ~completed_jobs ->
  let open State_monad.Let_syntax in
  let%bind state = State_monad.get in
  let delay = state.delay + 1 in
  let depth = Int.ceil_log2 state.max_base_jobs in
  let merge_jobs = List.map completed_jobs ~f:(fun j -> New_job.Merge j) in
  let jobs_required = work_for_current_tree state in
  let curr_tree = Non_empty_list.head state.trees in
  let updated_trees, result_opt, _ =
    List.foldi (Non_empty_list.tail state.trees) ~init:([], None, merge_jobs)
      ~f:(fun i (trees, scan_result, jobs) tree ->
        if i % delay = delay - 1 then
          (*All the trees with delay number of trees between them*)
          (*TODO: dont updste if required job count is zero*)
          let tree', scan_result' =
            Tree.update
              (List.take jobs (Tree.required_job_count tree))
              ~update_level:(depth - (i / delay))
              ~sequence_no:state.curr_job_seq_no ~depth tree
          in
          ( tree' :: trees
          , scan_result'
          , List.drop jobs (Tree.required_job_count tree) )
        else (tree :: trees, scan_result, jobs) )
  in
  let updated_trees, result_opt =
    let updated_trees, result_opt =
      Option.value_map result_opt
        ~default:(List.rev updated_trees, None)
        ~f:(fun res ->
          match updated_trees with
          | [] ->
              ([], None)
          | t :: ts ->
              let data_list = Tree.leaves t in
              (List.rev ts, Some (res, data_list)) )
    in
    if
      Option.is_some result_opt
      || List.length (curr_tree :: updated_trees) < max_trees state
         && List.length completed_jobs = List.length jobs_required
      (*exact number of jobs*)
    then (List.map updated_trees ~f:Tree.reset_weights, result_opt)
    else (updated_trees, result_opt)
  in
  let all_trees = cons curr_tree updated_trees in
  let%map _ = State_monad.put {state with trees= all_trees} in
  result_opt

let add_data : data:'d list -> (_, _, 'd) State_monad.t =
 fun ~data ->
  let open State_monad.Let_syntax in
  let%bind state = State_monad.get in
  let depth = Int.ceil_log2 state.max_base_jobs in
  let tree = Non_empty_list.head state.trees in
  let base_jobs = List.map data ~f:(fun j -> New_job.Base j) in
  let available_space = Tree.required_job_count tree in
  let tree, _ =
    Tree.update base_jobs ~update_level:depth
      ~sequence_no:state.curr_job_seq_no ~depth tree
  in
  let updated_trees =
    if List.length base_jobs = available_space then
      cons (create_tree ~depth) [Tree.reset_weights tree]
    else Non_empty_list.singleton tree
  in
  let%map _ =
    State_monad.put
      {state with trees= append updated_trees (Non_empty_list.tail state.trees)}
  in
  ()

let incr_sequence_no = function
  | state ->
      let open State_monad in
      (*let open State_monad.Let_syntax in*)
      put {state with curr_job_seq_no= state.curr_job_seq_no + 1}

let update_helper :
    data:'d list -> completed_jobs:'a list -> ('b, 'a, 'd) State_monad.t =
 fun ~data ~completed_jobs ->
  let open State_monad in
  let open State_monad.Let_syntax in
  let%bind t = get in
  let%bind () =
    error_if
      (List.length data > t.max_base_jobs)
      ~message:
        (sprintf
           !"Data count (%d) exceeded maximum (%d)"
           (List.length data) t.max_base_jobs)
  in
  let delay = t.delay + 1 in
  (*Increment the sequence number*)
  let%bind () = incr_sequence_no t in
  let latest_tree = Non_empty_list.head t.trees in
  let available_space = Tree.required_job_count latest_tree in
  (*Possible that new base jobs be added to a new tree within an update. This happens when the throughput is not always at max. Which also requires merge jobs to be done one two different set of trees*)
  let data1, data2 = List.split_n data available_space in
  let required_jobs_for_current_tree =
    work (Non_empty_list.tail t.trees) ~max_base_jobs:t.max_base_jobs ~delay
    |> List.length
  in
  let jobs1, jobs2 =
    List.split_n completed_jobs required_jobs_for_current_tree
  in
  (*update fist set of jobs and data*)
  let%bind result_opt = add_merge_jobs ~completed_jobs:jobs1 in
  let%bind () = add_data ~data:data1 in
  (*update second set of jobs and data. This will be empty if all the data fit in the current tree*)
  let%bind _ = add_merge_jobs ~completed_jobs:jobs2 in
  let%bind () = add_data ~data:data2 in
  let%bind state = State_monad.get in
  (*update the latest emitted value *)
  let%bind () =
    State_monad.put
      {state with acc= Option.merge result_opt state.acc ~f:Fn.const}
  in
  (*Check the tree-list length is under max*)
  let%map () =
    error_if
      (Non_empty_list.length state.trees > max_trees state)
      ~message:
        (sprintf
           !"Tree list length (%d) exceeded maximum (%d)"
           (Non_empty_list.length state.trees)
           (max_trees state))
  in
  result_opt

let update :
       data:'d list
    -> completed_jobs:'a list
    -> ('a, 'd) t
    -> (('a * 'd list) option * ('a, 'd) t) Or_error.t =
 fun ~data ~completed_jobs state ->
  State_monad.run_state (update_helper ~data ~completed_jobs) ~state

let next_k_jobs :
    state:('a, 'd) t -> k:int -> ('a, 'd) Available_job.t list Or_error.t =
 fun ~state ~k ->
  let work = all_work state |> List.concat in
  if k > List.length work then
    Or_error.errorf "You asked for %d jobs, but I only have %d available" k
      (List.length work)
  else Ok (List.take work k)

let all_jobs : ('a, 'd) t -> ('a, 'd) Available_job.t list list = all_work

let jobs_for_next_update t = work_for_next_update t ~data_count:t.max_base_jobs

let free_space t = t.max_base_jobs

let last_emitted_value : ('a, 'd) t -> ('a * 'd list) option = fun t -> t.acc

let current_job_sequence_number t = t.curr_job_seq_no

(*let current_data state =
  state.recent_tree_data @ List.concat state.other_trees_data*)

let base_jobs_on_latest_tree t =
  let depth = Int.ceil_log2 t.max_base_jobs in
  List.filter_map
    (Tree.jobs_on_level ~depth ~level:depth (Non_empty_list.head t.trees))
    ~f:(fun job -> match job with Base d -> Some d | Merge _ -> None)

let partition_if_overflowing : ('a, 'd) t -> Space_partition.t =
 fun t ->
  let cur_tree_space = free_space_on_current_tree t in
  (*Check actual work count because it would be zero initially*)
  let work_count = work_for_current_tree t |> List.length in
  let depth = Int.ceil_log2 t.max_base_jobs in
  let work_count_new_tree =
    work_for_current_tree
      {t with trees= Non_empty_list.cons (create_tree ~depth) t.trees}
    |> List.length
  in
  { first= (cur_tree_space, work_count)
  ; second=
      ( if cur_tree_space < t.max_base_jobs then
        let slots = t.max_base_jobs - cur_tree_space in
        Some (slots, min work_count_new_tree (2 * slots))
      else None ) }

let next_on_new_tree t =
  let curr_tree_space = free_space_on_current_tree t in
  curr_tree_space = t.max_base_jobs

let pending_data t =
  List.concat_map Non_empty_list.(to_list @@ rev t.trees) ~f:Tree.leaves

(*List.(rev (concat (t.recent_tree_data :: t.other_trees_data)))*)

let is_valid _ = failwith ""

let view_jobs_with_position (_t : ('a, 'd) State.t) _fa _fd = failwith "TODO"

let%test_module "test" =
  ( module struct
    let%test_unit "always max base jobs" =
      let max_base_jobs = 256 in
      let state = empty ~max_base_jobs ~delay:2 in
      let _t' =
        List.foldi ~init:([], state) (List.init 100 ~f:Fn.id)
          ~f:(fun i (expected_results, t') _ ->
            let data = List.init max_base_jobs ~f:(fun j -> i + j) in
            let expected_results = data :: expected_results in
            let work =
              work_for_next_update t' ~data_count:(List.length data)
              |> List.concat
            in
            let new_merges =
              List.map work ~f:(fun job ->
                  match job with Base i -> i | Merge (i, j) -> i + j )
            in
            let result_opt, t' =
              update ~data ~completed_jobs:new_merges t' |> Or_error.ok_exn
            in
            let expected_result, remaining_expected_results =
              Option.value_map result_opt
                ~default:((0, []), expected_results)
                ~f:(fun _ ->
                  match List.rev expected_results with
                  | [] ->
                      ((0, []), [])
                  | x :: xs ->
                      ((List.sum (module Int) x ~f:Fn.id, x), List.rev xs) )
            in
            assert (
              Option.value ~default:expected_result result_opt
              = expected_result ) ;
            (remaining_expected_results, t') )
      in
      ()

    let%test_unit "Ramdom base jobs" =
      let max_base_jobs = 4 in
      let t = empty ~max_base_jobs ~delay:1 in
      let state = ref t in
      Quickcheck.test
        (Quickcheck.Generator.list (Int.gen_incl 1 1))
        ~f:(fun list ->
          let t' = !state in
          let data = List.take list max_base_jobs in
          Core.printf !"tree %{sexp:(int, int)t} \n%!" t' ;
          let work =
            List.take
              ( work_for_next_update t' ~data_count:(List.length data)
              |> List.concat )
              (List.length data * 2)
          in
          let new_merges =
            List.map work ~f:(fun job ->
                match job with Base i -> i | Merge (i, j) -> i + j )
          in
          let result_opt, t' =
            update ~data ~completed_jobs:new_merges t' |> Or_error.ok_exn
          in
          let expected_result =
            (max_base_jobs, List.init max_base_jobs ~f:(fun _ -> 1))
          in
          assert (
            Option.value ~default:expected_result result_opt = expected_result
          ) ;
          state := t' )
  end )
