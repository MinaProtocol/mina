open Core_kernel

(*Glossary of type variables used in this file:
  1. 'base: polymorphic type for jobs in the leaves of the scan state tree
  2. 'merge: polymorphic type for jobs in the intermediate nodes of the scan state tree
  3. 'base_t: 'base Base.t
  4. 'merge_t: 'merge Merge.t
  5. 'base_job: Base.Job.t
  6. 'merge_job: Merge.Job.t
  *)

(**Sequence number for jobs in the scan state that corresponds to the order in 
which they were added*)
module Sequence_number = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = int [@@deriving sexp, bin_io, version {unnumbered}]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp]
end

(**Each node on the tree is viewed as a job that needs to be completed. When a 
job is completed, it creates a new "Todo" job and marks the old job as "Done"*)
module Job_status = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Todo | Done [@@deriving sexp, bin_io, version {unnumbered}]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t = Todo | Done [@@deriving sexp]

  let to_string = function Todo -> "Todo" | Done -> "Done"
end

(**The number of new jobs that can be added to this tree. This could be new 
base jobs or new merge jobs. Each node has a weight associated to it and the 
new jobs received are distributed across the tree based on this number. *)
module Weight = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = int [@@deriving sexp, bin_io, version {unnumbered}]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp]
end

(**For base proofs (Proving new transactions)*)
module Base = struct
  module Job = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type 'base t =
            | Empty
            | Full of
                { job: 'base
                ; seq_no: Sequence_number.Stable.V1.t
                ; status: Job_status.Stable.V1.t }
          [@@deriving sexp, bin_io, version]
        end

        include T
      end

      module Latest = V1
    end

    type 'base t = 'base Stable.Latest.t =
      | Empty
      | Full of
          { job: 'base
          ; seq_no: Sequence_number.Stable.V1.t
          ; status: Job_status.Stable.V1.t }
    [@@deriving sexp]
  end

  module Stable = struct
    module V1 = struct
      module T = struct
        type 'base t = Weight.Stable.V1.t * 'base Job.Stable.V1.t
        [@@deriving sexp, bin_io, version]
      end

      include T
    end

    module Latest = V1
  end

  type 'base t = 'base Stable.Latest.t [@@deriving sexp]
end

(** For merge proofs: Merging two base proofs or two merge proofs*)
module Merge = struct
  module Job = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type 'merge t =
            | Empty
            | Part of 'merge (*When only the left component of the job is available since we always complete the jobs from left to right*)
            | Full of
                { left: 'merge
                ; right: 'merge
                ; seq_no: Sequence_number.Stable.V1.t
                ; status: Job_status.Stable.V1.t }
          [@@deriving sexp, bin_io, version]
        end

        include T
      end

      module Latest = V1
    end

    type 'merge t = 'merge Stable.Latest.t =
      | Empty
      | Part of 'merge
      | Full of
          { left: 'merge
          ; right: 'merge
          ; seq_no: Sequence_number.Stable.V1.t
          ; status: Job_status.Stable.V1.t }
    [@@deriving sexp]
  end

  module Stable = struct
    module V1 = struct
      module T = struct
        type 'merge t =
          (Weight.Stable.V1.t * Weight.Stable.V1.t) * 'merge Job.Stable.V1.t
        [@@deriving sexp, bin_io, version]
      end

      include T
    end

    module Latest = V1
  end

  type 'merge t = 'merge Stable.Latest.t [@@deriving sexp]
end

(**All the jobs on a tree that can be done. Base.Full and Merge.Bcomp*)
module Available_job = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('merge, 'base) t = Base of 'base | Merge of 'merge * 'merge
        [@@deriving sexp]
      end

      include T
    end

    module Latest = V1
  end

  type ('merge, 'base) t = ('merge, 'base) Stable.Latest.t =
    | Base of 'base
    | Merge of 'merge * 'merge
  [@@deriving sexp]
end

(**New jobs to be added (including new transactions or new merge jobs)*)
module New_job = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('merge, 'base) t = Base of 'base | Merge of 'merge
        [@@deriving sexp]
      end

      include T
    end

    module Latest = V1
  end

  type ('merge, 'base) t = ('merge, 'base) Stable.Latest.t =
    | Base of 'base
    | Merge of 'merge
  [@@deriving sexp]
end

