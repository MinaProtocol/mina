open Core_kernel
open Async_kernel
open Coda_base

module Prod :
  Protocols.Coda_pow.Ledger_proof_intf
  with type t = Transaction_snark.t
   and type statement = Transaction_snark.Statement.t
   and type sok_digest := Sok_message.Digest.t
   and type ledger_hash := Frozen_ledger_hash.t
   and type proof := Proof.t = struct
  type t = Transaction_snark.t [@@deriving bin_io, sexp]

  type statement = Transaction_snark.Statement.t

  let sok_digest = Transaction_snark.sok_digest

  let statement = Transaction_snark.statement

  let statement_target (t : Transaction_snark.Statement.t) = t.target

  let underlying_proof = Transaction_snark.proof
end

module Debug :
  Protocols.Coda_pow.Ledger_proof_intf
  with type t = Transaction_snark.Statement.t * Sok_message.Digest.Stable.V1.t
   and type statement = Transaction_snark.Statement.t
   and type sok_digest := Sok_message.Digest.t
   and type ledger_hash := Frozen_ledger_hash.t
   and type proof := Proof.t = struct
  type t = Transaction_snark.Statement.t * Sok_message.Digest.Stable.V1.t
  [@@deriving sexp, bin_io]

  type statement = Transaction_snark.Statement.t

  let underlying_proof (_ : t) = Proof.dummy

  let statement ((t, _) : t) : Transaction_snark.Statement.t = t

  let statement_target (t : Transaction_snark.Statement.t) = t.target

  let sok_digest (_, d) = d
end
