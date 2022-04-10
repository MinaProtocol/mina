module Types = Types
module Client = Client

module Get_transaction_status : sig
  type query = Mina_base.Signed_command.Stable.Latest.t

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response =
    Transaction_inclusion_status.State.Stable.Latest.t Core_kernel.Or_error.t

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Send_user_commands : sig
  type query = User_command_input.Stable.Latest.t list

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response =
    ( Network_pool.Transaction_pool.Diff_versioned.Stable.Latest.t
    * Network_pool.Transaction_pool.Diff_versioned.Rejected.Stable.Latest.t )
    Core_kernel.Or_error.t

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Get_ledger : sig
  type query = Mina_base.State_hash.Stable.Latest.t option

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = Mina_base.Account.Stable.Latest.t list Core_kernel.Or_error.t

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Get_snarked_ledger : sig
  type query = Mina_base.State_hash.Stable.Latest.t option

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = Mina_base.Account.Stable.Latest.t list Core_kernel.Or_error.t

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Get_staking_ledger : sig
  type query = Current | Next

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = Mina_base.Account.Stable.Latest.t list Core_kernel.Or_error.t

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Get_balance : sig
  type query = Mina_base.Account_id.Stable.Latest.t

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = Currency.Balance.Stable.Latest.t option Core_kernel.Or_error.t

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Get_trust_status : sig
  type query = Async.Unix.Inet_addr.t

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response =
    ( Network_peer.Peer.Stable.Latest.t
    * Trust_system.Peer_status.Stable.Latest.t )
    list

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Get_trust_status_all : sig
  type query = unit

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response =
    ( Network_peer.Peer.Stable.Latest.t
    * Trust_system.Peer_status.Stable.Latest.t )
    list

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Reset_trust_status : sig
  type query = Get_trust_status.query

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response =
    ( Network_peer.Peer.Stable.Latest.t
    * Trust_system.Peer_status.Stable.Latest.t )
    list

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Chain_id_inputs : sig
  type query = Get_trust_status_all.query

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response =
    Mina_base.State_hash.Stable.Latest.t * Genesis_constants.t * string list

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Verify_proof : sig
  type query =
    Get_balance.query
    * Mina_base.User_command.Stable.Latest.t
    * ( Mina_base.Receipt.Chain_hash.Stable.Latest.t
      * Mina_base.User_command.Stable.Latest.t list )

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = Get_trust_status_all.query Core_kernel.Or_error.t

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Get_inferred_nonce : sig
  type query = Get_balance.query

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response =
    Mina_base.Account.Nonce.Stable.Latest.t option Core_kernel.Or_error.t

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Get_nonce : sig
  type query = Get_inferred_nonce.query

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response =
    Mina_base.Account.Nonce.Stable.Latest.t option Core_kernel.Or_error.t

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Get_status : sig
  type query = [ `None | `Performance ]

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : 'a -> pos_ref:'b -> int -> [> `None | `Performance ]

  val bin_read_query :
       Bin_prot.Common.buf
    -> pos_ref:Bin_prot.Common.pos_ref
    -> [> `None | `Performance ]

  val bin_reader_query :
    [> `None | `Performance ] Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : 'a -> int

  val bin_write_query :
       Bin_prot.Common.buf
    -> pos:Bin_prot.Common.pos
    -> [< `None | `Performance ]
    -> Bin_prot.Common.pos

  val bin_writer_query :
    [< `None | `Performance ] Core_kernel.Bin_prot.Type_class.writer

  val bin_query : [ `None | `Performance ] Core_kernel.Bin_prot.Type_class.t

  type response = Types.Status.t

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Clear_hist_status : sig
  type query = [ `None | `Performance ]

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : 'a -> pos_ref:'b -> int -> [> `None | `Performance ]

  val bin_read_query :
       Bin_prot.Common.buf
    -> pos_ref:Bin_prot.Common.pos_ref
    -> [> `None | `Performance ]

  val bin_reader_query :
    [> `None | `Performance ] Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : 'a -> int

  val bin_write_query :
       Bin_prot.Common.buf
    -> pos:Bin_prot.Common.pos
    -> [< `None | `Performance ]
    -> Bin_prot.Common.pos

  val bin_writer_query :
    [< `None | `Performance ] Core_kernel.Bin_prot.Type_class.writer

  val bin_query : [ `None | `Performance ] Core_kernel.Bin_prot.Type_class.t

  type response = Get_status.response

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Get_public_keys_with_details : sig
  type query = Get_trust_status_all.query

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = (string * int * int) list Core_kernel.Or_error.t

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Get_public_keys : sig
  type query = Get_trust_status_all.query

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = string list Core_kernel.Or_error.t

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Stop_daemon : sig
  type query = Get_trust_status_all.query

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = query

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (response, response) Async.Rpc.Rpc.t
end

module Snark_job_list : sig
  type query = Stop_daemon.response

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = string Core_kernel.Or_error.t

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Snark_pool_list : sig
  type query = Stop_daemon.response

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = string

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Start_tracing : sig
  type query = Stop_daemon.response

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = query

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (response, response) Async.Rpc.Rpc.t
end

