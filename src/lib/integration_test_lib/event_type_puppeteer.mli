open Core_kernel
open Mina_base

module type Event_type_puppeteer_intf = sig
  type t [@@deriving to_yojson]

  val name : string

  val puppeteer_event_type : string option

  val parse : Puppeteer_message.t -> t Or_error.t
end

module Log_error : sig
  type t = Puppeteer_message.t

  include Event_type_puppeteer_intf with type t := t
end

module Node_offline : sig
  type t = unit

  include Event_type_puppeteer_intf with type t := t
end

type 'a t = Log_error : Log_error.t t | Node_offline : Node_offline.t t

val to_string : 'a t -> string

type existential = Event_type_puppeteer : 'a t -> existential
[@@deriving sexp, to_yojson]

val all_event_types : existential list

val event_type_puppeteer_module :
  'a t -> (module Event_type_puppeteer_intf with type t = 'a)

val existential_to_string : existential -> string

val existential_of_string_exn : string -> existential

val to_puppeteer_event_type : existential -> string option

val of_puppeteer_event_type : string -> existential option

module Map : Map.S with type Key.t = existential

type event = Event : 'a t * 'a -> event [@@deriving to_yojson]

val type_of_event : event -> existential

val parse_event : Puppeteer_message.t -> event Or_error.t

val dispatch_exn : 'a t -> 'a -> 'b t -> ('b -> 'c) -> 'c
