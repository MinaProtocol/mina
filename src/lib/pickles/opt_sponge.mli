(* Undocumented *)

type 'f sponge_state =
  | Absorbing of
      { next_index : 'f Snarky_backendless.Boolean.t
      ; xs : ('f Snarky_backendless.Boolean.t * 'f) list
      }
  | Squeezed of int

type 'f t =
  { mutable state : 'f array
  ; params : 'f Sponge.Params.t
  ; needs_final_permute_if_empty : bool
  ; mutable sponge_state : 'f sponge_state
  }

module Make
    (Impl : Snarky_backendless.Snark_intf.Run)
    (P : Sponge.Intf.Permutation with type Field.t = Impl.Field.t) : sig
  type nonrec t = Impl.Field.t t

  val create : ?init:Impl.Field.t array -> Impl.Field.t Sponge.Params.t -> t

  val of_sponge : Impl.Field.t Sponge.t -> t

  val absorb :
    t -> Impl.Field.t Snarky_backendless.Boolean.t * Impl.Field.t -> unit

  val squeeze : t -> Impl.Field.t
end
