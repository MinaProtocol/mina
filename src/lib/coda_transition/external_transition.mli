open Core_kernel
open Coda_base
open Coda_state
open Signature_lib

module type S =
  Protocols.Coda_pow.External_transition_intf
  with type time := Block_time.t
   and type state_hash := State_hash.t
   and type compressed_public_key := Public_key.Compressed.t
   and type user_command := User_command.t
   and type consensus_state := Consensus.Data.Consensus_state.Value.t
   and type protocol_state := Protocol_state.Value.t
   and type proof := Proof.t
   and type staged_ledger_hash := Staged_ledger_hash.t
   and type ledger_proof := Ledger_proof.t
   and type transaction := Transaction.t

module type Staged_ledger_diff_intf = sig
  type t [@@deriving bin_io, sexp, version]

  val creator : t -> Signature_lib.Public_key.Compressed.t

  val user_commands : t -> User_command.t list
end

module Make
    (Verifier : Verifier.S)
    (Staged_ledger_diff : Staged_ledger_diff_intf) :
  S
  with type verifier := Verifier.t
   and type staged_ledger_diff := Staged_ledger_diff.t

include
  S
  with type verifier := Verifier.t
   and type staged_ledger_diff := Staged_ledger_diff.Stable.V1.t
