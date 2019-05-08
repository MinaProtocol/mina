open Coda_base
open Signature_lib

(** Transaction database is a database that stores transactions for a client.
    It queries a set of transactions involving a peer with a certain public
    key. This database allows a developer to store transactions and perform
    pagination queries of transactions via GraphQL *)
module type S = sig
  type t

  type time

  val create : Logger.t -> string -> t

  val close : t -> unit

  val add : t -> Transaction.t -> time -> unit

  (** [get_transactions t pk] queries all the transactions involving [pk] as a
      participant. Specifically, it queries all the transactions [pk] sent or
      received. *)
  val get_transactions : t -> Public_key.Compressed.t -> Transaction.t list

  (** [get_earlier_transactions t pk txn n] queries [n] transactions involving
      peer, [pk], added before [txn], exclusively. It indicates if there are
      any earlier transactions added before the earliest transaction in the
      query. It also indicates any transactions that occurred after [txn]. It
      outputs an empty list of transactions if there are no transactions
      related to [pk] in the database *)
  val get_earlier_transactions :
       t
    -> Public_key.Compressed.t
    -> Transaction.t
    -> int
    -> Transaction.t list
       * [`Has_earlier_page of bool]
       * [`Has_later_page of bool]

  (** [get_later_transactions t pk txn n] queries [n] transactions involving
      peer, [pk], added after [txn], exclusively. It would indicate if there
      are any later transactions added after the latest transaction in the
      query. It also indicates any transactions that occurred before [txn]. It
      would output an empty list of transactions if there are no transactions
      related to [pk] in the database *)
  val get_later_transactions :
       t
    -> Public_key.Compressed.t
    -> Transaction.t
    -> int
    -> Transaction.t list
       * [`Has_earlier_page of bool]
       * [`Has_later_page of bool]
end
