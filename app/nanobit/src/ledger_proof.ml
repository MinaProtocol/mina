open Core_kernel
open Async_kernel
open Nanobit_base

module Prod = struct
  type t = Transaction_snark.t [@@deriving bin_io, sexp]

  let statement = Transaction_snark.statement

  let proof = Transaction_snark.proof
end

module Debug = struct
  type t = Transaction_snark.Statement.t [@@deriving sexp, bin_io]

  let proof (_: t) = Proof.dummy

  let statement (t: t) : Transaction_snark.Statement.t = t
end
