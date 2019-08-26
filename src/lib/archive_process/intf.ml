open Coda_base
open Signature_lib

(* TODO: this should be a writer module *)
module type Receipt_chain = sig
  type t

  type external_transition

  type user_command

  type merkle_list

  (** Add stores a payment into a client's database as a value.
      The key is computed by using the payment payload and the previous receipt_chain_hash.
      This receipt_chain_hash is computed within the `add` function. As a result,
      the computed receipt_chain_hash is returned *)
  val add :
       t
    -> (external_transition, State_hash.t) With_hash.t
    -> Receipt.Chain_hash.t Public_key.Compressed.Map.t
    -> unit

  (* TODO: put this into another module (as reader) *)
  (* val prove :
       t
    -> proving_receipt:Receipt.Chain_hash.t
    -> resulting_receipt:Receipt.Chain_hash.t
    -> Payment_proof.t Or_error.t *)
end
