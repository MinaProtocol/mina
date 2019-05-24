open Tuple_lib
open Fold_lib

module type S = sig
  module Field : sig
    type t

    include Group_map.Field_intf.S_unchecked with type t := t

    val to_bits : t -> bool list

    val of_bits : bool list -> t
  end

  module Bigint : sig
    type t

    val test_bit : t -> int -> bool

    val of_field : Field.t -> t
  end

  module Fqe : sig
    type t

    val parts : t -> Field.t list
  end

  module G1 : sig
    type t

    val to_affine_coordinates : t -> Field.t * Field.t

    val of_affine_coordinates : Field.t * Field.t -> t
  end

  module G2 : sig
    type t

    val to_affine_coordinates : t -> Fqe.t * Fqe.t
  end

  val pedersen : bool Triple.t Fold.t -> Field.t

  val params : Field.t Group_map.Params.t
end
