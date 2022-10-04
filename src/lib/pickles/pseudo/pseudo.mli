(* Pseudo *)

module Make (Impl : Snarky_backendless.Snark_intf.Run) : sig
  type ('a, 'n) t =
    'n One_hot_vector.T(Impl).t * ('a, 'n) Pickles_types.Vector.t

  val seal : Impl.Field.t -> Impl.Field.t

  val mask :
       'n One_hot_vector.T(Impl).t
    -> (Impl.Field.t, 'n) Pickles_types.Vector.t
    -> Impl.Field.t

  val choose : ('a, 'n) t -> f:('a -> Impl.Field.t) -> Impl.Field.t

  module Degree_bound : sig
    type nonrec 'n t = (int, 'n) t

    val shifted_pow : crs_max_degree:int -> 'a t -> Impl.Field.t -> Impl.Field.t
  end

  module Domain : sig
    val num_shifts : int

    (** Compute the 'shifts' used by the kimchi permutation argument.

        These values are selected deterministically-randomly to appear outside
        of the domain, so that every choice of [i] and [shift] results in a
        distinct value for [shift * domain_generator ^ i].

        Note that, for each different domain size, we attempt to use the same
        [shifts], and only sample different ones if the shifts are already a
        member of the domain (ie. there exists some [i] such that
        [shift = domain_generator ^ i]). This ensures that the invariant above
        is satisfied.
        Optimisation: since the shifts for the domains that we use in practise
        are all the same -- none of them have 2-adic order < largest domain
        size -- we can hard-code the shifts instead of using a one-hot mask,
        and this function adds no constraints to the circuit.
    *)
    val shifts :
         'n Degree_bound.t
      -> shifts:(log2_size:int -> Impl.Field.Constant.t array)
      -> Impl.Field.t Pickles_types.Plonk_types.Shifts.t

    val generator :
         'n Degree_bound.t
      -> domain_generator:(log2_size:int -> Impl.Field.t)
      -> Impl.Field.t

    type nonrec 'n t = (Plonk_checks.Domain.t, 'n) t

    val to_domain :
         shifts:(log2_size:int -> Impl.Field.Constant.t array)
      -> domain_generator:(log2_size:int -> Impl.Field.t)
      -> 'n t
      -> Impl.Field.t Plonk_checks.plonk_domain
  end
end
