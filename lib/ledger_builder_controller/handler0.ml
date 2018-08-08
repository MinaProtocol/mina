open Core_kernel

module type S = sig
  type transition

  type heavy

  module Transition_tree : Ktree.S with type elem := transition

  type t =
    { locked_tip: heavy
    ; longest_branch_tip: heavy
    ; ktree: Transition_tree.t option
    (* TODO: This impl assumes we have the original Ouroboros assumption. In
       order to work with the Praos assumption we'll need to keep a linked
       list as well at the prefix of size (#blocks possible out of order)
     *)
    }
  [@@deriving fields, bin_io]

  module Change : sig
    type t =
      | Locked_tip of heavy
      | Longest_branch_tip of heavy
      | Ktree of Transition_tree.t
  end

  val apply : t -> Change.t -> t

  val apply_all : t -> Change.t list -> t

  val create : heavy -> t
end

module Make (Heavy : sig
  type t [@@deriving bin_io]
end) (Transition : sig
  type t [@@deriving eq, compare, sexp, bin_io]
end) :
  S with type heavy := Heavy.t and type transition := Transition.t =
struct
  module Transition_tree =
    Ktree.Make (Transition)
      (struct
        let k = 50
      end)

  module Change = struct
    type t =
      | Locked_tip of Heavy.t
      | Longest_branch_tip of Heavy.t
      | Ktree of Transition_tree.t
  end

  open Change

  type t =
    { locked_tip: Heavy.t
    ; longest_branch_tip: Heavy.t
    ; ktree: Transition_tree.t option
    (* TODO: This impl assumes we have the original Ouroboros assumption. In
       order to work with the Praos assumption we'll need to keep a linked
       list as well at the prefix of size (#blocks possible out of order)
     *)
    }
  [@@deriving fields, bin_io]

  let apply t = function
    | Locked_tip h -> {t with locked_tip= h}
    | Longest_branch_tip h -> {t with longest_branch_tip= h}
    | Ktree k -> {t with ktree= Some k}

  let apply_all t changes = List.fold changes ~init:t ~f:apply

  let create genesis_heavy =
    {locked_tip= genesis_heavy; longest_branch_tip= genesis_heavy; ktree= None}
end
