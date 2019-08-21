open Signature_lib

module type Pagination = sig
  type time

  type cursor

  type value

  type t

  val get_total_values : t -> Public_key.Compressed.t -> int option

  (** [get_values t pk] queries all the values involving [pk] as a
      participant. *)
  val get_values : t -> Public_key.Compressed.t -> value list

  (** [get_all_values t] queries all the values that are in the database  *)
  val get_all_values : t -> value list

  (** [get_earlier_values t pk cursor n] queries [n] values (or all if n is
      None) involving peer, [pk], added before the value corresponding to
      [cursor] (exclusively) if [cursor] is non-null. Otherwise, it queries the
      [n] latest values. It indicates if there are any earlier values added
      before the earliest value in the query. It also indicates any values that
      occurred after [cursor]. It outputs an empty list of values if there are
      no values related to [pk] in the database *)
  val get_earlier_values :
       t
    -> Public_key.Compressed.t
    -> cursor option
    -> int option
    -> value list * [`Has_earlier_page of bool] * [`Has_later_page of bool]

  (** [get_later_values t pk cursor n] queries [n] values (or all if n is None)
      involving peer, [pk], added after the value corresponding to [cursor],
      (exclusively) if [cursor] is non-null. Otherwise, it queries the [n]
      earliest values. It would indicate if there are any later values added
      after the latest value in the query. It also indicates any values that
      occurred before [cursor]. It would output an empty list of values if
      there are no values related to [pk] in the database *)
  val get_later_values :
       t
    -> Public_key.Compressed.t
    -> cursor option
    -> int option
    -> value list * [`Has_earlier_page of bool] * [`Has_later_page of bool]
end

(** Transaction database is a database that stores transactions for a client.
    It queries a set of transactions involving a peer with a certain public
    key. This database allows a developer to store transactions and perform
    pagination queries of transactions via GraphQL *)
module type Transaction = sig
  type t

  type time

  type transaction

  val create : logger:Logger.t -> string -> t

  val close : t -> unit

  val add : t -> transaction -> time -> unit

  include
    Pagination
    with type t := t
     and type time := time
     and type value := transaction
     and type cursor := transaction
end

module type External_transition = sig
  type t

  type filtered_external_transition

  type hash

  type time

  val create : logger:Logger.t -> string -> t

  val close : t -> unit

  val add :
    t -> (filtered_external_transition, hash) With_hash.t -> time -> unit

  include
    Pagination
    with type t := t
     and type time := time
     and type cursor := hash
     and type value := (filtered_external_transition, hash) With_hash.t
end
