open Pickles_types

(** Represents how many proofs are verified. Currently only [0], [1] or [2] *)
module Stable : sig
  module V2 : sig
    type t = Mina_wire_types.Pickles_base.Proofs_verified.V2.t =
      | N0
      | N1
      | N2
      | N_other of int
    [@@deriving sexp, compare, yojson, hash, equal]

    include Plonkish_prelude.Sigs.Binable.S with type t := t

    include Plonkish_prelude.Sigs.VERSIONED
  end

  module Latest = V2

  module V1 : sig
    type t = Mina_wire_types.Pickles_base.Proofs_verified.V1.t = N0 | N1 | N2
    [@@deriving sexp, compare, yojson, hash, equal]

    include Plonkish_prelude.Sigs.Binable.S with type t := t

    include Plonkish_prelude.Sigs.VERSIONED

    val to_latest : t -> V2.t
  end
end

type t = N0 | N1 | N2 | N_other of int
[@@deriving sexp, compare, yojson, hash, equal]

(** [of_nat_exn t_n] converts the type level natural [t_n] to the data type natural.
    Raise an exception if [t_n] represents a value above or equal to 3 *)
val of_nat_exn : 'n Nat.t -> t

(** [of_int_exn n] converts the runtime natural [n] to the data type natural. Raise
    an exception if the value [n] is above or equal to 3 *)
val of_int_exn : int -> t

(** [to_int v] converts the value [v] to the corresponding integer, i.e [N0 ->
    0], [N1 -> 1] and [N2 -> 2] *)
val to_int : t -> int

(** Conversions between the in-memory [t] and the serialised [Stable] encodings. *)

val to_stable_v2 : t -> Stable.V2.t

val of_stable_v2 : Stable.V2.t -> t

val to_stable_v1 : t -> Stable.V1.t

val of_stable_v1 : Stable.V1.t -> t

module One_hot : sig
  open Kimchi_pasta_snarky_backend

  module Checked : sig
    type 'n t = 'n Nat.N3.plus_n One_hot_vector.Step.t

    val to_input : 'n t -> Step_impl.Field.t Random_oracle_input.Chunked.t
  end

  val to_input :
       'n Nat.N3.plus_n Nat.t
    -> zero:'a
    -> one:'a
    -> t
    -> 'a Random_oracle_input.Chunked.t

  val typ : 'n Nat.N3.plus_n Nat.t -> ('n Checked.t, t) Step_impl.Typ.t
end

val to_bool_vec : 'n Nat.t -> t -> (bool, 'n) Vector.t

val of_bool_vec : (bool, 'n) Vector.t -> t

module Prefix_mask : sig
  open Kimchi_pasta_snarky_backend

  module Step : sig
    module Checked : sig
      type 'n t = (Step_impl.Boolean.var, 'n Nat.N2.plus_n) Vector.t
    end

    val typ : 'n Nat.N2.plus_n Nat.t -> ('n Checked.t, t) Step_impl.Typ.t
  end

  module Wrap : sig
    module Checked : sig
      type 'n t = (Wrap_impl.Boolean.var, 'n Nat.N2.plus_n) Vector.t
    end

    val typ : 'n Nat.N2.plus_n Nat.t -> ('n Checked.t, t) Wrap_impl.Typ.t
  end
end
