open Core_kernel
open Async_kernel
open Currency
open Signature_lib
open Coda_base

module type Security_intf = sig
  (** In production we set this to (hopefully a prefix of) k for our consensus
   * mechanism; infinite is for tests *)
  val max_depth : [`Infinity | `Finite of int]
end

module type Snark_pool_proof_intf = sig
  module Statement : sig
    type t [@@deriving sexp, bin_io, yojson]
  end

  type t [@@deriving sexp, bin_io, yojson]
end

(* TODO: this is temporarily required due to staged ledger test stubs *)
module type Ledger_proof_generalized_intf = sig
  type transaction_snark_statement

  type sok_message_digest

  type proof

  type frozen_ledger_hash

  (* bin_io omitted intentionally *)
  type t [@@deriving sexp, yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io, yojson, version]
      end

      module Latest = V1
    end
    with type V1.t = t

  val create :
       statement:transaction_snark_statement
    -> sok_digest:sok_message_digest
    -> proof:proof
    -> t

  val statement_target : transaction_snark_statement -> frozen_ledger_hash

  val statement : t -> transaction_snark_statement

  val sok_digest : t -> sok_message_digest

  val underlying_proof : t -> proof
end

module type Ledger_proof_intf =
  Ledger_proof_generalized_intf
  with type transaction_snark_statement := Transaction_snark.Statement.t
   and type sok_message_digest := Sok_message.Digest.t
   and type proof := Proof.t
   and type frozen_ledger_hash := Frozen_ledger_hash.t

module type Verifier_intf = sig
  type t

  type ledger_proof

  val create : unit -> t Deferred.t

  val verify_blockchain_snark :
    t -> Blockchain_snark.Blockchain.t -> bool Or_error.t Deferred.t

  val verify_transaction_snark :
       t
    -> ledger_proof
    -> message:Coda_base.Sok_message.t
    -> bool Or_error.t Deferred.t
end

(* TODO: this is temporarily required due to staged ledger test stubs *)
module type Transaction_snark_work_generalized_intf = sig
  type compressed_public_key [@@deriving to_yojson]

  type transaction_snark_statement

  type ledger_proof [@@deriving to_yojson]

  module Statement : sig
    type t = transaction_snark_statement list [@@deriving yojson, sexp]

    include Hashable.S with type t := t

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving yojson, version, sexp, bin_io]

          include Hashable.S_binable with type t := t
        end
      end
      with type V1.t = t

    val gen : t Quickcheck.Generator.t
  end

  module Info : sig
    type t =
      { statements: Statement.Stable.V1.t
      ; job_ids: int list
      ; fee: Fee.Stable.V1.t
      ; prover: Public_key.Compressed.Stable.V1.t }
    [@@deriving to_yojson, sexp]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving to_yojson, version, sexp, bin_io]
        end
      end
      with type V1.t = t
  end

  (* TODO: The SOK message actually should bind the SNARK to
     be in this particular bundle. The easiest way would be to
     SOK with
     H(all_statements_in_bundle || fee || public_key)
  *)

  type t =
    {fee: Fee.t; proofs: ledger_proof list; prover: compressed_public_key}
  [@@deriving sexp, to_yojson]

  val fee : t -> Fee.t

  val info : t -> Info.t

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io, to_yojson, version]
      end
    end
    with type V1.t = t

  type unchecked = t

  module Checked : sig
    type nonrec t = t =
      {fee: Fee.t; proofs: ledger_proof list; prover: compressed_public_key}
    [@@deriving sexp, to_yojson]

    module Stable : module type of Stable

    val create_unsafe : unchecked -> t
  end

  val forget : Checked.t -> t

  val proofs_length : int
end

module type Transaction_snark_work_intf =
  Transaction_snark_work_generalized_intf
  with type compressed_public_key := Public_key.Compressed.t
   and type transaction_snark_statement := Transaction_snark.Statement.t
