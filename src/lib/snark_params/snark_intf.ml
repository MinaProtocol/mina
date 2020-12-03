open Snark_bits

module type S = sig
  include Snarky_backendless.Snark_intf.S

  module Snarkable : sig
    module type S = sig
      type var

      type value

      val typ : (var, value) Typ.t
    end

    module Bits : sig
      module type Faithful =
        Bits_intf.Snarkable.Faithful
        with type ('a, 'b) typ := ('a, 'b) Typ.t
         and type ('a, 'b) checked := ('a, 'b) Checked.t
         and type boolean_var := Boolean.var

      module type Lossy =
        Bits_intf.Snarkable.Lossy
        with type ('a, 'b) typ := ('a, 'b) Typ.t
         and type ('a, 'b) checked := ('a, 'b) Checked.t
         and type boolean_var := Boolean.var
    end
  end
end
