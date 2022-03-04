open Core_kernel

val ledger_depth : int

module Field : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      type t [@@deriving equal, compare, yojson, sexp, hash]
    end
  end]

  type t = Stable.Latest.t
  [@@deriving equal, compare, yojson, sexp, hash, bin_io]

  module Nat = Snarkette.Pasta.Fp.Nat

  val order : Nat.t

  val one : t

  val zero : t

  val ( + ) : t -> t -> t

  val ( * ) : t -> t -> t

  val ( - ) : t -> t -> t

  val ( / ) : t -> t -> t

  val square : t -> t

  val gen : t Quickcheck.Generator.t

  val gen_incl : t -> t -> t Quickcheck.Generator.t

  val gen_uniform : t Quickcheck.Generator.t

  val gen_uniform_incl : t -> t -> t Quickcheck.Generator.t

  val random : unit -> t

  val negate : t -> t

  val inv : t -> t

  val parity : t -> bool

  val of_string : string -> t

  val to_string : t -> string

  val of_int : int -> t

  val of_bits : bool list -> t option

  val to_bigint : t -> Nat.t

  val of_bigint : Nat.t -> t

  val fold_bits : t -> bool Fold_lib.Fold.t

  val fold : t -> bool Tuple_lib.Triple.t Fold_lib.Fold.t

  val to_bits : t -> bool list

  val length_in_bits : int

  val is_square : t -> bool

  val sqrt : t -> t

  val size : Bigint.t

  val size_in_bits : int

  val unpack : t -> bool list

  val project : bool list -> t
end

module Tock : sig
  module Field : sig
    type t = Snarkette.Pasta.Fq.t

    val unpack : t -> bool list

    val size_in_bits : int

    val project : bool list -> Snarkette.Pasta.Fq.t
  end
end

module Inner_curve : sig
  type t [@@deriving sexp]

  module Coefficients : sig
    val a : Field.t

    val b : Field.t
  end

  val find_y : Field.t -> Field.t option

  val of_affine : Field.t * Field.t -> t

  val to_affine : t -> (Field.t * Field.t) option

  val to_affine_exn : t -> Field.t * Field.t

  val one : t

  val ( + ) : t -> t -> t

  val negate : t -> t

  module Scalar : sig
    type t = Tock.Field.t [@@deriving bin_io, sexp, equal, compare, hash]

    type _unused = unit

    val to_string : Tock.Field.t -> string

    val of_string : string -> Tock.Field.t

    val size : Snarkette.Pasta.Fq.Nat.t

    val zero : Tock.Field.t

    val one : Tock.Field.t

    val ( + ) : Tock.Field.t -> Tock.Field.t -> Tock.Field.t

    val ( - ) : Tock.Field.t -> Tock.Field.t -> Tock.Field.t

    val ( * ) : Tock.Field.t -> Tock.Field.t -> Tock.Field.t

    val gen_uniform_incl :
         Tock.Field.t
      -> Tock.Field.t
      -> Tock.Field.t Quickcheck.Generator.t

    val negate : Tock.Field.t -> Tock.Field.t

    val gen : Tock.Field.t Quickcheck.Generator.t

    val gen_uniform : Tock.Field.t Quickcheck.Generator.t

    val unpack : Tock.Field.t -> bool list

    val of_bits : bool list -> Tock.Field.t

    val project : bool list -> Tock.Field.t
  end

  val scale : t -> Scalar.t -> t

  val scale_field : t -> Snarkette.Pasta.Fq.Nat.t -> t
end
