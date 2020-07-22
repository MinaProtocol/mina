open Intf

module type Inputs_intf = sig
  module Verifier_index : T0

  module Field : sig
    include Type_with_delete

    module Vector : sig
      include Vector_with_gc with type elt = t

      module Triple : Triple with type elt := t
    end
  end

  module Proof : sig
    type t

    module Challenge_polynomial : T0

    module Backend : sig
      type t
    end

    val to_backend :
      Challenge_polynomial.t list -> Field.t list -> t -> Backend.t
  end

  module Backend : sig
    include Type_with_delete

    val create_without_finaliser : Verifier_index.t -> Proof.Backend.t -> t

    val alpha : t -> Field.t

    val eta_a : t -> Field.t

    val eta_b : t -> Field.t

    val eta_c : t -> Field.t

    val beta1 : t -> Field.t

    val beta2 : t -> Field.t

    val beta3 : t -> Field.t

    val polys : t -> Field.t

    val evals : t -> Field.t

    val opening_prechallenges : t -> Field.Vector.t

    val x_hat_nocopy : t -> Field.Vector.Triple.t

    val digest_before_evaluations : t -> Field.t
  end
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  let create vk prev_challenge input (pi : Proof.t) =
    let pi = Proof.to_backend prev_challenge input pi in
    let t = Backend.create_without_finaliser vk pi in
    Caml.Gc.finalise Backend.delete t ;
    t

  let field f t =
    let x = f t in
    Caml.Gc.finalise Field.delete x ;
    x

  let scalar_challenge f t = Pickles_types.Scalar_challenge.create (field f t)

  let fieldvec f t =
    let x = f t in
    Caml.Gc.finalise Field.Vector.delete x ;
    x

  open Backend

  let alpha = field alpha

  let eta_a = field eta_a

  let eta_b = field eta_b

  let eta_c = field eta_c

  let beta1 = scalar_challenge beta1

  let beta2 = scalar_challenge beta2

  let beta3 = scalar_challenge beta3

  let polys = scalar_challenge polys

  let evals = scalar_challenge evals

  (* TODO: Leaky *)
  let opening_prechallenges t =
    let t = opening_prechallenges t in
    Array.init (Field.Vector.length t) (fun i ->
        Pickles_types.Scalar_challenge.create (Field.Vector.get t i) )

  let x_hat t =
    let t = x_hat_nocopy t in
    let fqv f = Field.Vector.get (fieldvec f t) 0 in
    Field.Vector.Triple.(fqv f0, fqv f1, fqv f2)

  let digest_before_evaluations = field digest_before_evaluations
end
