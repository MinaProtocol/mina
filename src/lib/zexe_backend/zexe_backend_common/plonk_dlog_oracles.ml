open Intf

module type Inputs_intf = sig
  module Verifier_index : T0

  module Field : sig
    include Type_with_delete

    module Vector : sig
      include Vector with type elt = t

      module Triple : Triple with type elt := t
    end
  end

  module Proof : sig
    type t

    module Backend : sig
      type t
    end

    val to_backend : Field.t list -> t -> Backend.t
  end

  module Backend : sig
    include Type_with_delete

    val create : Verifier_index.t -> Proof.Backend.t -> t

    val opening_prechallenges : t -> Field.Vector.t

    val alpha : t -> Field.t

    val beta : t -> Field.t

    val gamma : t -> Field.t

    val zeta : t -> Field.t

    val v : t -> Field.t

    val u : t -> Field.t

    val p_eval_1 : t -> Field.t

    val p_eval_2 : t -> Field.t
  end
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  let create vk input (pi : Proof.t) =
    let pi = Proof.to_backend input pi in
    let t = Backend.create vk pi in
    Caml.Gc.finalise Backend.delete t ;
    t

  let field f t =
    let x = f t in
    Caml.Gc.finalise Field.delete x ;
    x

  open Backend

  let alpha = field alpha

  let beta = field beta

  let gamma = field gamma

  let zeta = field zeta

  let v = field v

  let u = field u

  let p_eval_1 = field p_eval_1

  let p_eval_2 = field p_eval_2

  let opening_prechallenges t =
    let t = opening_prechallenges t in
    Array.init (Field.Vector.length t) (fun i ->
        Pickles_types.Scalar_challenge.create (Field.Vector.get t i) )
end
