open Frontier_base

(* TODO: refactor out, this is a leak in the abstraction of extensions *)
module T = struct
  type t = unit

  type view = Diff.Full.With_mutant.t list

  let name = "identity"

  let create ~logger:_ _ = ((), [])

  let handle_diffs () _ diffs_with_mutants : view option =
    Some diffs_with_mutants
end

include T
module Broadcasted = Functor.Make_broadcasted (T)
