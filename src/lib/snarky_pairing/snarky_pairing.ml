module type Inputs_intf = sig
  module Fq : Intf.Fq with type 'a A.t = 'a and type 'a Base.t_ = 'a

  module Fqe : Intf.Fqe with module Impl = Fq.Impl and module Base = Fq

  module Fqk :
    Intf.Fqk with module Impl = Fq.Impl and type 'a Base.t_ = 'a Fqe.t_

  module N : Snarkette.Nat_intf.S

  module G2 : Intf.G2 with module Fqe := Fqe

  module Params : sig
    include Intf.Params with module N := N

    val twist : Fqe.Unchecked.t

    val g2_coeff_a : Fqe.Unchecked.t
  end
end

module Make (Inputs : Inputs_intf) : sig
  open Inputs
  open Fq.Impl

  module G1_precomputation : Intf.G1_precomputation with module Fqe := Fqe

  module G2_precomputation :
    Intf.G2_precomputation with module Fqe := Fqe and module G2 := G2

  val miller_loop :
    G1_precomputation.t -> G2_precomputation.t -> (Fqk.t, _) Checked.t

  val batch_miller_loop :
       (Sgn_type.Sgn.t * G1_precomputation.t * G2_precomputation.t) list
    -> (Fqk.t, _) Checked.t

  val final_exponentiation : Fqk.t -> (Fqk.t, _) Checked.t
end = struct
  module T = struct
    include Inputs
    module G1_precomputation = G1_precomputation.Make (Fqe) (Params)
    module G2_precomputation = G2_precomputation.Make (Fqe) (G2) (N) (Params)
  end

  module G1_precomputation = T.G1_precomputation
  module G2_precomputation = T.G2_precomputation
  include Miller_loop.Make (T)
  include Final_exponentiation.Make (Inputs)
end
