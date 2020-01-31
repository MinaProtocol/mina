type ('t, 'ledger_proof) provider =
  (module Verifier_intf.Base.S
     with type t = 't
      and type ledger_proof = 'ledger_proof)

type _ t =
  | Any :
      't
      * 'ledger_proof Ledger_proof.type_witness
      * ('t, 'ledger_proof) provider
      -> 'ledger_proof t

let cast (t : 't) (w : 'ledger_proof Ledger_proof.type_witness)
    (m : ('t, 'ledger_proof) provider) : 'ledger_proof t =
  Any (t, w, m)

let verify_blockchain_snark (type ledger_proof)
    (Any (t, w, m) : ledger_proof t) blockchain =
  match (w, m) with
  | Debug, (module M) ->
      M.verify_blockchain_snark t blockchain
  | Prod, (module M) ->
      M.verify_blockchain_snark t blockchain

let verify_transaction_snark (type ledger_proof)
    (Any (t, w, m) : ledger_proof t) (proof : ledger_proof) ~message =
  match (w, m) with
  | Debug, (module M) ->
      M.verify_transaction_snark t proof ~message
  | Prod, (module M) ->
      M.verify_transaction_snark t proof ~message

(* TEMP: hack to eschew compile time type safety temporarily, to be fixed in (#3518) *)
module E = struct
  type e = E : _ t -> e

  type t = e

  let verify_blockchain_snark (E t) blockchain =
    verify_blockchain_snark t blockchain

  let verify_transaction_snark (E (Any (_, any_witness, _) as t))
      (Ledger_proof.With_witness (proof, witness)) ~message =
    match (any_witness, witness) with
    | Debug, Debug ->
        verify_transaction_snark t proof ~message
    | Prod, Prod ->
        verify_transaction_snark t proof ~message
    | _, _ ->
        failwith "invalid"
end
