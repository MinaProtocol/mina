module Rounds : sig
  val rounds_full : int

  val initial_ark : bool

  val rounds_partial : int
end

(** {2 Module type} *)

module type S = sig
  module Inputs : sig
    include module type of Rounds

    module Field : Kimchi_backend.Field.S

    type field := Field.t

    val to_the_alpha : field -> field

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

    type params := f Sponge.Params.t

    type state := f Sponge.State.t

    type t = f Sponge.t (* TODO: Make this type abstract *)

    val create : ?init:state -> params -> t

    val make :
      state:state -> params:params -> sponge_state:Sponge.sponge_state -> t

    val absorb : t -> f -> unit

    val squeeze : t -> f

    val copy : t -> t

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
    (S_constant : Sponge.Intf.Sponge
                    with module Field := Impl.Field.Constant
                     and module State := Sponge.State
                     and type input := Impl.field
                     and type digest := Impl.field)
    (S_checked : Sponge.Intf.Sponge
                   with module Field := Impl.Field
                    and module State := Sponge.State
                    and type input := Impl.Field.t
                    and type digest := Impl.Field.t) : sig
  val test : Impl.Field.Constant.t Sponge.Params.t -> unit
end
