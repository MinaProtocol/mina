open Pickles_types

(** Represents how many proofs are verified. Currently only [0], [1] or [2] *)
module Stable : sig
  module V1 : sig
    type t = Mina_wire_types.Pickles_base.Proofs_verified.V1.t = N0 | N1 | N2
    [@@deriving sexp, compare, yojson, hash, equal]

    include Plonkish_prelude.Sigs.Binable.S with type t := t

    include Plonkish_prelude.Sigs.VERSIONED
  end
end

type t = Stable.V1.t = N0 | N1 | N2
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

module One_hot : sig
  open Kimchi_pasta_snarky_backend

  module Checked : sig
    type t = Pickles_types.Nat.N3.n One_hot_vector.Step.t

    val to_input : t -> Step_impl.Field.t Random_oracle_input.Chunked.t
  end

  val to_input : zero:'a -> one:'a -> t -> 'a Random_oracle_input.Chunked.t

  val typ : (Checked.t, t) Step_impl.Typ.t
end

val to_bool_vec : t -> (bool, Nat.N2.n) Vector.t

val of_bool_vec : (bool, Nat.N2.n) Vector.t -> t

module Prefix_mask : sig
  open Kimchi_pasta_snarky_backend

  module Step : sig
    module Checked : sig
      type t = (Step_impl.Boolean.var, Nat.N2.n) Vector.t
    end

    val typ : (Checked.t, t) Step_impl.Typ.t
  end

  module Wrap : sig
    module Checked : sig
      type t = (Wrap_impl.Boolean.var, Nat.N2.n) Vector.t
    end

    val typ : (Checked.t, t) Wrap_impl.Typ.t
  end
end
