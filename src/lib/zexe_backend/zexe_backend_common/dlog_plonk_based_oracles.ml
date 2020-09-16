open Intf

module type Inputs_intf = sig
  module Verifier_index : T0

  module Field : sig
    include Type_with_delete

    module Vector : sig
      include Vector with type elt = t

      module Double : Double with type elt := t
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

    val create : Verifier_index.t -> Proof.Backend.t -> t

    val beta : t -> Field.t

    val gamma : t -> Field.t

    val alpha : t -> Field.t

    val zeta : t -> Field.t

    val v : t -> Field.t

    val u : t -> Field.t

    val opening_prechallenges : t -> Field.Vector.t

    val p_nocopy : t -> Field.Vector.Double.t

    val digest_before_evaluations : t -> Field.t
  end
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  let create vk prev_challenge input (pi : Proof.t) =
    let pi = Proof.to_backend prev_challenge input pi in
    let t = Backend.create vk pi in
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

  let beta = field beta

  let gamma = field gamma

  let alpha = field alpha

  let zeta = field zeta

  let v = scalar_challenge v

  let u = scalar_challenge u

  (* TODO: Leaky *)
  let opening_prechallenges t =
    let t = opening_prechallenges t in
    Array.init (Field.Vector.length t) (fun i ->
        Pickles_types.Scalar_challenge.create (Field.Vector.get t i) )

  let p t =
    let t = p_nocopy t in
    let fqv f = Field.Vector.get (fieldvec f t) 0 in
    Field.Vector.Double.(fqv f0, fqv f1)

  let digest_before_evaluations = field digest_before_evaluations
end
