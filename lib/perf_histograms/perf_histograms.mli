open Core_kernel

module Report : sig
  type t =
    { values: int list
    ; intervals: (Time.Span.t * Time.Span.t) list
    ; underflow: int
    ; overflow: int }
  [@@deriving yojson, bin_io]
end

val add_span : name:string -> Time.Span.t -> unit

val report : name:string -> Report.t option
