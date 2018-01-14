module type S = sig
  include Camlsnark.Snark_intf.S

  module Snarkable : sig
    module type S = sig
      type var
      type value
      val spec : (var, value) Var_spec.t
    end

    module Bits : sig
      module type S = sig
        val bit_length : int

        module Packed : sig
          type var
          type value
          val spec : (var, value) Var_spec.t
        end

        module Unpacked : sig
          type var = Boolean.var list
          type value
          val spec : (var, value) Var_spec.t

          module Padded : sig
            type var = private Boolean.var list
            type value
            val spec : (var, value) Var_spec.t
          end

          val fold : value -> init:'acc -> f:('acc -> bool -> 'acc) -> 'acc
          val iter : value -> f:(bool -> unit) -> unit

          val to_bits : value -> bool list
        end

        module Checked : sig
          val pad : Unpacked.var -> Unpacked.Padded.var
          val unpack : Packed.var -> (Unpacked.var, _) Checked.t
        end

        val unpack : Packed.value -> Unpacked.value
      end
    end
  end
end
