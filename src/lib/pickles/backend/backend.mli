(** Pickles backend, i.e. curves used by the inductive proof system.
    At the time of writing, Pallas and Vesta curves (so-called Pasta) are
    hardcoded. The 2-cycle is called [Tick] and [Tock].
*)

module Tick : sig
  include module type of Kimchi_backend.Pasta.Vesta_based_plonk

  module Inner_curve = Kimchi_backend.Pasta.Pasta.Pallas
end

module Tock : sig
  include module type of Kimchi_backend.Pasta.Pallas_based_plonk

  module Inner_curve = Kimchi_backend.Pasta.Pasta.Vesta
end

module Bn254 = Kimchi_backend.Bn254.Bn254_based_plonk
