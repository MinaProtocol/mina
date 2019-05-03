open Coda_base
open Signature_lib

module type S = sig
  type t

  type time

  val create : ?directory_name:string -> unit -> t

  val close : t -> unit

  val add : t -> Transaction.t -> time -> unit

  val get_transactions : t -> Public_key.Compressed.t -> Transaction.t list

  val get_earlier_transactions :
       t
    -> Public_key.Compressed.t
    -> Transaction.t
    -> int
    -> Transaction.t list
       * [`Has_earlier_page of bool]
       * [`Has_later_page of bool]

  val get_later_transactions :
       t
    -> Public_key.Compressed.t
    -> Transaction.t
    -> int
    -> Transaction.t list
       * [`Has_earlier_page of bool]
       * [`Has_later_page of bool]
end
