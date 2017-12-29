open Core_kernel

module Main_curve = Camlsnark.Backends.Mnt4
module Main = Camlsnark.Snark.Make(Main_curve)

module Other_curve = Camlsnark.Backends.Mnt6
module Other = Camlsnark.Snark.Make(Other_curve)
