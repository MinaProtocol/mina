open Snarkette
open Laurent

module type Group = sig
  type t

  type nat

  val one : t

  val ( + ) : t -> t -> t

  val scale : t -> nat -> t
end

module type Field_intf = sig 
  type t
  type nat 
  val ( * ) : t -> t -> t
  val ( / ) : t -> t -> t
  val ( + ) : t -> t -> t
  val ( - ) : t -> t -> t
  val zero : t
  val one : t
  val inv : t -> t
  val negate : t -> t
  val ( ** ) : t -> nat -> t
  val to_bigint : t -> nat
end

module type Field_intf_str = sig 
  type t
  type nat 
  val ( * ) : t -> t -> t
  val ( / ) : t -> t -> t
  val ( + ) : t -> t -> t
  val ( - ) : t -> t -> t
  val zero : t
  val one : t
  val inv : t -> t
  val negate : t -> t
  val ( ** ) : t -> nat -> t
  val to_bigint : t -> nat
  val to_string : t -> string
end

module type Backend_intf = sig
  module N : sig type t val of_int : int -> t end

  module Fq : Field_intf with type nat := N.t

  module Fr : Field_intf_str with type nat := N.t

  module G1 : Group with type nat := N.t

  module G2 : Group with type nat := N.t

  module Fq_target : Fields.Degree_2_extension_intf

  module Pairing :
    Pairing.S_sonic
      with module G1 := G1
       and module G2 := G2
       and module Fq_target := Fq_target

  module Fr_laurent 
  : Laurent with type field := Fr.t and type nat := N.t

  module Bivariate_fr_laurent :
    Laurent with type field := Fr_laurent.t and type nat := N.t
end
