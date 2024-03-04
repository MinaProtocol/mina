(* bits_intf.ml *)

[%%import "/src/config.mlh"]

open Fold_lib

module type Basic = sig
  type t

  val fold : t -> bool Fold.t

  val size_in_bits : int
end

module type S = sig
  include Basic

  val iter : t -> f:(bool -> unit) -> unit

  val to_bits : t -> bool list
end

module type Convertible_bits = sig
  include S

  val of_bits : bool list -> t
end

[%%ifdef consensus_mechanism]

open Tuple_lib

module Snarkable = struct
  module type Basic = sig
    type (_, _) typ

    type _ checked

    type boolean_var

    val size_in_bits : int

    module Packed : sig
      type var

      type value

      val typ : (var, value) typ

      val size_in_bits : int
    end

    module Unpacked : sig
      type var

      type value

      val typ : (var, value) typ

      val var_to_bits : var -> boolean_var Bitstring_lib.Bitstring.Lsb_first.t

      val var_of_bits : boolean_var Bitstring_lib.Bitstring.Lsb_first.t -> var

      val var_to_triples : var -> boolean_var Triple.t list

      val var_of_value : value -> var

      val size_in_bits : int
    end
  end

  module type Lossy = sig
    include Basic

    val project_value : Unpacked.value -> Packed.value

    val unpack_value : Packed.value -> Unpacked.value

    val project_var : Unpacked.var -> Packed.var

    val choose_preimage_var : Packed.var -> Unpacked.var checked
  end

  module type Faithful = sig
    include Basic

    val pack_value : Unpacked.value -> Packed.value

    val unpack_value : Packed.value -> Unpacked.value

    val pack_var : Unpacked.var -> Packed.var

    val unpack_var : Packed.var -> Unpacked.var checked
  end

  module type Small = sig
    type comparison_result

    type field_var

    include Faithful with type Packed.var = private field_var

    val compare_var : Unpacked.var -> Unpacked.var -> comparison_result checked

    val increment_var : Unpacked.var -> Unpacked.var checked

    val increment_if_var : Unpacked.var -> boolean_var -> Unpacked.var checked

    val assert_equal_var : Unpacked.var -> Unpacked.var -> unit checked

    val equal_var : Unpacked.var -> Unpacked.var -> boolean_var checked

    val var_of_field : field_var -> Unpacked.var checked

    val var_of_field_unsafe : field_var -> Packed.var

    val if_ :
         boolean_var
      -> then_:Unpacked.var
      -> else_:Unpacked.var
      -> Unpacked.var checked
  end
end

[%%endif]
