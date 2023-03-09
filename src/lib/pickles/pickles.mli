(* Pickles implementation *)

include
  Pickles_intf.S
    with type Side_loaded.Verification_key.Stable.V2.t =
      Mina_wire_types.Pickles.Side_loaded.Verification_key.V2.t
     and type ('a, 'b) Proof.t = ('a, 'b) Mina_wire_types.Pickles.Proof.t

module Wrap_main_inputs = Wrap_main_inputs
module Opt_sponge = Opt_sponge
