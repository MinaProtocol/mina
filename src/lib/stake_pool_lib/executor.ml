open Core
open Coda_base
open Signature_lib
open Operators

module Pending_payout = struct
  type t =
    { receiver: Public_key.Compressed.t
    ; amount: Currency.Amount.t
    ; nonce: Account.Nonce.t }
end

type t =
  { progress: Coda_numbers.Length.t Account.Nonce.Table.t
  ; payouts: Pending_payout.t Queue.t
  ; mutable next_nonce: Account.Nonce.t
  ; broadcast: User_command_payload.t -> unit }

let create ~account_nonce ~broadcast =
  { progress= Account.Nonce.Table.create ()
  ; payouts= Queue.create ()
  ; next_nonce= account_nonce
  ; broadcast }

let long_tip_confirm t ~account_nonce ~length =
  Hashtbl.update t.progress account_nonce ~f:(function
    | None -> length
    | Some l -> Coda_numbers.Length.max l length )

let dequeue_if q ~f =
  let open Option.Let_syntax in
  let%bind x = Queue.peek q in
  if f x then Some (Queue.dequeue_exn q) else None

let add_opt f x = Option.value_map ~default:x ~f:(f x)

let locked_tip_confirm t ~account_nonce =
  Hashtbl.filter_keys_inplace t.progress ~f:(fun n ->
      Account.Nonce.(n >= account_nonce) ) ;
  let res = Public_key.Compressed.Table.create () in
  let rec clear_payouts () =
    match
      dequeue_if t.payouts ~f:(fun p -> Account.Nonce.(p.nonce < account_nonce))
    with
    | None -> ()
    | Some {receiver; amount; nonce= _} ->
        Hashtbl.update res receiver ~f:(add_opt ( +! ) amount) ;
        clear_payouts ()
  in
  clear_payouts () ; res

let payout t ~receiver ~amount =
  let nonce = t.next_nonce in
  Queue.enqueue t.payouts {receiver; amount; nonce}
