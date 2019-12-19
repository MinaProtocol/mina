(* sponge_params.ml -- use snarky field *)

module Functor = Functor
include Functor.Make (Curve_choice.Tick0.Field)