(**Space available and number of jobs required to enqueue data. When there isn't enough space on the current tree for all the base jobs per update, the remainder of it would be added on to a new tree. The partition specifies how much space is available and the number on the each of the trees *)
module Space_partition = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = {first: int * int; second: (int * int) option}
        [@@deriving sexp, bin_io, version {unnumbered}]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t = {first: int * int; second: (int * int) option}
  [@@deriving sexp]
end

(**View of a job for json output*)
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

(**A single tree with number of leaves = max_base_jobs = 2^transaction_capacity_log_2 *)
module Tree = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('merge_t, 'base_t) t =
          | Leaf of 'base_t
          | Node of
              { depth: int
              ; value: 'merge_t
              ; sub_tree: ('merge_t * 'merge_t, 'base_t * 'base_t) t }
        [@@deriving sexp, bin_io, version]
      end

      include T
    end

    module Latest = V1
  end

  type ('merge_t, 'base_t) t = ('merge_t, 'base_t) Stable.Latest.t =
    | Leaf of 'base_t
    | Node of
        { depth: int
        ; value: 'merge_t
        ; sub_tree: ('merge_t * 'merge_t, 'base_t * 'base_t) t }
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
  let rec map_depth : type a_merge b_merge c_base d_base.
         f_merge:(int -> a_merge -> b_merge)
      -> f_base:(c_base -> d_base)
      -> (a_merge, c_base) t
      -> (b_merge, d_base) t =
   fun ~f_merge ~f_base tree ->
    match tree with
    | Leaf d ->
        Leaf (f_base d)
    | Node {depth; value; sub_tree} ->
        Node
          { depth
          ; value= f_merge depth value
          ; sub_tree=
              map_depth
                ~f_merge:(fun i (x, y) -> (f_merge i x, f_merge i y))
                ~f_base:(fun (x, y) -> (f_base x, f_base y))
                sub_tree }

  let map : type a_merge b_merge c_base d_base.
         f_merge:(a_merge -> b_merge)
      -> f_base:(c_base -> d_base)
      -> (a_merge, c_base) t
      -> (b_merge, d_base) t =
   fun ~f_merge ~f_base tree ->
    map_depth tree ~f_base ~f_merge:(fun _ -> f_merge)

  (* foldi where i is the cur_level*)
  module Make_foldable (M : Monad.S) = struct
    let rec fold_depth_until' : type merge_t accum base_t final.
           f_merge:(   int
                    -> accum
                    -> merge_t
                    -> (accum, final) Continue_or_stop.t M.t)
        -> f_base:(accum -> base_t -> (accum, final) Continue_or_stop.t M.t)
        -> init:accum
        -> (merge_t, base_t) t
        -> (accum, final) Continue_or_stop.t M.t =
     fun ~f_merge ~f_base ~init:acc t ->
      let open Container.Continue_or_stop in
      let open M.Let_syntax in
      match t with
      | Leaf d ->
          f_base acc d
      | Node {depth; value; sub_tree} -> (
          match%bind f_merge depth acc value with
          | Continue acc' ->
              fold_depth_until'
                ~f_merge:(fun i acc (x, y) ->
                  match%bind f_merge i acc x with
                  | Continue r ->
                      f_merge i r y
                  | x ->
                      M.return x )
                ~f_base:(fun acc (x, y) ->
                  match%bind f_base acc x with
                  | Continue r ->
                      f_base r y
                  | x ->
                      M.return x )
                ~init:acc' sub_tree
          | x ->
              M.return x )

    let fold_depth_until : type merge_t base_t accum final.
           f_merge:(   int
                    -> accum
                    -> merge_t
                    -> (accum, final) Continue_or_stop.t M.t)
        -> f_base:(accum -> base_t -> (accum, final) Continue_or_stop.t M.t)
        -> init:accum
        -> finish:(accum -> final M.t)
        -> (merge_t, base_t) t
        -> final M.t =
     fun ~f_merge ~f_base ~init ~finish t ->
      let open M.Let_syntax in
      match%bind fold_depth_until' ~f_merge ~f_base ~init t with
      | Continue result ->
          finish result
      | Stop e ->
          M.return e
  end

  module Foldable_ident = Make_foldable (Monad.Ident)

  let fold_depth : type merge_t base_t accum.
         f_merge:(int -> accum -> merge_t -> accum)
      -> f_base:(accum -> base_t -> accum)
      -> init:accum
      -> (merge_t, base_t) t
      -> accum =
   fun ~f_merge ~f_base ~init t ->
    Foldable_ident.fold_depth_until
      ~f_merge:(fun i acc a -> Continue (f_merge i acc a))
      ~f_base:(fun acc d -> Continue (f_base acc d))
      ~init ~finish:Fn.id t

  let fold : type merge_t base_t accum.
         f_merge:(accum -> merge_t -> accum)
      -> f_base:(accum -> base_t -> accum)
      -> init:accum
      -> (merge_t, base_t) t
      -> accum =
   fun ~f_merge ~f_base ~init t ->
    fold_depth t ~init ~f_merge:(fun _ -> f_merge) ~f_base

  let fold_until : type merge_t base_t accum final.
         f_merge:(accum -> merge_t -> (accum, final) Continue_or_stop.t)
      -> f_base:(accum -> base_t -> (accum, final) Continue_or_stop.t)
      -> init:accum
      -> finish:(accum -> final)
      -> (merge_t, base_t) t
      -> final =
   fun ~f_merge ~f_base ~init ~finish t ->
    Foldable_ident.fold_depth_until
      ~f_merge:(fun _ -> f_merge)
      ~f_base ~init ~finish t

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

    let rec of_tree : type merge_t weight data base_t.
           data t
        -> (merge_t, base_t) tree
        -> weight_a:(merge_t -> weight * weight)
        -> weight_d:(base_t -> weight * weight)
        -> f_split:(weight * weight -> data -> data * data)
        -> on_level:int
        -> data t =
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
    result -> final proof
    f_merge, f_base are to update the nodes with new jobs and mark old jobs to "Done"*)
  let rec update_split : type merge_t base_t data weight result.
         f_merge:(data -> int -> merge_t -> merge_t * result option)
      -> f_base:(data -> base_t -> base_t)
      -> weight_merge:(merge_t -> weight * weight)
      -> jobs:data Data_list.t
      -> update_level:int
      -> jobs_split:(weight * weight -> data -> data * data)
      -> (merge_t, base_t) t
      -> (merge_t, base_t) t * result option =
   fun ~f_merge ~f_base ~weight_merge ~jobs ~update_level ~jobs_split t ->
    match t with
    | Leaf d ->
        let x = (Leaf (f_base (Data_list.to_data jobs) d), None) in
        x
    | Node {depth; value; sub_tree} ->
        let weight_left_subtree, weight_right_subtree = weight_merge value in
        (*update the jobs at the current level*)
        let value', scan_result =
          f_merge (Data_list.to_data jobs) depth value
        in
        (*get the updated subtree*)
        let sub, _ =
          if update_level = depth then (sub_tree, None)
          else
            (*split the jobs for the next level*)
            let new_jobs_list =
              Data_list.split jobs
                (jobs_split (weight_left_subtree, weight_right_subtree))
            in
            update_split
              ~f_merge:(fun (b, b') i (x, y) ->
                let left = f_merge b i x in
                let right = f_merge b' i y in
                ((fst left, fst right), Option.both (snd left) (snd right)) )
              ~f_base:(fun (b, b') (x, x') -> (f_base b x, f_base b' x'))
              ~weight_merge:(fun (a, b) -> (weight_merge a, weight_merge b))
              ~update_level
              ~jobs_split:(fun (x, y) (a, b) ->
                (jobs_split x a, jobs_split y b) )
              ~jobs:new_jobs_list sub_tree
        in
        (Node {depth; value= value'; sub_tree= sub}, scan_result)

  let rec update_accumulate : type merge_t base_t data.
         f_merge:(   (data * data) Data_list.t
                  -> merge_t
                  -> merge_t * data Data_list.t)
      -> f_base:(base_t -> base_t * data Data_list.t)
      -> (merge_t, base_t) t
      -> (merge_t, base_t) t * data Data_list.t =
   fun ~f_merge ~f_base t ->
    match t with
    | Leaf d ->
        let new_base, count_list = f_base d in
        (Leaf new_base, count_list)
    | Node {depth; value; sub_tree} ->
        (*get the updated subtree*)
        let sub, counts =
          update_accumulate
            ~f_merge:(fun b (x, y) ->
              let b1, b2 = Data_list.to_data b in
              let left, count1 = f_merge (Single b1) x in
              let right, count2 = f_merge (Single b2) y in
              let count = Data_list.merge count1 count2 in
              ((left, right), count) )
            ~f_base:(fun (x, y) ->
              let left, count1 = f_base x in
              let right, count2 = f_base y in
              let count = Data_list.merge count1 count2 in
              ((left, right), count) )
            sub_tree
        in
        let value', count_list = f_merge counts value in
        (Node {depth; value= value'; sub_tree= sub}, count_list)

  let update :
         ('merge_job, 'base_job) New_job.t list
      -> update_level:int
      -> sequence_no:int
      -> depth:int
      -> ('merge_t, 'base_t) t
      -> ('merge_t, 'base_t) t * 'b option =
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
    update_split ~f_merge:add_merges ~f_base:add_bases tree ~weight_merge:fst
      ~jobs ~update_level ~jobs_split:(fun (l, r) a ->
        (List.take a l, List.take (List.drop a l) r) )

  let reset_weights : ('merge_t, 'base_t) t -> ('merge_t, 'base_t) t =
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
    fst (update_accumulate ~f_merge ~f_base tree)

  let jobs_on_level :
         depth:int
      -> level:int
      -> ('merge_t, 'base_t) t
      -> ('merge_job, 'base_job) Available_job.t list =
   fun ~depth ~level tree ->
    fold_depth ~init:[]
      ~f_merge:(fun i acc a ->
        match (i = level, a) with
        | true, (_weight, Merge.Job.Full {left; right; status= Todo; _}) ->
            Available_job.Merge (left, right) :: acc
        | _ ->
            acc )
      ~f_base:(fun acc d ->
        match (level = depth, d) with
        | true, (_weight, Base.Job.Full {job; status= Todo; _}) ->
            Available_job.Base job :: acc
        | _ ->
            acc )
      tree
    |> List.rev

  let to_hashable_jobs :
      ('merge_t, 'base_t) t -> ('merge_job, 'base_job) New_job.t list =
   fun tree ->
    fold ~init:[]
      ~f_merge:(fun acc a ->
        match a with
        | _, Merge.Job.Full {status= Job_status.Done; _} ->
            acc
        | _ ->
            New_job.Merge a :: acc )
      ~f_base:(fun acc d ->
        match d with
        | _, Base.Job.Full {status= Job_status.Done; _} ->
            acc
        | _ ->
            New_job.Base d :: acc )
      tree
    |> List.rev

  let to_jobs :
      ('merge_t, 'base_t) t -> ('merge_job, 'base_job) Available_job.t list =
   fun tree ->
    fold ~init:[]
      ~f_merge:(fun acc a ->
        match a with
        | _weight, Merge.Job.Full {left; right; status= Todo; _} ->
            Available_job.Merge (left, right) :: acc
        | _ ->
            acc )
      ~f_base:(fun acc d ->
        match d with
        | _weight, Base.Job.Full {job; status= Todo; _} ->
            Available_job.Base job :: acc
        | _ ->
            acc )
      tree
    |> List.rev

  let leaves : ('merge_t, 'base_t) t -> 'base_job list =
   fun tree ->
    fold_depth ~init:[]
      ~f_merge:(fun _ _ _ -> [])
      ~f_base:(fun acc d ->
        match d with _, Base.Job.Full {job; _} -> job :: acc | _ -> acc )
      tree
    |> List.rev

  let rec view_tree : type merge_t base_t.
         (merge_t, base_t) t
      -> show_merge:(merge_t -> string)
      -> show_base:(base_t -> string)
      -> string =
   fun tree ~show_merge ~show_base ->
    match tree with
    | Leaf d ->
        sprintf !"Leaf %s\n" (show_base d)
    | Node {value; sub_tree; _} ->
        let curr = sprintf !"Node %s\n" (show_merge value) in
        let subtree =
          view_tree sub_tree
            ~show_merge:(fun (x, y) ->
              sprintf !"%s  %s" (show_merge x) (show_merge y) )
            ~show_base:(fun (x, y) ->
              sprintf !"%s  %s" (show_base x) (show_base y) )
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
        type ('merge, 'base) t =
          { trees:
              ( 'merge Merge.Stable.V1.t
              , 'base Base.Stable.V1.t )
              Tree.Stable.V1.t
              Non_empty_list.Stable.V1.t
                (*use non empty list*)
          ; acc: ('merge * 'base list) option
                (*last emitted proof and the corresponding transactions*)
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

  type ('merge, 'base) t = ('merge, 'base) Stable.Latest.t =
    { trees:
        ('merge Merge.Stable.V1.t, 'base Base.Stable.V1.t) Tree.Stable.V1.t
        Non_empty_list.Stable.V1.t
    ; acc: ('merge * 'base list) option
          (*last emitted proof and the corresponding transactions*)
    ; curr_job_seq_no: int
    ; max_base_jobs: int
    ; delay: int }
  [@@deriving sexp]

  let create_tree_for_level ~level ~depth ~merge_job ~base_job =
    let rec go : type merge_t base_t.
        int -> (int -> merge_t) -> base_t -> (merge_t, base_t) Tree.t =
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
        (weight, merge_job) )
      (base_weight, base_job)

  let create_tree ~depth =
    create_tree_for_level ~level:depth ~depth ~merge_job:Merge.Job.Empty
      ~base_job:Base.Job.Empty

  let empty : type merge base.
      max_base_jobs:int -> delay:int -> (merge, base) t =
   fun ~max_base_jobs ~delay ->
    let depth = Int.ceil_log2 max_base_jobs in
    let first_tree = create_tree ~depth in
    { trees= Non_empty_list.singleton first_tree
    ; acc= None
    ; curr_job_seq_no= 0
    ; max_base_jobs
    ; delay }

  let delay : type merge base. (merge, base) t -> int = fun t -> t.delay

  let max_base_jobs : type merge base. (merge, base) t -> int =
   fun t -> t.max_base_jobs
end

module type State_intf = sig
  type ('merge, 'base) t

  val empty : max_base_jobs:int -> delay:int -> ('merge, 'base) t

  val max_base_jobs : ('merge, 'base) t -> int

  val delay : ('merge, 'base) t -> int
end

module type State_monad_intf = functor (State : State_intf) -> sig
  include Monad.S3

  val run_state :
       ('a, 'merge, 'base) t
    -> state:('merge, 'base) State.t
    -> ('a * ('merge, 'base) State.t) Or_error.t

  val eval_state :
    ('a, 'merge, 'base) t -> state:('merge, 'base) State.t -> 'a Or_error.t

  val exec_state :
       ('a, 'merge, 'base) t
    -> state:('merge, 'base) State.t
    -> ('merge, 'base) State.t Or_error.t

  val get : (('merge, 'base) State.t, 'merge, 'base) t

  val put : ('merge, 'base) State.t -> (unit, 'merge, 'base) t

  val error_if : bool -> message:string -> (unit, _, _) t
end

module Make_state_monad : State_monad_intf =
functor
  (State : State_intf)
  ->
  struct
    module T = struct
      type ('merge, 'base) state = ('merge, 'base) State.t

      type ('a, 'merge, 'base) t =
        ('merge, 'base) state -> ('a * ('merge, 'base) state) Or_error.t

      let return : type a merge base. a -> (a, merge, base) t =
       fun a s -> Ok (a, s)

      let bind m ~f = function
        | s ->
            let open Or_error.Let_syntax in
            let%bind a, s' = m s in
            f a s'

      let map = `Define_using_bind
    end

    include T
    include Monad.Make3 (T)

    let get (*: type merge base. ((merge, base) state, merge, base) t*) =
      function
      | s ->
          Ok (s, s)

    let put s = function _ -> Ok ((), s)

    let run_state t ~state = t state

    let error_if b ~message =
      if b then fun _ -> Or_error.error_string message else return ()

    let eval_state t ~state =
      let open Or_error.Let_syntax in
      let%map b, _ = run_state t ~state in
      b

    let exec_state t ~state =
      let open Or_error.Let_syntax in
      let%map _, s = run_state t ~state in
      s
  end

module State = struct
  include T
  module Hash = Hash

  let hash {trees; acc; max_base_jobs; curr_job_seq_no; delay; _} f_merge
      f_base =
    let h = ref (Digestif.SHA256.init ()) in
    let add_string s = h := Digestif.SHA256.feed_string !h s in
    let () =
      let tree_acc = Buffer.create 0 in
      let buff a = Buffer.add_string tree_acc a in
      let tree_hash tree f_merge f_base =
        List.iter (Tree.to_hashable_jobs tree) ~f:(fun job ->
            match job with New_job.Merge a -> f_merge a | Base d -> f_base d )
      in
      let () =
        Non_empty_list.iter trees ~f:(fun tree ->
            let w_to_string (l, r) = Int.to_string l ^ Int.to_string r in
            let f_merge = function
              | w, Merge.Job.Empty ->
                  buff (w_to_string w ^ "Empty")
              | w, Merge.Job.Full {left; right; status; seq_no} ->
                  buff
                    ( w_to_string w ^ "Full" ^ Int.to_string seq_no
                    ^ Job_status.to_string status ) ;
                  buff (f_merge left) ;
                  buff (f_merge right)
              | w, Merge.Job.Part j ->
                  buff (w_to_string w ^ "Part") ;
                  buff (f_merge j)
            in
            let f_base = function
              | w, Base.Job.Empty ->
                  buff (Int.to_string w ^ "Empty")
              | w, Base.Job.Full {job; status; seq_no} ->
                  buff
                    ( Int.to_string w ^ "Full" ^ Int.to_string seq_no
                    ^ Job_status.to_string status ) ;
                  buff (f_base job)
            in
            tree_hash tree f_merge f_base )
      in
      add_string (Buffer.contents tree_acc)
    in
    let acc_string =
      Option.value_map acc ~default:"None" ~f:(fun (a, d_lst) ->
          f_merge a ^ List.fold ~init:"" d_lst ~f:(fun acc d -> acc ^ f_base d)
      )
    in
    add_string acc_string ;
    add_string (Int.to_string curr_job_seq_no) ;
    add_string (Int.to_string max_base_jobs) ;
    add_string (Int.to_string delay) ;
    Digestif.SHA256.get !h

  module Make_foldable (M : Monad.S) = struct
    module Tree_foldable = Tree.Make_foldable (M)

    let fold_chronological_until :
           ('merge, 'base) t
        -> init:'acc
        -> f_merge:(   'acc
                    -> 'merge Merge.t
                    -> ('acc, 'final) Continue_or_stop.t M.t)
        -> f_base:(   'acc
                   -> 'base Base.t
                   -> ('acc, 'final) Continue_or_stop.t M.t)
        -> finish:('acc -> 'final M.t)
        -> 'final M.t =
     fun t ~init ~f_merge ~f_base ~finish ->
      let open M.Let_syntax in
      let open Container.Continue_or_stop in
      let work_trees = Non_empty_list.rev t.trees |> Non_empty_list.to_list in
      let rec go acc = function
        | [] ->
            M.return (Continue acc)
        | tree :: trees -> (
            match%bind
              Tree_foldable.fold_depth_until'
                ~f_merge:(fun _ -> f_merge)
                ~f_base ~init:acc tree
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

  let fold_chronological t ~init ~f_merge ~f_base =
    let open Container.Continue_or_stop in
    Foldable_ident.fold_chronological_until t ~init
      ~f_merge:(fun acc a -> Continue (f_merge acc a))
      ~f_base:(fun acc d -> Continue (f_base acc d))
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

let max_trees : ('merge, 'base) t -> int =
 fun t -> ((Int.ceil_log2 t.max_base_jobs + 1) * (t.delay + 1)) + 1

let work_to_do : type merge base.
       (merge Merge.t, base Base.t) Tree.t list
    -> max_base_jobs:int
    -> (merge, base) Available_job.t list =
 fun trees ~max_base_jobs ->
  let depth = Int.ceil_log2 max_base_jobs in
  List.concat_mapi trees ~f:(fun i tree ->
      Tree.jobs_on_level ~depth ~level:(depth - i) tree )

let work : type merge base.
       (merge Merge.t, base Base.t) Tree.t list
    -> delay:int
    -> max_base_jobs:int
    -> (merge, base) Available_job.t list =
 fun trees ~delay ~max_base_jobs ->
  let depth = Int.ceil_log2 max_base_jobs in
  let work_trees =
    List.take
      (List.filteri trees ~f:(fun i _ -> i % delay = delay - 1))
      (depth + 1)
  in
  work_to_do work_trees ~max_base_jobs

let work_for_current_tree t =
  let delay = t.delay + 1 in
  work (Non_empty_list.tail t.trees) ~max_base_jobs:t.max_base_jobs ~delay

(*work on all the level and all the trees*)
let all_work : type merge base.
    (merge, base) t -> (merge, base) Available_job.t list list =
 fun t ->
  let depth = Int.ceil_log2 t.max_base_jobs in
  let set1 = work_for_current_tree t in
  let _, other_sets =
    List.fold ~init:(t, []) (List.init ~f:Fn.id t.delay)
      ~f:(fun (t, work_list) _ ->
        let trees' = Non_empty_list.cons (create_tree ~depth) t.trees in
        let t' = {t with trees= trees'} in
        let work = work_for_current_tree t' in
        (t', work :: work_list) )
  in
  set1 :: List.rev other_sets

let work_for_next_update : type merge base.
       (merge, base) t
    -> data_count:int
    -> (merge, base) Available_job.t list list =
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

let add_merge_jobs : completed_jobs:'merge list -> (_, 'merge, _) State_monad.t
    =
 fun ~completed_jobs ->
  let open State_monad.Let_syntax in
  if List.length completed_jobs = 0 then return None
  else
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
            (*TODO: dont update if required job count is zero*)
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

let add_data : data:'base list -> (_, _, 'base) State_monad.t =
 fun ~data ->
  let open State_monad.Let_syntax in
  if List.length data = 0 then return ()
  else
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
        { state with
          trees= append updated_trees (Non_empty_list.tail state.trees) }
    in
    ()

let incr_sequence_no = function
  | state ->
      let open State_monad in
      put {state with curr_job_seq_no= state.curr_job_seq_no + 1}

let update_helper :
       data:'base list
    -> completed_jobs:'merge list
    -> ('a, 'merge, 'base) State_monad.t =
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
  (*Possible that new base jobs is added to a new tree within an update i.e., part of it is added to the first tree and the rest of it to a new tree. This happens when the throughput is not max. This also requires merge jobs to be done on two different set of trees*)
  let data1, data2 = List.split_n data available_space in
  let required_jobs_for_current_tree =
    work (Non_empty_list.tail t.trees) ~max_base_jobs:t.max_base_jobs ~delay
    |> List.length
  in
  let jobs1, jobs2 =
    List.split_n completed_jobs required_jobs_for_current_tree
  in
  (*update first set of jobs and data*)
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
       data:'base list
    -> completed_jobs:'merge list
    -> ('merge, 'base) t
    -> (('merge * 'base list) option * ('merge, 'base) t) Or_error.t =
 fun ~data ~completed_jobs state ->
  State_monad.run_state (update_helper ~data ~completed_jobs) ~state

(*let next_k_jobs ~state ~k =
  let work = all_work state |> List.concat in
  if k > List.length work then
    Or_error.errorf "You asked for %d jobs, but I only have %d available" k
      (List.length work)
  else Ok (List.take work k)*)

let all_jobs t = all_work t

let jobs_for_next_update t = work_for_next_update t ~data_count:t.max_base_jobs

let free_space t = t.max_base_jobs

let last_emitted_value t = t.acc

let current_job_sequence_number t = t.curr_job_seq_no

let base_jobs_on_latest_tree t =
  let depth = Int.ceil_log2 t.max_base_jobs in
  List.filter_map
    (Tree.jobs_on_level ~depth ~level:depth (Non_empty_list.head t.trees))
    ~f:(fun job -> match job with Base d -> Some d | Merge _ -> None)

let partition_if_overflowing : ('merge, 'base) t -> Space_partition.t =
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

let is_valid _ = failwith ""

let view_jobs_with_position (_t : ('merge, 'base) State.t) _fa _fd =
  failwith "TODO"

let%test_module "test" =
  ( module struct
    let%test_unit "always max base jobs" =
      let max_base_jobs = 512 in
      let state = empty ~max_base_jobs ~delay:3 in
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
      let max_base_jobs = 512 in
      let t = empty ~max_base_jobs ~delay:3 in
      let state = ref t in
      Quickcheck.test
        (Quickcheck.Generator.list (Int.gen_incl 1 1))
        ~f:(fun list ->
          let t' = !state in
          let data = List.take list max_base_jobs in
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
