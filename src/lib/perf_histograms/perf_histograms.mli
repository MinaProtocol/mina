open Core_kernel

module Rpc : sig
  module Plain : sig
    module Extend (Rpc : Intf.Rpc.S) :
      Intf.Patched.S
      with type callee_query := Rpc.Callee.query
       and type callee_response := Rpc.Callee.response
       and type caller_query := Rpc.Caller.query
       and type caller_response := Rpc.Caller.response

    module Decorate_bin_io (Rpc : Intf.Versioned_rpc.S) : sig
      val bin_write_response : Rpc.response Bin_prot.Write.writer

      val bin_writer_response : Rpc.response Bin_prot.Type_class.writer

      val bin_read_response : Rpc.response Bin_prot.Read.reader

      val bin_reader_response : Rpc.response Bin_prot.Type_class.reader

      val bin_response : Rpc.response Bin_prot.Type_class.t
    end
  end
end

module Report : sig
  type t =
    { values: int list
    ; intervals: (Time.Span.t * Time.Span.t) list
    ; underflow: int
    ; overflow: int }
  [@@deriving yojson, bin_io, fields]
end

val add_span : name:string -> Time.Span.t -> unit

val report : name:string -> Report.t option

val wipe : unit -> unit
