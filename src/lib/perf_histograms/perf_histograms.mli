open Core_kernel

module Rpc : sig
  module Plain : sig
    module Extend (Rpc : Intf.Rpc.S) :
      Intf.Patched.S
        with type callee_query := Rpc.Callee.query
         and type callee_response := Rpc.Callee.response
         and type caller_query := Rpc.Caller.query
         and type caller_response := Rpc.Caller.response

    module Decorate_bin_io (M : Intf.Rpc.S) (Rpc : Intf.Versioned_rpc(M).S) :
      Intf.Versioned_rpc(M).S
    [@@warning "-67"]
  end
end

module Report : sig
  type t =
    { values : int list
    ; intervals : (Time.Span.t * Time.Span.t) list
    ; underflow : int
    ; overflow : int
    }
  [@@deriving yojson, bin_io, fields]
end

val add_span : name:string -> Time.Span.t -> unit

val report : name:string -> Report.t option

val wipe : unit -> unit
