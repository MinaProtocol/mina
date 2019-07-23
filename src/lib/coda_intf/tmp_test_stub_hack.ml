open Async_kernel
open Core_kernel

module type For_transaction_snark_scan_state_intf = sig
  module Compressed_public_key : sig
    type t [@@deriving sexp]

    include Comparable.S with type t := t
  end

  module Proof_type : sig
    type t = [`Base | `Merge]
  end

  module Ledger_hash : sig
    type t [@@deriving compare, eq, sexp]
  end

  module Frozen_ledger_hash : sig
    type t [@@deriving eq, sexp]

    val of_ledger_hash : Ledger_hash.t -> t
  end

  module Staged_ledger_aux_hash : sig
    type t

    val of_bytes : string -> t
  end

  module User_command : sig
    type t [@@deriving sexp]

    module With_valid_signature : sig
      type nonrec t = private t [@@deriving sexp, yojson]
    end

    val fee : t -> Currency.Fee.t

    val check : t -> With_valid_signature.t option

    val accounts_accessed : t -> Compressed_public_key.t list
  end

  module Fee_transfer : sig
    type t

    module Single : sig
      type t = Compressed_public_key.t * Currency.Fee.t
    end

    val of_single : Single.t -> t

    val of_single_list : Single.t list -> t list

    val receivers : t -> Compressed_public_key.t list
  end

  module Coinbase : sig
    type t = private
      { proposer: Compressed_public_key.t
      ; amount: Currency.Amount.t
      ; fee_transfer: Fee_transfer.Single.t option }

    val create :
         amount:Currency.Amount.t
      -> proposer:Compressed_public_key.t
      -> fee_transfer:Fee_transfer.Single.t option
      -> t Or_error.t
  end

  module Transaction : sig
    type t =
      | User_command of User_command.With_valid_signature.t
      | Fee_transfer of Fee_transfer.t
      | Coinbase of Coinbase.t
    [@@deriving sexp, bin_io, compare, eq]

    val fee_excess : t -> Currency.Fee.Signed.t Or_error.t

    val supply_increase : t -> Currency.Amount.t Or_error.t
  end

  module Pending_coinbase_stack : sig
    type t [@@deriving eq]

    val push : t -> Coinbase.t -> t
  end

  module Pending_coinbase_stack_state : sig
    type t =
      {source: Pending_coinbase_stack.t; target: Pending_coinbase_stack.t}
    [@@deriving sexp]
  end

  module Ledger : sig
    type t

    module Undo : sig
      type t [@@deriving sexp]

      module Stable : sig
        module V1 : sig
          type nonrec t = t [@@deriving bin_io, sexp, version]
        end
      end

      val transaction : t -> Transaction.t Or_error.t
    end

    module Mask : sig
      type t

      val create : unit -> t
    end

    type attached_mask = t

    type maskable_ledger = t

    type serializable [@@deriving bin_io]

    val serializable_of_t : t -> serializable

    val unattached_mask_of_serializable : serializable -> Mask.t

    val register_mask : t -> Mask.t -> t

    val merkle_root : t -> Ledger_hash.t

    val undo : t -> Undo.t -> unit Or_error.t

    val apply_transaction : t -> Transaction.t -> Undo.t Or_error.t
  end

  module Sparse_ledger : sig
    type t

    val of_ledger_subset_exn : Ledger.t -> Compressed_public_key.t list -> t

    val merkle_root : t -> Ledger_hash.t

    val apply_transaction_exn : t -> Transaction.t -> t
  end

  module Transaction_witness : sig
    type t = {ledger: Sparse_ledger.t} [@@deriving sexp]

    module Stable : sig
      module V1 : sig
        type nonrec t = t [@@deriving bin_io, sexp, version]
      end
    end
  end

  module Transaction_snark_statement : sig
    type t =
      { source: Frozen_ledger_hash.t
      ; target: Frozen_ledger_hash.t
      ; supply_increase: Currency.Amount.Stable.V1.t
      ; pending_coinbase_stack_state: Pending_coinbase_stack_state.t
      ; fee_excess: Currency.Fee.Signed.Stable.V1.t
      ; proof_type: Proof_type.t }
    [@@deriving compare, eq, sexp, to_yojson]

    module Stable : sig
      module V1 : sig
        type nonrec t = t [@@deriving bin_io, sexp, version]
      end
    end

    val merge : t -> t -> t Or_error.t
  end

  module Proof : sig
    type t
  end

  module Sok_message : sig
    type t [@@deriving sexp]

    module Stable : sig
      module V1 : sig
        type nonrec t = t [@@deriving bin_io, sexp, version]
      end
    end

    val create : fee:Currency.Fee.t -> prover:Compressed_public_key.t -> t

    module Digest : sig
      type t
    end
  end

  module Ledger_proof :
    Core_intf.Ledger_proof_generalized_intf
    with type transaction_snark_statement := Transaction_snark_statement.t
     and type sok_message_digest := Sok_message.Digest.t
     and type proof := Proof.t
     and type frozen_ledger_hash := Frozen_ledger_hash.t

  module Transaction_snark_work :
    Core_intf.Transaction_snark_work_generalized_intf
    with type ledger_proof := Ledger_proof.t
     and type transaction_snark_statement := Transaction_snark_statement.t
     and type compressed_public_key := Compressed_public_key.t
end

module type For_staged_ledger_intf = sig
  include For_transaction_snark_scan_state_intf

  module Pending_coinbase : sig
    type t [@@deriving bin_io, sexp, to_yojson]

    val create : unit -> t Or_error.t

    val latest_stack :
      t -> is_new_stack:bool -> Pending_coinbase_stack.t Or_error.t

    val remove_coinbase_stack : t -> (Pending_coinbase_stack.t * t) Or_error.t

    val update_coinbase_stack :
      t -> Pending_coinbase_stack.t -> is_new_stack:bool -> t Or_error.t
  end

  module Staged_ledger_hash : sig
    type t [@@deriving eq, sexp]

    val of_aux_ledger_and_coinbase_hash :
      Staged_ledger_aux_hash.t -> Ledger_hash.t -> Pending_coinbase.t -> t
  end

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
    with type fee_transfer_single := Fee_transfer.Single.t
     and type user_command := User_command.t
     and type user_command_with_valid_signature :=
                User_command.With_valid_signature.t
     and type compressed_public_key := Compressed_public_key.t
     and type staged_ledger_hash := Staged_ledger_hash.t
     and type transaction_snark_work := Transaction_snark_work.t
     and type transaction_snark_work_checked :=
                Transaction_snark_work.Checked.t
end
