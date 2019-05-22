open Signature_lib

(** Transaction database is a database that stores transactions for a client.
    It queries a set of transactions involving a peer with a certain public
    key. This database allows a developer to store transactions and perform
    pagination queries of transactions via GraphQL *)
module type S = sig
  type t

  type time

  type transaction

  val create : Logger.t -> string -> t

  val close : t -> unit

  val add : t -> transaction -> time -> unit

  val get_total_transactions : t -> Public_key.Compressed.t -> int option

  (** [get_transactions t pk] queries all the transactions involving [pk] as a
      participant. Specifically, it queries all the transactions [pk] sent or
      received. *)
  val get_transactions : t -> Public_key.Compressed.t -> transaction list

  (** [get_earlier_transactions t pk txn n] queries [n] transactions (or all if
      n is None) involving peer, [pk], added before [txn] (exclusively) if
      [txn] is non-null. Otherwise, it queries the [n] latest transactions. It
      indicates if there are any earlier transactions added before the earliest
      transaction in the query. It also indicates any transactions that
      occurred after [txn]. It outputs an empty list of transactions if there
      are no transactions related to [pk] in the database *)
  val get_earlier_transactions :
       t
    -> Public_key.Compressed.t
    -> transaction option
    -> int option
    -> transaction list
       * [`Has_earlier_page of bool]
       * [`Has_later_page of bool]

  (** [get_later_transactions t pk txn n] queries [n] transactions (or all if n
      is None) involving peer, [pk], added after [txn], (exclusively) if [txn]
      is non-null. Otherwise, it queries the [n] earliest transactions. It
      would indicate if there are any later transactions added after the latest
      transaction in the query. It also indicates any transactions that
      occurred before [txn]. It would output an empty list of transactions if
      there are no transactions related to [pk] in the database *)
  val get_later_transactions :
       t
    -> Public_key.Compressed.t
    -> transaction option
    -> int option
    -> transaction list
       * [`Has_earlier_page of bool]
       * [`Has_later_page of bool]
end
