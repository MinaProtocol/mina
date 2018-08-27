open Core_kernel
open Async_kernel
open Nanobit_base

module Prod = struct
  type t = Transaction_snark.t [@@deriving bin_io, sexp]

  let sok_digest = Transaction_snark.sok_digest

  let statement = Transaction_snark.statement

  let proof = Transaction_snark.proof
end

module Debug = struct
  type t = Transaction_snark.Statement.t * Sok_message.Digest.Stable.V1.t [@@deriving sexp, bin_io]

  let proof (_: t) = Proof.dummy

  let statement ((t, _): t) : Transaction_snark.Statement.t = t

  let sok_digest (_, d) = d
end