module Stop_tracing : sig
  type query = Stop_daemon.response

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = query

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (response, response) Async.Rpc.Rpc.t
end

module Visualization : sig
  module Frontier : sig
    type query = Snark_pool_list.response

    val bin_shape_query : Core_kernel.Bin_prot.Shape.t

    val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

    val bin_read_query : query Core_kernel.Bin_prot.Read.reader

    val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

    val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

    val bin_write_query : query Core_kernel.Bin_prot.Write.writer

    val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

    val bin_query : query Core_kernel.Bin_prot.Type_class.t

    type response = [ `Active of Stop_tracing.response | `Bootstrapping ]

    val bin_shape_response : Core_kernel.Bin_prot.Shape.t

    val __bin_read_response__ :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos_ref
      -> int
      -> [> `Active of Core_kernel__.Import.unit | `Bootstrapping ]

    val bin_read_response :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos_ref
      -> [> `Active of Core_kernel__.Import.unit | `Bootstrapping ]

    val bin_reader_response :
      [> `Active of Core_kernel__.Import.unit | `Bootstrapping ]
      Core_kernel.Bin_prot.Type_class.reader

    val bin_size_response : [> `Active of Core_kernel__.Import.unit ] -> int

    val bin_write_response :
         Bin_prot.Common.buf
      -> pos:Bin_prot.Common.pos
      -> [< `Active of Core_kernel__.Import.unit | `Bootstrapping ]
      -> Bin_prot.Common.pos

    val bin_writer_response :
      [< `Active of Core_kernel__.Import.unit | `Bootstrapping > `Active ]
      Core_kernel.Bin_prot.Type_class.writer

    val bin_response :
      [ `Active of Core_kernel__.Import.unit | `Bootstrapping ]
      Core_kernel.Bin_prot.Type_class.t

    val rpc : (query, response) Async.Rpc.Rpc.t
  end

  module Registered_masks : sig
    type query = Snark_pool_list.response

    val bin_shape_query : Core_kernel.Bin_prot.Shape.t

    val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

    val bin_read_query : query Core_kernel.Bin_prot.Read.reader

    val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

    val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

    val bin_write_query : query Core_kernel.Bin_prot.Write.writer

    val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

    val bin_query : query Core_kernel.Bin_prot.Type_class.t

    type response = Stop_tracing.response

    val bin_shape_response : Core_kernel.Bin_prot.Shape.t

    val __bin_read_response__ :
      (int -> response) Core_kernel.Bin_prot.Read.reader

    val bin_read_response : response Core_kernel.Bin_prot.Read.reader

    val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

    val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

    val bin_write_response : response Core_kernel.Bin_prot.Write.writer

    val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

    val bin_response : response Core_kernel.Bin_prot.Type_class.t

    val rpc : (query, response) Async.Rpc.Rpc.t
  end
end

module Add_trustlist : sig
  type query = Async.Unix.Cidr.t

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = Stop_tracing.response Core_kernel.Or_error.t

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Remove_trustlist : sig
  type query = Add_trustlist.query

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = Stop_tracing.response Core_kernel.Or_error.t

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Get_trustlist : sig
  type query = Stop_tracing.response

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = Remove_trustlist.query list

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Get_node_status : sig
  type query = Mina_net2.Multiaddr.t list option

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response =
    Mina_networking.Rpcs.Get_node_status.Node_status.Stable.Latest.t
    Core_kernel.Or_error.t
    list

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end

module Get_object_lifetime_statistics : sig
  type query = Stop_tracing.response

  val bin_shape_query : Core_kernel.Bin_prot.Shape.t

  val __bin_read_query__ : (int -> query) Core_kernel.Bin_prot.Read.reader

  val bin_read_query : query Core_kernel.Bin_prot.Read.reader

  val bin_reader_query : query Core_kernel.Bin_prot.Type_class.reader

  val bin_size_query : query Core_kernel.Bin_prot.Size.sizer

  val bin_write_query : query Core_kernel.Bin_prot.Write.writer

  val bin_writer_query : query Core_kernel.Bin_prot.Type_class.writer

  val bin_query : query Core_kernel.Bin_prot.Type_class.t

  type response = Snark_pool_list.response

  val bin_shape_response : Core_kernel.Bin_prot.Shape.t

  val __bin_read_response__ : (int -> response) Core_kernel.Bin_prot.Read.reader

  val bin_read_response : response Core_kernel.Bin_prot.Read.reader

  val bin_reader_response : response Core_kernel.Bin_prot.Type_class.reader

  val bin_size_response : response Core_kernel.Bin_prot.Size.sizer

  val bin_write_response : response Core_kernel.Bin_prot.Write.writer

  val bin_writer_response : response Core_kernel.Bin_prot.Type_class.writer

  val bin_response : response Core_kernel.Bin_prot.Type_class.t

  val rpc : (query, response) Async.Rpc.Rpc.t
end
