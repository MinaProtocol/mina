open Core_kernel
open Coda_base
open Signature_lib

module type Staged_ledger_diff_intf = sig
  type t [@@deriving bin_io, sexp, version]

  val creator : t -> Public_key.Compressed.t

  val user_commands : t -> User_command.t list
end

module Make
    (Ledger_proof : Coda_intf.Ledger_proof_intf)
    (Verifier : Coda_intf.Verifier_intf
                with type ledger_proof := Ledger_proof.t)
    (Staged_ledger_diff : Staged_ledger_diff_intf) :
  Coda_intf.External_transition_intf
  with type ledger_proof := Ledger_proof.t
   and type verifier := Verifier.t
   and type staged_ledger_diff := Staged_ledger_diff.t

include
  Coda_intf.External_transition_intf
  with type ledger_proof := Ledger_proof.t
   and type verifier := Verifier.t
   and type staged_ledger_diff := Staged_ledger_diff.Stable.V1.t
