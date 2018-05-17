open Core_kernel
open Async_kernel

module Constraint_count = Constraint_count

module type Proof_intf = sig
  type input
  type t
  [@@deriving eq, bin_io]

  include Constraint_count.Cost_s with type t := t
  val verify : t -> input -> bool Deferred.t
end

module type S = sig
  type t
  type work
  type work_unit
  type proof
  module With_path : sig
    type 'a t
    val data : 'a t -> 'a
  end

  module Evidence : sig
    type t
    val create : work With_path.t -> proof -> t
  end

  val create : unit -> t

  include Constraint_count.Free_s with type t := t

  (* Applies as many work_units as possible that are paid for by
   * proofs and returns any work_units for which we didn't have
   * enough budget *)
  val submit : t -> units:work_unit list -> proofs:Evidence.t list -> work_unit list
  val work : t -> geq:Constraint_count.t -> work With_path.t list Or_error.t
end

module Make
 (Work_unit : sig
   type t [@@deriving eq, bin_io]
   include Constraint_count.Cost_s with type t := t
 end)
 (Proof : Proof_intf with type input := Work_unit.t)
 (Work : Work_intf.S with type proof := Proof.t and type input := Work_unit.t) : S with type work := Work.t
               and type work_unit := Work_unit.t
               and type proof := Proof.t
= struct
  module Tree =
    Tree.Make(Work_unit)(Proof)(Work)(struct let cost = 4 end)

  module With_path = Tree.With_path
  module Evidence = Tree.Evidence

  type t =
    { mutable tree : Tree.t option
    ; mutable buffer : Work_unit.t Buffer.t
    }
  [@@deriving bin_io]

  let empty_buffer = Buffer.empty ~max_size:1024

  let create () =
    (* Invariant: Tree is only None before pipeline is full.
     * When pipeline is full it's never None again *)
    { tree = None
    (* TODO: What should be the max size *)
    ; buffer = empty_buffer
    }

  (* mutates t ; returns new tree *)
  let rebuild_tree t data =
    let tree = Tree.create ~data in
    t.tree <- Some tree;
    t.buffer <- empty_buffer;
    tree

  let free t =
    match t.tree with
    | None -> Constraint_count.max_value
    | Some tree -> (Tree.free tree) - (Buffer.sum (module Int) t.buffer ~f:Work_unit.cost)

  let submit t ~units ~proofs =
    let exists_a_tree tree units =
      let new_tree_option, leftovers = Tree.attempt_prove tree proofs in
      let new_tree =
        match new_tree_option with
        | None -> rebuild_tree t (Buffer.drain t.buffer)
        | Some tree -> tree
      in
      let positive_constraints = (Tree.free new_tree) - (Tree.free tree) in
      let cheapest_first = List.sort ~cmp:(fun u u' -> Int.compare (Work_unit.cost u) (Work_unit.cost u')) units in
      (* TODO: Remove once I make sure compare works the way I think *)
      if (List.length cheapest_first >= 2) then begin
        let first = Work_unit.cost (List.nth_exn cheapest_first 0) in
        let second = Work_unit.cost (List.nth_exn cheapest_first 1) in
        assert (first < second)
      end;

      let fold_result =
        List.fold_until
          cheapest_first
          ~init:(positive_constraints, units, [])
          ~f:(fun (budget, units, to_apply) x ->
            match units with
            | [] -> Stop ([], to_apply)
            | u::rest ->
              let new_budget = budget - (Work_unit.cost u) in
              if new_budget >= 0 then
                Continue (new_budget, rest, u::to_apply)
              else
                Stop (u::rest, to_apply)
          )
      in

      let (to_apply, leftover_units) =
        match fold_result with
        | Finished (_, units, to_apply) -> (List.rev to_apply, units)
        | Stopped_early (units, to_apply) -> (List.rev to_apply, units)
      in
      match Buffer.add_all t.buffer to_apply with
      | `Next b ->
          t.buffer <- b;
          t.tree <- Some new_tree;
          leftover_units
      | `Full (data, spill) ->
          (* TODO: Handle tree merges here!! *)
          (* Unfortunately I don't see a way around it *)
          let new_tree = rebuild_tree t data in
          match Buffer.add_all empty_buffer spill with
          | `Next b ->
              t.buffer <- b;
              (* For now, we're just going to overwrite the existing tree *)
              t.tree <- Some new_tree;
              leftover_units
          | `Full _ -> failwith "Submit fewer units! Don't submit more than max_buffer_size work units at one time!"
    in
    match t.tree with
    | None ->
      (match Buffer.add_all t.buffer units with
      | `Next b ->
          t.buffer <- b;
          []
      | `Full (data, spill) ->
          let new_tree = rebuild_tree t data in
          exists_a_tree new_tree spill)
    | Some tree -> exists_a_tree tree units

  let work t ~geq =
    match t.tree with
    | None -> Or_error.return []
    | Some tree ->
        (match Tree.random tree ~geq with
        | Stopped_early works -> Or_error.return works
        | Finished (budget, works) ->
            let tree = rebuild_tree t (Buffer.drain t.buffer) in
            (match Tree.random tree ~geq:budget with
            | Stopped_early works' -> Or_error.return (works @ works')
            | Finished (budget, _) ->
              Or_error.errorf "Too much work requested! Even after rebuilding the tree, %d contraints couldn't be snarked" budget
            )
        )
end


