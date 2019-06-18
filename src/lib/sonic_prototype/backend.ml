open Snarkette
open Laurent

module type Backend_intf = sig
  module N : Nat_intf.S

  module Fq : Fields.Fp_intf with type nat := N.t

  module Fr : Fields.Fp_intf with type nat := N.t

  module Fqe : Fields.Extension_intf with type base = Fq.t

  module G1 : sig
    type t

    val zero : t

    val ( * ) : N.t -> t -> t

    val ( + ) : t -> t -> t
  end

  module G2 : sig
    type t

    val zero : t

    val ( * ) : N.t -> t -> t

    val ( + ) : t -> t -> t
  end

  module Fq_target : sig
    include Fields.Degree_2_extension_intf with type base = Fqe.t

    val unitary_inverse : t -> t
  end
  
  module Pairing : 
    Pairing.S
    with module G1 := G1
    and module G2 := G2
    and module Fq_target := Fq_target

  module Fr_laurent : Laurent with type field := Fr.t and type nat := N.t

  module Bivariate_fr_laurent : Laurent with type field := Fr_laurent.t and type nat := N.t
end
