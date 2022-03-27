val decorate_dispatch :
  name:string -> ('q, 'r) Intf.dispatch -> ('q, 'r) Intf.dispatch

val decorate_impl :
  name:string -> ('q, 'r, 'state) Intf.impl -> ('q, 'r, 'state) Intf.impl

module Plain : sig
  module Extend : functor (Rpc : Intf.Rpc.S) -> sig
    val dispatch_multi :
      (Rpc.Caller.query, Rpc.Caller.response) Perf_histograms__Intf.dispatch

    val implement_multi :
         ?log_not_previously_seen_version:(name:string -> int -> unit)
      -> ( Rpc.Callee.query
         , Rpc.Callee.response
         , 'state )
         Perf_histograms__Intf.impl
      -> 'state Async.Rpc.Implementation.t list
  end

  module Decorate_bin_io : functor
    (M : Intf.Rpc.S)
    (Rpc : Perf_histograms__.Intf.Versioned_rpc(M).S)
    -> sig
    type query = Rpc.query

    val bin_shape_query : Bin_prot.Shape.t

    val bin_size_query : query Bin_prot.Size.sizer

    val bin_write_query : query Bin_prot.Write.writer

    val bin_writer_query : query Bin_prot.Type_class.writer

    val bin_read_query : query Bin_prot.Read.reader

    val __bin_read_query__ : (int -> query) Bin_prot.Read.reader

    val bin_reader_query : query Bin_prot.Type_class.reader

    val bin_query : query Bin_prot.Type_class.t

    type response = Rpc.response

    val bin_shape_response : Bin_prot.Shape.t

    val bin_size_response : response Bin_prot.Size.sizer

    val __bin_read_response__ : (int -> response) Bin_prot.Read.reader

    val version : int

    val query_of_caller_model : M.Caller.query -> query

    val callee_model_of_query : query -> M.Callee.query

    val response_of_callee_model : M.Callee.response -> response

    val caller_model_of_response : response -> M.Caller.response

    module type Running_stats = sig
      val max_value : unit -> int

      val average_value : unit -> float

      val update_stats : int -> unit
    end

    module Make_stats () : Running_stats

    module Read_stats : Running_stats

    val bin_read_response :
      Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> response

    val bin_reader_response : response Core.Bin_prot.Type_class.reader

    module Write_stats : Running_stats

    val bin_write_response :
         Bin_prot.Common.buf
      -> pos:Bin_prot.Common.pos
      -> response
      -> Bin_prot.Common.pos

    val bin_writer_response : response Core.Bin_prot.Type_class.writer

    val bin_response : response Core.Bin_prot.Type_class.t
  end
end
