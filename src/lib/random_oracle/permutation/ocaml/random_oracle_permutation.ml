module Inputs = Pickles.Tick_field_sponge.Inputs
include Sponge.Poseidon (Inputs)
module Field = Kimchi_backend.Pasta.Basic.Fp
