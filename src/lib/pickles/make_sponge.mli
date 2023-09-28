(** This module provides interfaces and functors to instantiate a hash function
    built from a permutation and the {{
    https://en.wikipedia.org/wiki/Sponge_function} sponge construction }.

    The interfaces have been created to be used with permutations consisting of
    partial and full rounds, like {{ https://eprint.iacr.org/2019/458.pdf}
    Poseidon }.
*)

module Rounds : sig
  (** Number of full rounds for the permutation *)
  val rounds_full : int

  (** If this is set to [true], rounds constants will be added before running a
      round of the permutation. If set to [false], applies the standard
      construction S-BOX -> MDS -> ARK. *)
  val initial_ark : bool

  (** Number of partial rounds for the permutation *)
  val rounds_partial : int
end

(** {2 Module type} *)

module type S = sig
  module Inputs : sig
    include module type of Rounds

    module Field : Kimchi_backend.Field.S

    type field := Field.t

    (** [to_the_alpha x] returns [x^alpha] where [alpha] is a security parameter
        of the permutation used for the S-BOX *)
    val to_the_alpha : field -> field

    (** Exponent used in the S-BOX *)
    val alpha : int

    module Operations : Sponge.Intf.Operations with type Field.t = field
  end

  (** Type alias to make it easier to read the type signatures below. *)
  type field := Inputs.Field.t

  module F := Sponge.Poseidon(Inputs).Field

  (* TODO:  This should be defined as something like
     Sponge.Intf.Sponge with module Field = F
     and module State = Sponge.State
     and type input = F.t
     and type digest = F.t
     and type t = F.t Sponge.t
     alas, type t needs to be exposed
  *)
  module Field : sig
    type f := F.t

    (** Parameters for the permutation *)
    type params := f Sponge.Params.t

    (** Represents the state of the permutation. The capacity is always [1]. *)
    type state := f Sponge.State.t

    (** Represents the state of the sponge construction. It includes information like:
        - the permutation parameters (linear layer, number of rounds, constants, etc)
        - the sponge configuration
        - an internal ID to differentiate each new instance. It is currently used only
          for debugging purposes
    *)
    type t = f Sponge.t
    (* TODO: Make this type abstract *)

    (** [create ?init params] creates a new sponge state and initializes the
        permutation state with a fresh copy of [init]. If [init] is [None], the
        initial permutation state is set to [F.zero]. *)
    val create : ?init:state -> params -> t

    (** [make state params sponge_state] returns a new sponge state. The
        permutation state is initialized to a fresh copy of [state]. [params] are
        the parameters for the internal permutation. *)
    val make :
      state:state -> params:params -> sponge_state:Sponge.sponge_state -> t

    (** [absorb state x] "absorbs" the field element [f] into the sponge state [state]
        The sponge state [state] is modified *)
    val absorb : t -> f -> unit

    (** [squeeze state] squeezes the sponge state [state].
        The sponge state [state] is modified *)
    val squeeze : t -> f

    (** [copy state] returns a fresh copy of the sponge state [state] *)
    val copy : t -> t

    (** [state sponge_state] returns a fresh copy of the permutation state
        contained in the sponge state [sponge_state] *)
    val state : t -> state
  end

  module Bits : sig
    type t

    val create : ?init:field Sponge.State.t -> field Sponge.Params.t -> t

    val absorb : t -> field -> unit

    val squeeze : t -> length:int -> bool list

    val copy : t -> t

    val state : t -> field Sponge.State.t

    val squeeze_field : t -> field
  end

  (** [digest sponge_params elmts] is equivalent to absorbing one by one each
      element of the array [elmts] followed by a call to squeeze with a sponge
      construction instantiated with the parameters [sponge_params] *)
  val digest :
       field Sponge.Params.t
    -> field array
    -> (int64, Composition_types.Digest.Limbs.n) Pickles_types.Vector.t
end

(** {2 Functors} *)

module Make (Field : Kimchi_backend.Field.S) :
  S with module Inputs.Field = Field

module Test
    (Impl : Snarky_backendless.Snark_intf.Run)
    (_ : Sponge.Intf.Sponge
           with module Field := Impl.Field.Constant
            and module State := Sponge.State
            and type input := Impl.field
            and type digest := Impl.field)
    (_ : Sponge.Intf.Sponge
           with module Field := Impl.Field
            and module State := Sponge.State
            and type input := Impl.Field.t
            and type digest := Impl.Field.t) : sig
  val test : Impl.Field.Constant.t Sponge.Params.t -> unit
end
