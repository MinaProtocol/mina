(** This implements a functor to instantiate a {{
    https://en.wikipedia.org/wiki/Substitution%E2%80%93permutation_network } SPN
    } used in sponge construction.

    A Substitution-Permutation Network consists of applying consecutively a non-linear
    operation, a linear operation and adding some constants on a state S. Hash
    functions like the SHA family, Poseidon, Rescue and others are based on this
    generic construction, and consists of applying N times the same permutation
    on an initial state S.
*)

module Make
    (Impl : Snarky_backendless.Snark_intf.Run) (_ : sig
      (** The parameters of the permutation *)
      val params : Impl.field Sponge.Params.t

      (** The exponent used in the SBOX *)
      val to_the_alpha : Impl.field -> Impl.field

      (** Internal operations of the permutation *)
      module Operations : sig
        (** [apply_affine_map (mds, rc) state] computes the linear layer of the
            permutation using the matrix [MDS] and the round constants [rc] with the
            state [state] *)
        val apply_affine_map :
             Impl.field array array * Impl.field array
          -> Impl.field array
          -> Impl.field array
      end
    end) : Sponge.Intf.Permutation with module Field = Impl.Field
