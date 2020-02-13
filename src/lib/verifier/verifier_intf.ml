open Async_kernel
open Core_kernel
open Coda_base

module Base = struct
  module type S = sig
    type t

    type ledger_proof

    val verify_blockchain_snark :
      t -> Blockchain_snark.Blockchain.t -> bool Or_error.t Deferred.t

    val verify_transaction_snarks :
         t
      -> (ledger_proof * Sok_message.t) list
      -> bool list Or_error.t Deferred.t
  end
end

module Any = struct
  module type S = sig
    type ('t, 'ledger_proof) provider =
      (module Base.S with type t = 't and type ledger_proof = 'ledger_proof)

    type 'ledger_proof t

    val cast :
         't
      -> 'ledger_proof Ledger_proof.type_witness
      -> ('t, 'ledger_proof) provider
      -> 'ledger_proof t

    val verify_blockchain_snark :
      _ t -> Blockchain_snark.Blockchain.t -> bool Or_error.t Deferred.t

    val verify_transaction_snarks :
         'ledger_proof t
      -> ('ledger_proof * Sok_message.t) list
      -> bool list Or_error.t Deferred.t

    module E : sig
      type e = E : _ t -> e

      type t = e

      val verify_blockchain_snark :
        t -> Blockchain_snark.Blockchain.t -> bool Or_error.t Deferred.t

      val verify_transaction_snarks :
           t
        -> Ledger_proof.witnessed_list_with_messages
        -> bool list Or_error.t Deferred.t
    end
  end
end

module type S = sig
  include Base.S

  val create :
       logger:Logger.t
    -> pids:Child_processes.Termination.t
    -> conf_dir:string option
    -> t Deferred.t
end
