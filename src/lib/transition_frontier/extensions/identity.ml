open Frontier_base

(* TODO: refactor out, this is a leak in the abstraction of extensions *)
module T = struct
  type t = unit

  type view = Diff.Full.E.t list

  let create ~logger:_ _ = ((), [])

  let handle_diffs () _ diffs : view option = Some diffs
end

include T
module Broadcasted = Functor.Make_broadcasted (T)
