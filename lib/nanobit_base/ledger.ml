open Core
open Snark_params

include Merkle_ledger.Ledger.Make
    (struct
      type account = Account.t [@@deriving sexp]
      type hash = Tick.Pedersen.Digest.t [@@deriving sexp]

      let empty_hash =
        Tick.Pedersen.hash_bigstring (Bigstring.of_string "nothing up my sleeve")

      let merge t1 t2 =
        let open Tick.Pedersen in
        hash_fold params (fun ~init ~f ->
          let init = Digest.Bits.fold t1 ~init ~f in
          Digest.Bits.fold t2 ~init ~f)

      let hash_account account =
        Tick.Pedersen.hash_fold Tick.Pedersen.params
          (Account.fold_bits account)
    end)
    (struct let max_depth = ledger_depth end)
    (Public_key.Compressed)

let apply_transaction ledger (transaction : Transaction.t) =
  let error s = Or_error.errorf "Ledger.apply_transaction: %s" s in
  if Transaction.check_signature transaction
  then begin
    let sender = Public_key.compress transaction.sender in
    let { Transaction.Payload.fee=_; amount; receiver } = transaction.payload in
    begin match get ledger sender, get ledger receiver with
    | None, Some _ -> error "sender not found"
    | Some _, None -> error "receiver not found"
    | None, None -> error "neither sender nor receiver found"
    | Some sender_account, Some receiver_account ->
      update ledger sender
        { sender_account with
          balance = Unsigned.UInt64.sub sender_account.balance amount
        };
      update ledger receiver
        { receiver_account with
          balance = Unsigned.UInt64.add receiver_account.balance amount
        };
      Ok ()
    end
  end
  else error "bad signature"
