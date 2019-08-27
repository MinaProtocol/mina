open Core
open Coda_base
open Signature_lib

module type Receipt_chain_writer = sig
  type t

  type external_transition

  (* TODO: transition should only have transactions that a user would be
     interested in *)
  val add :
       t
    -> (external_transition, State_hash.t) With_hash.t
    -> Receipt.Chain_hash.t Public_key.Compressed.Map.t
    -> unit
end

module type Receipt_chain_reader = sig
  type t

  val prove :
       t
    -> proving_receipt:Receipt.Chain_hash.t
    -> resulting_receipt:Receipt.Chain_hash.t
    -> Payment_proof.t Or_error.t

  val verify :
       resulting_receipt:Receipt.Chain_hash.t
    -> ( Receipt.Chain_hash.t
       , User_command.t )
       Receipt_chain_database_lib.Payment_proof.t
    -> unit Or_error.t
end

(** We are separating receipt_chain by reader and writer because one process
    will be doing writing actions (Archive) and the other will be doing reading
    actions (Daemon) *)
module type Receipt_chain = sig
  type external_transition

  module Writer :
    Receipt_chain_writer with type external_transition := external_transition

  module Reader : Receipt_chain_reader

  val create :
    logger:Logger.t -> Receipt_chain_database.t -> Reader.t * Writer.t
end
