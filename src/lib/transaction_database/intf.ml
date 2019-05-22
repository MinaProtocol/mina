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

  val get_transactions : t -> Public_key.Compressed.t -> transaction list

  val get_earlier_transactions :
       t
    -> Public_key.Compressed.t
    -> transaction option
    -> int option
    -> transaction list
       * [`Has_earlier_page of bool]
       * [`Has_later_page of bool]

  val get_later_transactions :
       t
    -> Public_key.Compressed.t
    -> transaction option
    -> int option
    -> transaction list
       * [`Has_earlier_page of bool]
       * [`Has_later_page of bool]
end

module type Pagination = sig
  type time

  type value

  type value_with_time_witness

  type t =
    { user_values:
        (value * time, value_with_time_witness) Core.Set.t
        Public_key.Compressed.Table.t
    ; all_values: (value, time) Hashtbl.t }

  val get_total_values : t -> Public_key.Compressed.t -> int option

  (** [get_values t pk] queries all the values involving [pk] as a
      participant. *)
  val get_values : t -> Public_key.Compressed.t -> value list

  (** [get_earlier_values t pk value n] queries [n] values (or all if
      n is None) involving peer, [pk], added before [value] (exclusively) if
      [value] is non-null. Otherwise, it queries the [n] latest values. It
      indicates if there are any earlier values added before the earliest
      value in the query. It also indicates any values that
      occurred after [value]. It outputs an empty list of values if there
      are no values related to [pk] in the database *)
  val get_earlier_values :
       t
    -> Public_key.Compressed.t
    -> value option
    -> int option
    -> value list * [`Has_earlier_page of bool] * [`Has_later_page of bool]

  (** [get_later_values t pk value n] queries [n] values (or all if n
      is None) involving peer, [pk], added after [value], (exclusively) if [value]
      is non-null. Otherwise, it queries the [n] earliest values. It
      would indicate if there are any later values added after the latest
      value in the query. It also indicates any values that
      occurred before [value]. It would output an empty list of values if
      there are no values related to [pk] in the database *)
  val get_later_values :
       t
    -> Public_key.Compressed.t
    -> value option
    -> int option
    -> value list * [`Has_earlier_page of bool] * [`Has_later_page of bool]
end
