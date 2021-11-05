open Core_kernel

type t = Event_type_logger | Event_type_puppeteer [@@deriving yojson]

module type Event_type_intf = sig
  type t

  val name : string

  val parse : 'a -> t Or_error.t
end
