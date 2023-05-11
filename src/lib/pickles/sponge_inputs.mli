module Make
    (Impl : Snarky_backendless.Snark_intf.Run) (B : sig
      val params : Impl.field Sponge.Params.t

      val to_the_alpha : Impl.field -> Impl.field

      module Operations : sig
        val apply_affine_map :
             Impl.field array array * Impl.field array
          -> Impl.field array
          -> Impl.field array
      end
    end) : Sponge.Intf.Permutation with module Field = Impl.Field
