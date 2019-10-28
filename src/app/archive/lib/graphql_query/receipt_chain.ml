open Coda_base
open Signature_lib

module Get =
[%graphql
{|
query query_receipt_chain($receipt_chain: String!) {
  receipt_chain_hashes(where: {hash: {_eq: $receipt_chain}}) {
      blocks_user_commands {
        user_command_payload: user_command {
            fee @bsDecoder (fn: "Base_types.Fee.deserialize")
            hash @bsDecoder(fn: "Transaction_hash.of_base58_check_exn")
            memo @bsDecoder(fn: "User_command_memo.of_string")
            nonce @bsDecoder (fn: "Base_types.Nonce.deserialize")
            receiver: publicKeyByReceiver {
              value @bsDecoder (fn: "Public_key.Compressed.of_base58_check_exn")
            } 
            typ @bsDecoder (fn: "Base_types.User_command_type.decode")
            amount @bsDecoder (fn: "Base_types.Amount.deserialize")
        }
      }
      receipt_chain_hash {
        parent_hash: hash @bsDecoder (fn: "Receipt.Chain_hash.of_string")
      }
  }
}

|}]
