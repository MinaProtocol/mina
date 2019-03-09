open Core_kernel
open Async_kernel
open Coda_base

let to_signed_amount signed_fee =
  let magnitude =
    Currency.Fee.Signed.magnitude signed_fee |> Currency.Amount.of_fee
  and sgn = Currency.Fee.Signed.sgn signed_fee in
  Currency.Amount.Signed.create ~magnitude ~sgn

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

  let create
      ~statement:{ Transaction_snark.Statement.source
                 ; target
                 ; supply_increase
                 ; fee_excess
                 ; pending_coinbase_stack_state
                 ; proof_type } ~sok_digest ~proof =
    Transaction_snark.create ~source ~target ~pending_coinbase_stack_state
      ~supply_increase
      ~fee_excess:(to_signed_amount fee_excess)
      ~sok_digest ~proof ~proof_type
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

  let create ~statement ~sok_digest ~proof = (statement, sok_digest)
end
