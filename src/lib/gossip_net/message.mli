module Master : sig
  module T : sig
    type msg =
      | New_state of Mina_transition.External_transition.t
      | Snark_pool_diff of Network_pool.Snark_pool.Resource_pool.Diff.t
      | Transaction_pool_diff of
          Network_pool.Transaction_pool.Resource_pool.Diff.t

    val msg_to_yojson : msg -> Yojson.Safe.t

    val msg_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> msg

    val sexp_of_msg : msg -> Ppx_sexp_conv_lib.Sexp.t
  end

  val name : string

  module Caller = T
  module Callee = T
end

type msg = Master.T.msg =
  | New_state of Mina_transition.External_transition.t
  | Snark_pool_diff of Network_pool.Snark_pool.Resource_pool.Diff.t
  | Transaction_pool_diff of Network_pool.Transaction_pool.Resource_pool.Diff.t

val msg_to_yojson : msg -> Yojson.Safe.t

val msg_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> msg

val sexp_of_msg : msg -> Ppx_sexp_conv_lib.Sexp.t

module Register : functor
  (Version : sig
     val version : int

     type msg

     val bin_shape_msg : Core_kernel.Bin_prot.Shape.t

     val bin_size_msg : msg Core_kernel.Bin_prot.Size.sizer

     val bin_write_msg : msg Core_kernel.Bin_prot.Write.writer

     val bin_writer_msg : msg Core_kernel.Bin_prot.Type_class.writer

     val bin_read_msg : msg Core_kernel.Bin_prot.Read.reader

     val __bin_read_msg__ : (int -> msg) Core_kernel.Bin_prot.Read.reader

     val bin_reader_msg : msg Core_kernel.Bin_prot.Type_class.reader

     val bin_msg : msg Core_kernel.Bin_prot.Type_class.t

     val msg_of_caller_model : Master.T.msg -> msg

     val callee_model_of_msg : msg -> Master.T.msg
   end)
  -> sig
  val rpc : Version.msg Async_rpc_kernel__.Rpc.One_way.t
end

val dispatch_multi :
     Async_rpc_kernel__Versioned_rpc.Connection_with_menu.t
  -> msg
  -> unit Core_kernel.Or_error.t

val implement_multi :
     ?log_not_previously_seen_version:(name:string -> int -> unit)
  -> ('state -> version:int -> msg -> unit)
  -> 'state Async_rpc_kernel__.Rpc.Implementation.t list

val rpcs : unit -> Async_rpc_kernel__.Rpc.Any.t list

val versions : unit -> Core_kernel.Int.Set.t

val name : string

module V1 : sig
  module T : sig
    type msg = Master.T.msg =
      | New_state of Mina_transition.External_transition.Stable.V1.t
      | Snark_pool_diff of Network_pool.Snark_pool.Diff_versioned.Stable.V1.t
      | Transaction_pool_diff of
          Network_pool.Transaction_pool.Diff_versioned.Stable.V1.t

    val bin_shape_msg : Core_kernel.Bin_prot.Shape.t

    val bin_size_msg : msg Core_kernel.Bin_prot.Size.sizer

    val bin_write_msg : msg Core_kernel.Bin_prot.Write.writer

    val bin_writer_msg : msg Core_kernel.Bin_prot.Type_class.writer

    val __bin_read_msg__ : (int -> msg) Core_kernel.Bin_prot.Read.reader

    val bin_read_msg : msg Core_kernel.Bin_prot.Read.reader

    val bin_reader_msg : msg Core_kernel.Bin_prot.Type_class.reader

    val bin_msg : msg Core_kernel.Bin_prot.Type_class.t

    val msg_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> msg

    val sexp_of_msg : msg -> Ppx_sexp_conv_lib.Sexp.t

    val version : int

    val __ : unit

    val callee_model_of_msg : 'a -> 'a

    val msg_of_caller_model : 'a -> 'a
  end

  val rpc : msg Async_rpc_kernel__.Rpc.One_way.t

  val summary : msg -> string
end

module Latest = V1

val summary : msg -> string
