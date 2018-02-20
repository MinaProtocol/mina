module type S = sig
  include Camlsnark.Snark_intf.S

  module Snarkable : sig
    module type S = sig
      type var
      type value
      val spec : (var, value) Var_spec.t
    end

    module Bits : sig
      module type Faithful = Bits_intf.Snarkable.Faithful
        with type ('a, 'b) var_spec := ('a, 'b) Var_spec.t
         and type ('a, 'b) checked := ('a, 'b) Checked.t
         and type boolean_var := Boolean.var

      module type Lossy = Bits_intf.Snarkable.Lossy
        with type ('a, 'b) var_spec := ('a, 'b) Var_spec.t
         and type ('a, 'b) checked := ('a, 'b) Checked.t
         and type boolean_var := Boolean.var
    end
  end
end
