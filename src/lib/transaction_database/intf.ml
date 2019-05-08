open Coda_base
open Signature_lib

(** Transaction database is a database that stores transactions for a client.
    It would query a set of transactions involving a peer with a certain public
    key. The main purpose for this database is for a developer to store
    transactions and perform pagination queries of transactions via GraphQL *)
module type S = sig
  type t

  type time

  val create : Logger.t -> string -> t

  val close : t -> unit

  val add : t -> Transaction.t -> time -> unit

  (** [get_transactions t pk] would query all the transactions involving [pk]
      as a participant. Specifically, it would query all the transactions [pk]
      sent or received. *)
  val get_transactions : t -> Public_key.Compressed.t -> Transaction.t list

  (** [get_earlier_transactions t pk txn n] would query [n] transactions
      involving peer, [pk], that were added before [txn], exclusively. It would
      indicate if there are any earlier transactions that were added before the
      earliest transaction in the query. It would also indicate any
      transactions that occurred after [txn]. If there are no transactions
      related to [pk] in the database, it would output an empty list of
      transactions. *)
  val get_earlier_transactions :
       t
    -> Public_key.Compressed.t
    -> Transaction.t
    -> int
    -> Transaction.t list
       * [`Has_earlier_page of bool]
       * [`Has_later_page of bool]

  (* [get_later_transactions t pk txn n] would query [n] transactions involving
     peer, [pk], that were added after [txn], exclusively. It would indicate if
     there are any later transactions that were added after the latest
     transaction in the query. It would also indicate any transactions that
     occurred before [txn]. If there are no transactions related to [pk] in the
     database, it would output an empty list of transactions. *)
  val get_later_transactions :
       t
    -> Public_key.Compressed.t
    -> Transaction.t
    -> int
    -> Transaction.t list
       * [`Has_earlier_page of bool]
       * [`Has_later_page of bool]
end
