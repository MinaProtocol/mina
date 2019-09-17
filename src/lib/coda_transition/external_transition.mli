open Core_kernel

module Make
    (Ledger_proof : Coda_intf.Ledger_proof_intf)
    (Verifier : Coda_intf.Verifier_intf
                with type ledger_proof := Ledger_proof.t)
                                                        (Transaction_snark_work : sig
        module Stable : sig
          module V1 : sig
            type t [@@deriving bin_io, sexp, version]
          end
        end

        type t = Stable.V1.t

        module Checked : sig
          type t [@@deriving sexp]
        end
    end)
    (Staged_ledger_diff : Coda_intf.Staged_ledger_diff_intf
                          with type transaction_snark_work :=
                                      Transaction_snark_work.t
                           and type transaction_snark_work_checked :=
                                      Transaction_snark_work.Checked.t) :
  Coda_intf.External_transition_intf
  with type ledger_proof := Ledger_proof.t
   and type verifier := Verifier.t
   and type staged_ledger_diff := Staged_ledger_diff.t

include
  Coda_intf.External_transition_intf
  with type ledger_proof := Ledger_proof.t
   and type verifier := Verifier.t
   and type staged_ledger_diff := Staged_ledger_diff.Stable.V1.t
