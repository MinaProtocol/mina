type 'f sponge_state =
  | Absorbing of
      { next_index : 'f Snarky_backendless.Boolean.t
      ; xs : ('f Snarky_backendless.Boolean.t * 'f) list
      }
  | Squeezed of int

type 'f t =
  { mutable state : 'f array
  ; params : 'f Sponge.Params.t
  ; mutable needs_final_permute_if_empty : bool
  ; mutable sponge_state : 'f sponge_state
  }

module Make
    (Impl : Snarky_backendless.Snark_intf.Run)
    (_ : Sponge.Intf.Permutation with type Field.t = Impl.Field.t) : sig
  type nonrec t = Impl.Field.t t

  val create : ?init:Impl.Field.t array -> Impl.Field.t Sponge.Params.t -> t

  (** Create a new sponge with state copied from the given sponge.
      In particular, this copies the underlying state array, so that any
      mutations to the copy will not affect the original.
  *)
  val copy : t -> t

  val of_sponge : Impl.Field.t Sponge.t -> t

  val absorb :
    t -> Impl.Field.t Snarky_backendless.Boolean.t * Impl.Field.t -> unit

  val squeeze : t -> Impl.Field.t

  (** Updates the sponge state by forcing absorption of all 'pending' field
      elements passed to [absorb].
      This method runs logic equivalent to that in the [squeeze] method, but
      without transitioning the state.
      This method can be used with [copy] to create a fork of a sponge where
      one of the branches calls the [absorb] method and the other does not.
  *)
  val consume_all_pending : t -> unit

  (** Recombines a forked copy of a sponge with the original.
      When the boolean value is true, the sponge state will be preserved;
      otherwise it will be overwritten by the state of the original sponge.

      When an optional [squeeze] has ocurred, both the original and forked
      sponges have called [consume_all_pending] before the squeeze, and must
      subsequently absorb the same value or values, to bring their internal
      states back into alignment. 1 value is sufficient, but it is slightly
      more efficient to absorb 2.

      This enables optional absorption for sponges. For example:
{[
      let original_sponge = Opt_sponge.copy sponge in
      let squeezed = Opt_sponge.squeeze sponge in
      Opt_sponge.absorb sponge x_opt ;
      Opt_sponge.absorb original_sponge x_opt ;
      Opt_sponge.recombine ~original_sponge b sponge
]}
  *)
  val recombine : original_sponge:t -> Impl.Boolean.var -> t -> unit
end
