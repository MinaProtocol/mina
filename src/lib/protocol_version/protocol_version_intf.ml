module type Full = sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t [@@deriving compare, equal, sexp, yojson]
    end
  end]

  val transaction : t -> int

  val network : t -> int

  val patch : t -> int

  val create : transaction:int -> network:int -> patch:int -> t

  val current : t

  val get_proposed_opt : unit -> t option

  val set_proposed_opt : t option -> unit

  (** a daemon can accept blocks or RPC responses with compatible protocol versions *)
  val compatible_with_daemon : t -> bool

  val to_string : t -> string

  val of_string_exn : string -> t

  val of_string_opt : string -> t option

  (** useful when deserializing, could contain negative integers *)
  val is_valid : t -> bool
end
