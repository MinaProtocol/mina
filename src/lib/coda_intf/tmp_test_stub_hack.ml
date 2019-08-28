open Async_kernel
open Core_kernel
open Coda_base

module type For_transaction_snark_scan_state_intf = sig
  module Proof_type : sig
    type t = [`Base | `Merge]
  end

  (*module Staged_ledger_aux_hash : sig
    type t

    val of_bytes : string -> t
  end*)

  (*module Proof : sig
    type t
  end*)

  (*module Sok_message : sig
    type t [@@deriving sexp]

    module Stable : sig
      module V1 : sig
        type nonrec t = t [@@deriving bin_io, sexp, version]
      end
    end

    val create : fee:Currency.Fee.t -> prover:Public_key.Compressed.t -> t

    module Digest : sig
      type t
    end
  end*)

  module Ledger_proof :
    Core_intf.Ledger_proof_generalized_intf
    with type transaction_snark_statement := Transaction_snark.Statement.t
     and type frozen_ledger_hash := Coda_base.Frozen_ledger_hash.t

  module Transaction_snark_work :
    Core_intf.Transaction_snark_work_generalized_intf
    with type ledger_proof := Ledger_proof.t
end

module type For_staged_ledger_intf = sig
  include For_transaction_snark_scan_state_intf

  (*module Staged_ledger_hash : sig
    type t [@@deriving eq, sexp]

    val of_aux_ledger_and_coinbase_hash :
      Staged_ledger_aux_hash.t -> Ledger_hash.t -> Pending_coinbase.t -> t
  end*)

  module Verifier : sig
    type t

    val verify_transaction_snark :
      t -> Ledger_proof.t -> message:Sok_message.t -> bool Deferred.Or_error.t
  end

  module Transaction_validator : sig
    module Hashless_ledger : sig
      type t
    end

    val apply_transaction :
      Hashless_ledger.t -> Transaction.t -> unit Or_error.t

    val create : Ledger.t -> Hashless_ledger.t
  end

  module Staged_ledger_diff :
    Staged_ledger_intf.Staged_ledger_diff_generalized_intf
    with type transaction_snark_work := Transaction_snark_work.t
     and type transaction_snark_work_checked :=
                Transaction_snark_work.Checked.t
end
