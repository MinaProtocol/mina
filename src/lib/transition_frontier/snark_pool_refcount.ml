open Core_kernel
open Protocols
open Coda_transition_frontier

module type S = Transition_frontier_extension_intf

module Make
    (Transition_frontier : Transition_frontier0.S) (Work : sig
        type t [@@deriving sexp, bin_io]

        include Hashable.S_binable with type t := t
    end) :
  S
  with type transition_frontier := Transition_frontier.t
   and type transition_frontier_breadcrumb := Transition_frontier.Breadcrumb.t =
struct
  type t = {ref_table: int Work.Table.t}

  let create () = {ref_table= Work.Table.create ()}

  (* TODO: implement diff-handling functionality *)
  let handle_diff (_t : t) _frontier
      (_diff : Transition_frontier.Breadcrumb.t Transition_frontier_diff.t) =
    ()
end
