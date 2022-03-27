type ('q, 'r) dispatch =
     Async.Versioned_rpc.Connection_with_menu.t
  -> 'q
  -> 'r Async.Deferred.Or_error.t

type ('q, 'r, 'state) impl = 'state -> version:int -> 'q -> 'r Async.Deferred.t

module Rpc : sig
  module type S = sig
    module Caller : sig
      type query

      type response
    end

    module Callee : sig
      type query

      type response
    end

    val dispatch_multi :
         Async_rpc_kernel__Versioned_rpc.Connection_with_menu.t
      -> Caller.query
      -> Caller.response Core_kernel.Or_error.t Async_kernel.Deferred.t

    val implement_multi :
         ?log_not_previously_seen_version:(name:string -> int -> unit)
      -> (   'state
          -> version:int
          -> Callee.query
          -> Callee.response Async_kernel.Deferred.t)
      -> 'state Async_rpc_kernel__.Rpc.Implementation.t list

    val rpcs : unit -> Async_rpc_kernel__.Rpc.Any.t list

    val versions : unit -> Core_kernel.Int.Set.t

    val name : string
  end
end

module Versioned_rpc : functor (M : Rpc.S) -> sig
  module type S = sig
    type query

    val bin_shape_query : Bin_prot.Shape.t

    val bin_size_query : query Bin_prot.Size.sizer

    val bin_write_query : query Bin_prot.Write.writer

    val bin_writer_query : query Bin_prot.Type_class.writer

    val bin_read_query : query Bin_prot.Read.reader

    val __bin_read_query__ : (int -> query) Bin_prot.Read.reader

    val bin_reader_query : query Bin_prot.Type_class.reader

    val bin_query : query Bin_prot.Type_class.t

    type response

    val bin_shape_response : Bin_prot.Shape.t

    val bin_size_response : response Bin_prot.Size.sizer

    val bin_write_response : response Bin_prot.Write.writer

    val bin_writer_response : response Bin_prot.Type_class.writer

    val bin_read_response : response Bin_prot.Read.reader

    val __bin_read_response__ : (int -> response) Bin_prot.Read.reader

    val bin_reader_response : response Bin_prot.Type_class.reader

    val bin_response : response Bin_prot.Type_class.t

    val version : int

    val query_of_caller_model : M.Caller.query -> query

    val callee_model_of_query : query -> M.Callee.query

    val response_of_callee_model : M.Callee.response -> response

    val caller_model_of_response : response -> M.Caller.response
  end
end

module Patched : sig
  module type S = sig
    type callee_query

    type callee_response

    type caller_query

    type caller_response

    val dispatch_multi : (caller_query, caller_response) dispatch

    val implement_multi :
         ?log_not_previously_seen_version:(name:string -> int -> unit)
      -> (callee_query, callee_response, 'state) impl
      -> 'state Async.Rpc.Implementation.t list
  end
end
