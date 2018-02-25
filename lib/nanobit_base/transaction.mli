open Core_kernel

(* A Transaction needs a sender, receiver, amount, fee, and the designated
 * notary who will process the transaction in exchange for the fee (as long as
 * the notary designates the fee to be acceptable.
 *
 * The actual data looks something like this:
 *
 *   -------------------
 *   |signature        |
 *   -------------------
 *   |  -------------  |
 *   |  |signature  |  |
 *   |  -------------  |
 *   |  |sender     |  |
 *   |  |receiver   |  |
 *   |  |amount     |  |
 *   |  |fee        |  |
 *   |  -------------  |
 *   |notary           |
 *   ------------------
 *
 * It's important for the sender to sign a transaction so others cannot tamper
 * with it. The interesting bit is why the double-signatures:
 *
 * Since we know we don't need the notary address during the snarking of
 * transactions and we want to minimize the amount of data during snarking, we'd
 * like to be able to consider the rest of the transaction separately (let's
 * call it the payload). This payload needs to be signed as well! Thus we
 * re-sign the transaction structure again once we add the notary.
 *)

type addr = Public_key.Compressed.t [@@deriving bin_io]

module Payload : sig
  module Unsigned : sig
    type t =
      { sender : addr
      ; receiver : addr
      ; amount : Int64.t
      ; fee : Int32.t
      }
    [@@deriving bin_io]
  end
  include Signature_intf.S with type t = Unsigned.t
end

module Unsigned : sig
  type t =
    { payload: Payload.t
    ; notary : addr
    }
  [@@deriving bin_io]
end
include Signature_intf.S with type t = Unsigned.t

val create :
  sender:addr ->
  receiver:addr ->
  fee:Int32.t ->
  amount:Int64.t ->
  notary:addr ->
  t

