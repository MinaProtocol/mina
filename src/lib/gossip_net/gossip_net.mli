type ban_creator = Gossip_net__Intf.ban_creator =
  { banned_peer : Network_peer.Peer.t; banned_until : Core_kernel.Time.t }

val banned_until : ban_creator -> Core_kernel.Time.t

val banned_peer : ban_creator -> Network_peer.Peer.t

module Fields_of_ban_creator = Gossip_net__Intf.Fields_of_ban_creator

type ban_notification = Gossip_net__Intf.ban_notification =
  { banned_peer : Network_peer.Peer.t; banned_until : Core_kernel.Time.t }

module type Gossip_net_intf = sig
  type t

  module Rpc_intf : Mina_base.Rpc_intf.Rpc_interface_intf

  val restart_helper : t -> unit

  val peers : t -> Network_peer.Peer.t list Async.Deferred.t

  val bandwidth_info :
       t
    -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
       Async.Deferred.Or_error.t

  val set_node_status : t -> string -> unit Async.Deferred.Or_error.t

  val get_peer_node_status :
    t -> Network_peer.Peer.t -> string Async.Deferred.Or_error.t

  val initial_peers : t -> Mina_net2.Multiaddr.t list

  val add_peer :
    t -> Network_peer.Peer.t -> is_seed:bool -> unit Async.Deferred.Or_error.t

  val connection_gating : t -> Mina_net2.connection_gating Async.Deferred.t

  val set_connection_gating :
       t
    -> Mina_net2.connection_gating
    -> Mina_net2.connection_gating Async.Deferred.t

  val random_peers : t -> int -> Network_peer.Peer.t list Async.Deferred.t

  val random_peers_except :
       t
    -> int
    -> except:Network_peer.Peer.Hash_set.t
    -> Network_peer.Peer.t list Async.Deferred.t

  val query_peer' :
       ?how:Async.Monad_sequence.how
    -> ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
    -> ?timeout:Core_kernel.Time.Span.t
    -> t
    -> Network_peer.Peer.Id.t
    -> ('q, 'r) Rpc_intf.rpc
    -> 'q list
    -> 'r list Mina_base.Rpc_intf.rpc_response Async.Deferred.t

  val query_peer :
       ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
    -> ?timeout:Core_kernel.Time.Span.t
    -> t
    -> Network_peer.Peer.Id.t
    -> ('q, 'r) Rpc_intf.rpc
    -> 'q
    -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t

  val query_random_peers :
       t
    -> int
    -> ('q, 'r) Rpc_intf.rpc
    -> 'q
    -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t Core_kernel.List.t
       Async.Deferred.t

  val broadcast : t -> Message.msg -> unit

  val on_first_connect : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

  val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

  val received_message_reader :
       t
    -> ( Message.msg Network_peer.Envelope.Incoming.t
       * Mina_net2.Validation_callback.t )
       Pipe_lib.Strict_pipe.Reader.t

  val ban_notification_reader :
    t -> ban_notification Pipe_lib.Linear_pipe.Reader.t
end

module Any = Any
module Libp2p = Libp2p
module Fake = Fake

module type S = sig
  module Rpc_intf : Mina_base.Rpc_intf.Rpc_interface_intf

  type ban_creator = Gossip_net__Intf.ban_creator =
    { banned_peer : Network_peer.Peer.t; banned_until : Core_kernel.Time.t }

  val banned_until : ban_creator -> Core_kernel.Time.t

  val banned_peer : ban_creator -> Network_peer.Peer.t

  module Fields_of_ban_creator : sig
    val names : string list

    val banned_until :
      ( [< `Read | `Set_and_create ]
      , ban_creator
      , Core_kernel.Time.t )
      Fieldslib.Field.t_with_perm

    val banned_peer :
      ( [< `Read | `Set_and_create ]
      , ban_creator
      , Network_peer.Peer.t )
      Fieldslib.Field.t_with_perm

    val make_creator :
         banned_peer:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Network_peer.Peer.t )
               Fieldslib.Field.t_with_perm
            -> 'a
            -> ('b -> Network_peer.Peer.t) * 'c)
      -> banned_until:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Core_kernel.Time.t )
               Fieldslib.Field.t_with_perm
            -> 'c
            -> ('b -> Core_kernel.Time.t) * 'd)
      -> 'a
      -> ('b -> ban_creator) * 'd

    val create :
         banned_peer:Network_peer.Peer.t
      -> banned_until:Core_kernel.Time.t
      -> ban_creator

    val map :
         banned_peer:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Network_peer.Peer.t )
               Fieldslib.Field.t_with_perm
            -> Network_peer.Peer.t)
      -> banned_until:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Core_kernel.Time.t )
               Fieldslib.Field.t_with_perm
            -> Core_kernel.Time.t)
      -> ban_creator

    val iter :
         banned_peer:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Network_peer.Peer.t )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> banned_until:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Core_kernel.Time.t )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> unit

    val fold :
         init:'a
      -> banned_peer:
           (   'a
            -> ( [< `Read | `Set_and_create ]
               , ban_creator
               , Network_peer.Peer.t )
               Fieldslib.Field.t_with_perm
            -> 'b)
      -> banned_until:
           (   'b
            -> ( [< `Read | `Set_and_create ]
               , ban_creator
               , Core_kernel.Time.t )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> 'c

    val map_poly :
         ([< `Read | `Set_and_create ], ban_creator, 'a) Fieldslib.Field.user
      -> 'a list

    val for_all :
         banned_peer:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Network_peer.Peer.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> banned_until:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Core_kernel.Time.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val exists :
         banned_peer:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Network_peer.Peer.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> banned_until:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Core_kernel.Time.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val to_list :
         banned_peer:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Network_peer.Peer.t )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> banned_until:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Core_kernel.Time.t )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> 'a list

    module Direct : sig
      val iter :
           ban_creator
        -> banned_peer:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Network_peer.Peer.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Network_peer.Peer.t
              -> unit)
        -> banned_until:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Core_kernel.Time.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Core_kernel.Time.t
              -> 'a)
        -> 'a

      val fold :
           ban_creator
        -> init:'a
        -> banned_peer:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Network_peer.Peer.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Network_peer.Peer.t
              -> 'b)
        -> banned_until:
             (   'b
              -> ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Core_kernel.Time.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Core_kernel.Time.t
              -> 'c)
        -> 'c

      val for_all :
           ban_creator
        -> banned_peer:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Network_peer.Peer.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Network_peer.Peer.t
              -> bool)
        -> banned_until:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Core_kernel.Time.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Core_kernel.Time.t
              -> bool)
        -> bool

      val exists :
           ban_creator
        -> banned_peer:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Network_peer.Peer.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Network_peer.Peer.t
              -> bool)
        -> banned_until:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Core_kernel.Time.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Core_kernel.Time.t
              -> bool)
        -> bool

      val to_list :
           ban_creator
        -> banned_peer:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Network_peer.Peer.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Network_peer.Peer.t
              -> 'a)
        -> banned_until:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Core_kernel.Time.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Core_kernel.Time.t
              -> 'a)
        -> 'a list

      val map :
           ban_creator
        -> banned_peer:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Network_peer.Peer.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Network_peer.Peer.t
              -> Network_peer.Peer.t)
        -> banned_until:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Core_kernel.Time.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Core_kernel.Time.t
              -> Core_kernel.Time.t)
        -> ban_creator

      val set_all_mutable_fields : 'a -> unit
    end
  end

  type ban_notification = Gossip_net__Intf.ban_notification =
    { banned_peer : Network_peer.Peer.t; banned_until : Core_kernel.Time.t }

  module type Gossip_net_intf = sig
    type t

    module Rpc_intf : Mina_base.Rpc_intf.Rpc_interface_intf

    val restart_helper : t -> unit

    val peers : t -> Network_peer.Peer.t list Async.Deferred.t

    val bandwidth_info :
         t
      -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
         Async.Deferred.Or_error.t

    val set_node_status : t -> string -> unit Async.Deferred.Or_error.t

    val get_peer_node_status :
      t -> Network_peer.Peer.t -> string Async.Deferred.Or_error.t

    val initial_peers : t -> Mina_net2.Multiaddr.t list

    val add_peer :
      t -> Network_peer.Peer.t -> is_seed:bool -> unit Async.Deferred.Or_error.t

    val connection_gating : t -> Mina_net2.connection_gating Async.Deferred.t

    val set_connection_gating :
         t
      -> Mina_net2.connection_gating
      -> Mina_net2.connection_gating Async.Deferred.t

    val random_peers : t -> int -> Network_peer.Peer.t list Async.Deferred.t

    val random_peers_except :
         t
      -> int
      -> except:Network_peer.Peer.Hash_set.t
      -> Network_peer.Peer.t list Async.Deferred.t

    val query_peer' :
         ?how:Async.Monad_sequence.how
      -> ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q list
      -> 'r list Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_peer :
         ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_random_peers :
         t
      -> int
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t Core_kernel.List.t
         Async.Deferred.t

    val broadcast : t -> Message.msg -> unit

    val on_first_connect : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val received_message_reader :
         t
      -> ( Message.msg Network_peer.Envelope.Incoming.t
         * Mina_net2.Validation_callback.t )
         Pipe_lib.Strict_pipe.Reader.t

    val ban_notification_reader :
      t -> ban_notification Pipe_lib.Linear_pipe.Reader.t
  end

  module Message : sig
    module Master : sig
      module T : sig
        type msg = Gossip_net__Message.Master.T.msg =
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
      | Transaction_pool_diff of
          Network_pool.Transaction_pool.Resource_pool.Diff.t

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
          | Snark_pool_diff of
              Network_pool.Snark_pool.Diff_versioned.Stable.V1.t
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
  end

  module Any : sig
    module type Implementation_intf = sig
      type t

      val restart_helper : t -> unit

      val peers : t -> Network_peer.Peer.t list Async.Deferred.t

      val bandwidth_info :
           t
        -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
           Async.Deferred.Or_error.t

      val set_node_status : t -> string -> unit Async.Deferred.Or_error.t

      val get_peer_node_status :
        t -> Network_peer.Peer.t -> string Async.Deferred.Or_error.t

      val initial_peers : t -> Mina_net2.Multiaddr.t list

      val add_peer :
           t
        -> Network_peer.Peer.t
        -> is_seed:bool
        -> unit Async.Deferred.Or_error.t

      val connection_gating : t -> Mina_net2.connection_gating Async.Deferred.t

      val set_connection_gating :
           t
        -> Mina_net2.connection_gating
        -> Mina_net2.connection_gating Async.Deferred.t

      val random_peers : t -> int -> Network_peer.Peer.t list Async.Deferred.t

      val random_peers_except :
           t
        -> int
        -> except:Network_peer.Peer.Hash_set.t
        -> Network_peer.Peer.t list Async.Deferred.t

      val query_peer' :
           ?how:Async.Monad_sequence.how
        -> ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
        -> ?timeout:Core_kernel.Time.Span.t
        -> t
        -> Network_peer.Peer.Id.t
        -> ('q, 'r) Rpc_intf.rpc
        -> 'q list
        -> 'r list Mina_base.Rpc_intf.rpc_response Async.Deferred.t

      val query_peer :
           ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
        -> ?timeout:Core_kernel.Time.Span.t
        -> t
        -> Network_peer.Peer.Id.t
        -> ('q, 'r) Rpc_intf.rpc
        -> 'q
        -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t

      val query_random_peers :
           t
        -> int
        -> ('q, 'r) Rpc_intf.rpc
        -> 'q
        -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t
           Core_kernel.List.t
           Async.Deferred.t

      val broadcast : t -> Message.msg -> unit

      val on_first_connect : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

      val on_first_high_connectivity :
        t -> f:(unit -> 'a) -> 'a Async.Deferred.t

      val received_message_reader :
           t
        -> ( Message.msg Network_peer.Envelope.Incoming.t
           * Mina_net2.Validation_callback.t )
           Pipe_lib.Strict_pipe.Reader.t

      val ban_notification_reader :
        t -> Intf.ban_notification Pipe_lib.Linear_pipe.Reader.t
    end

    type 't implementation = (module Implementation_intf with type t = 't)

    type t = Any : 't implementation * 't -> t

    val restart_helper : t -> unit

    val peers : t -> Network_peer.Peer.t list Async.Deferred.t

    val bandwidth_info :
         t
      -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
         Async.Deferred.Or_error.t

    val set_node_status : t -> string -> unit Async.Deferred.Or_error.t

    val get_peer_node_status :
      t -> Network_peer.Peer.t -> string Async.Deferred.Or_error.t

    val initial_peers : t -> Mina_net2.Multiaddr.t list

    val add_peer :
      t -> Network_peer.Peer.t -> is_seed:bool -> unit Async.Deferred.Or_error.t

    val connection_gating : t -> Mina_net2.connection_gating Async.Deferred.t

    val set_connection_gating :
         t
      -> Mina_net2.connection_gating
      -> Mina_net2.connection_gating Async.Deferred.t

    val random_peers : t -> int -> Network_peer.Peer.t list Async.Deferred.t

    val random_peers_except :
         t
      -> int
      -> except:Network_peer.Peer.Hash_set.t
      -> Network_peer.Peer.t list Async.Deferred.t

    val query_peer' :
         ?how:Async.Monad_sequence.how
      -> ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q list
      -> 'r list Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_peer :
         ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_random_peers :
         t
      -> int
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t Core_kernel.List.t
         Async.Deferred.t

    val broadcast : t -> Message.msg -> unit

    val on_first_connect : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val received_message_reader :
         t
      -> ( Message.msg Network_peer.Envelope.Incoming.t
         * Mina_net2.Validation_callback.t )
         Pipe_lib.Strict_pipe.Reader.t

    val ban_notification_reader :
      t -> Intf.ban_notification Pipe_lib.Linear_pipe.Reader.t

    type 't creator = Rpc_intf.rpc_handler list -> 't Async_kernel.Deferred.t

    type creatable = Creatable : 't implementation * 't creator -> creatable

    val create : creatable -> t creator
  end

  module Libp2p : sig
    type t

    val restart_helper : t -> unit

    val peers : t -> Network_peer.Peer.t list Async.Deferred.t

    val bandwidth_info :
         t
      -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
         Async.Deferred.Or_error.t

    val set_node_status : t -> string -> unit Async.Deferred.Or_error.t

    val get_peer_node_status :
      t -> Network_peer.Peer.t -> string Async.Deferred.Or_error.t

    val initial_peers : t -> Mina_net2.Multiaddr.t list

    val add_peer :
      t -> Network_peer.Peer.t -> is_seed:bool -> unit Async.Deferred.Or_error.t

    val connection_gating : t -> Mina_net2.connection_gating Async.Deferred.t

    val set_connection_gating :
         t
      -> Mina_net2.connection_gating
      -> Mina_net2.connection_gating Async.Deferred.t

    val random_peers : t -> int -> Network_peer.Peer.t list Async.Deferred.t

    val random_peers_except :
         t
      -> int
      -> except:Network_peer.Peer.Hash_set.t
      -> Network_peer.Peer.t list Async.Deferred.t

    val query_peer' :
         ?how:Async.Monad_sequence.how
      -> ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q list
      -> 'r list Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_peer :
         ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_random_peers :
         t
      -> int
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t Core_kernel.List.t
         Async.Deferred.t

    val broadcast : t -> Message.msg -> unit

    val on_first_connect : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val received_message_reader :
         t
      -> ( Message.msg Network_peer.Envelope.Incoming.t
         * Mina_net2.Validation_callback.t )
         Pipe_lib.Strict_pipe.Reader.t

    val ban_notification_reader :
      t -> Intf.ban_notification Pipe_lib.Linear_pipe.Reader.t

    val create :
         Libp2p.Config.t
      -> pids:Child_processes.Termination.t
      -> Rpc_intf.rpc_handler list
      -> t Async.Deferred.t
  end

  module Fake : sig
    type t

    val restart_helper : t -> unit

    val peers : t -> Network_peer.Peer.t list Async.Deferred.t

    val bandwidth_info :
         t
      -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
         Async.Deferred.Or_error.t

    val set_node_status : t -> string -> unit Async.Deferred.Or_error.t

    val get_peer_node_status :
      t -> Network_peer.Peer.t -> string Async.Deferred.Or_error.t

    val initial_peers : t -> Mina_net2.Multiaddr.t list

    val add_peer :
      t -> Network_peer.Peer.t -> is_seed:bool -> unit Async.Deferred.Or_error.t

    val connection_gating : t -> Mina_net2.connection_gating Async.Deferred.t

    val set_connection_gating :
         t
      -> Mina_net2.connection_gating
      -> Mina_net2.connection_gating Async.Deferred.t

    val random_peers : t -> int -> Network_peer.Peer.t list Async.Deferred.t

    val random_peers_except :
         t
      -> int
      -> except:Network_peer.Peer.Hash_set.t
      -> Network_peer.Peer.t list Async.Deferred.t

    val query_peer' :
         ?how:Async.Monad_sequence.how
      -> ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q list
      -> 'r list Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_peer :
         ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_random_peers :
         t
      -> int
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t Core_kernel.List.t
         Async.Deferred.t

    val broadcast : t -> Message.msg -> unit

    val on_first_connect : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val received_message_reader :
         t
      -> ( Message.msg Network_peer.Envelope.Incoming.t
         * Mina_net2.Validation_callback.t )
         Pipe_lib.Strict_pipe.Reader.t

    val ban_notification_reader :
      t -> Intf.ban_notification Pipe_lib.Linear_pipe.Reader.t

    type network

    val create_network : Network_peer.Peer.t list -> network

    val create_instance :
         network
      -> Network_peer.Peer.t
      -> Rpc_intf.rpc_handler list
      -> t Async_kernel.Deferred.t
  end
end

module Make : functor (Rpc_intf : Mina_base.Rpc_intf.Rpc_interface_intf) -> sig
  type ban_creator = Gossip_net__Intf.ban_creator =
    { banned_peer : Network_peer.Peer.t; banned_until : Core_kernel.Time.t }

  val banned_until : ban_creator -> Core_kernel.Time.t

  val banned_peer : ban_creator -> Network_peer.Peer.t

  module Fields_of_ban_creator : sig
    val names : string list

    val banned_until :
      ( [< `Read | `Set_and_create ]
      , ban_creator
      , Core_kernel.Time.t )
      Fieldslib.Field.t_with_perm

    val banned_peer :
      ( [< `Read | `Set_and_create ]
      , ban_creator
      , Network_peer.Peer.t )
      Fieldslib.Field.t_with_perm

    val make_creator :
         banned_peer:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Network_peer.Peer.t )
               Fieldslib.Field.t_with_perm
            -> 'a
            -> ('b -> Network_peer.Peer.t) * 'c)
      -> banned_until:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Core_kernel.Time.t )
               Fieldslib.Field.t_with_perm
            -> 'c
            -> ('b -> Core_kernel.Time.t) * 'd)
      -> 'a
      -> ('b -> ban_creator) * 'd

    val create :
         banned_peer:Network_peer.Peer.t
      -> banned_until:Core_kernel.Time.t
      -> ban_creator

    val map :
         banned_peer:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Network_peer.Peer.t )
               Fieldslib.Field.t_with_perm
            -> Network_peer.Peer.t)
      -> banned_until:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Core_kernel.Time.t )
               Fieldslib.Field.t_with_perm
            -> Core_kernel.Time.t)
      -> ban_creator

    val iter :
         banned_peer:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Network_peer.Peer.t )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> banned_until:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Core_kernel.Time.t )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> unit

    val fold :
         init:'a
      -> banned_peer:
           (   'a
            -> ( [< `Read | `Set_and_create ]
               , ban_creator
               , Network_peer.Peer.t )
               Fieldslib.Field.t_with_perm
            -> 'b)
      -> banned_until:
           (   'b
            -> ( [< `Read | `Set_and_create ]
               , ban_creator
               , Core_kernel.Time.t )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> 'c

    val map_poly :
         ([< `Read | `Set_and_create ], ban_creator, 'a) Fieldslib.Field.user
      -> 'a list

    val for_all :
         banned_peer:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Network_peer.Peer.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> banned_until:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Core_kernel.Time.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val exists :
         banned_peer:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Network_peer.Peer.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> banned_until:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Core_kernel.Time.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val to_list :
         banned_peer:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Network_peer.Peer.t )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> banned_until:
           (   ( [< `Read | `Set_and_create ]
               , ban_creator
               , Core_kernel.Time.t )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> 'a list

    module Direct : sig
      val iter :
           ban_creator
        -> banned_peer:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Network_peer.Peer.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Network_peer.Peer.t
              -> unit)
        -> banned_until:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Core_kernel.Time.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Core_kernel.Time.t
              -> 'a)
        -> 'a

      val fold :
           ban_creator
        -> init:'a
        -> banned_peer:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Network_peer.Peer.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Network_peer.Peer.t
              -> 'b)
        -> banned_until:
             (   'b
              -> ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Core_kernel.Time.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Core_kernel.Time.t
              -> 'c)
        -> 'c

      val for_all :
           ban_creator
        -> banned_peer:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Network_peer.Peer.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Network_peer.Peer.t
              -> bool)
        -> banned_until:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Core_kernel.Time.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Core_kernel.Time.t
              -> bool)
        -> bool

      val exists :
           ban_creator
        -> banned_peer:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Network_peer.Peer.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Network_peer.Peer.t
              -> bool)
        -> banned_until:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Core_kernel.Time.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Core_kernel.Time.t
              -> bool)
        -> bool

      val to_list :
           ban_creator
        -> banned_peer:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Network_peer.Peer.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Network_peer.Peer.t
              -> 'a)
        -> banned_until:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Core_kernel.Time.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Core_kernel.Time.t
              -> 'a)
        -> 'a list

      val map :
           ban_creator
        -> banned_peer:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Network_peer.Peer.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Network_peer.Peer.t
              -> Network_peer.Peer.t)
        -> banned_until:
             (   ( [< `Read | `Set_and_create ]
                 , ban_creator
                 , Core_kernel.Time.t )
                 Fieldslib.Field.t_with_perm
              -> ban_creator
              -> Core_kernel.Time.t
              -> Core_kernel.Time.t)
        -> ban_creator

      val set_all_mutable_fields : 'a -> unit
    end
  end

  type ban_notification = Gossip_net__Intf.ban_notification =
    { banned_peer : Network_peer.Peer.t; banned_until : Core_kernel.Time.t }

  module type Gossip_net_intf = sig
    type t

    module Rpc_intf : Mina_base.Rpc_intf.Rpc_interface_intf

    val restart_helper : t -> unit

    val peers : t -> Network_peer.Peer.t list Async.Deferred.t

    val bandwidth_info :
         t
      -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
         Async.Deferred.Or_error.t

    val set_node_status : t -> string -> unit Async.Deferred.Or_error.t

    val get_peer_node_status :
      t -> Network_peer.Peer.t -> string Async.Deferred.Or_error.t

    val initial_peers : t -> Mina_net2.Multiaddr.t list

    val add_peer :
      t -> Network_peer.Peer.t -> is_seed:bool -> unit Async.Deferred.Or_error.t

    val connection_gating : t -> Mina_net2.connection_gating Async.Deferred.t

    val set_connection_gating :
         t
      -> Mina_net2.connection_gating
      -> Mina_net2.connection_gating Async.Deferred.t

    val random_peers : t -> int -> Network_peer.Peer.t list Async.Deferred.t

    val random_peers_except :
         t
      -> int
      -> except:Network_peer.Peer.Hash_set.t
      -> Network_peer.Peer.t list Async.Deferred.t

    val query_peer' :
         ?how:Async.Monad_sequence.how
      -> ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q list
      -> 'r list Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_peer :
         ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_random_peers :
         t
      -> int
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t Core_kernel.List.t
         Async.Deferred.t

    val broadcast : t -> Message.msg -> unit

    val on_first_connect : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val received_message_reader :
         t
      -> ( Message.msg Network_peer.Envelope.Incoming.t
         * Mina_net2.Validation_callback.t )
         Pipe_lib.Strict_pipe.Reader.t

    val ban_notification_reader :
      t -> ban_notification Pipe_lib.Linear_pipe.Reader.t
  end

  module Message : sig
    module Master : sig
      module T : sig
        type msg = Gossip_net__Message.Master.T.msg =
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
      | Transaction_pool_diff of
          Network_pool.Transaction_pool.Resource_pool.Diff.t

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
          | Snark_pool_diff of
              Network_pool.Snark_pool.Diff_versioned.Stable.V1.t
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
  end

  module Any : sig
    module type Implementation_intf = sig
      type t

      val restart_helper : t -> unit

      val peers : t -> Network_peer.Peer.t list Async.Deferred.t

      val bandwidth_info :
           t
        -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
           Async.Deferred.Or_error.t

      val set_node_status : t -> string -> unit Async.Deferred.Or_error.t

      val get_peer_node_status :
        t -> Network_peer.Peer.t -> string Async.Deferred.Or_error.t

      val initial_peers : t -> Mina_net2.Multiaddr.t list

      val add_peer :
           t
        -> Network_peer.Peer.t
        -> is_seed:bool
        -> unit Async.Deferred.Or_error.t

      val connection_gating : t -> Mina_net2.connection_gating Async.Deferred.t

      val set_connection_gating :
           t
        -> Mina_net2.connection_gating
        -> Mina_net2.connection_gating Async.Deferred.t

      val random_peers : t -> int -> Network_peer.Peer.t list Async.Deferred.t

      val random_peers_except :
           t
        -> int
        -> except:Network_peer.Peer.Hash_set.t
        -> Network_peer.Peer.t list Async.Deferred.t

      val query_peer' :
           ?how:Async.Monad_sequence.how
        -> ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
        -> ?timeout:Core_kernel.Time.Span.t
        -> t
        -> Network_peer.Peer.Id.t
        -> ('q, 'r) Rpc_intf.rpc
        -> 'q list
        -> 'r list Mina_base.Rpc_intf.rpc_response Async.Deferred.t

      val query_peer :
           ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
        -> ?timeout:Core_kernel.Time.Span.t
        -> t
        -> Network_peer.Peer.Id.t
        -> ('q, 'r) Rpc_intf.rpc
        -> 'q
        -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t

      val query_random_peers :
           t
        -> int
        -> ('q, 'r) Rpc_intf.rpc
        -> 'q
        -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t
           Core_kernel.List.t
           Async.Deferred.t

      val broadcast : t -> Message.msg -> unit

      val on_first_connect : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

      val on_first_high_connectivity :
        t -> f:(unit -> 'a) -> 'a Async.Deferred.t

      val received_message_reader :
           t
        -> ( Message.msg Network_peer.Envelope.Incoming.t
           * Mina_net2.Validation_callback.t )
           Pipe_lib.Strict_pipe.Reader.t

      val ban_notification_reader :
        t -> Intf.ban_notification Pipe_lib.Linear_pipe.Reader.t
    end

    type 't implementation = (module Implementation_intf with type t = 't)

    type t = Any : 't implementation * 't -> t

    val restart_helper : t -> unit

    val peers : t -> Network_peer.Peer.t list Async.Deferred.t

    val bandwidth_info :
         t
      -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
         Async.Deferred.Or_error.t

    val set_node_status : t -> string -> unit Async.Deferred.Or_error.t

    val get_peer_node_status :
      t -> Network_peer.Peer.t -> string Async.Deferred.Or_error.t

    val initial_peers : t -> Mina_net2.Multiaddr.t list

    val add_peer :
      t -> Network_peer.Peer.t -> is_seed:bool -> unit Async.Deferred.Or_error.t

    val connection_gating : t -> Mina_net2.connection_gating Async.Deferred.t

    val set_connection_gating :
         t
      -> Mina_net2.connection_gating
      -> Mina_net2.connection_gating Async.Deferred.t

    val random_peers : t -> int -> Network_peer.Peer.t list Async.Deferred.t

    val random_peers_except :
         t
      -> int
      -> except:Network_peer.Peer.Hash_set.t
      -> Network_peer.Peer.t list Async.Deferred.t

    val query_peer' :
         ?how:Async.Monad_sequence.how
      -> ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q list
      -> 'r list Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_peer :
         ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_random_peers :
         t
      -> int
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t Core_kernel.List.t
         Async.Deferred.t

    val broadcast : t -> Message.msg -> unit

    val on_first_connect : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val received_message_reader :
         t
      -> ( Message.msg Network_peer.Envelope.Incoming.t
         * Mina_net2.Validation_callback.t )
         Pipe_lib.Strict_pipe.Reader.t

    val ban_notification_reader :
      t -> Intf.ban_notification Pipe_lib.Linear_pipe.Reader.t

    type 't creator = Rpc_intf.rpc_handler list -> 't Async_kernel.Deferred.t

    type creatable = Creatable : 't implementation * 't creator -> creatable

    val create : creatable -> t creator
  end

  module Libp2p : sig
    type t

    val restart_helper : t -> unit

    val peers : t -> Network_peer.Peer.t list Async.Deferred.t

    val bandwidth_info :
         t
      -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
         Async.Deferred.Or_error.t

    val set_node_status : t -> string -> unit Async.Deferred.Or_error.t

    val get_peer_node_status :
      t -> Network_peer.Peer.t -> string Async.Deferred.Or_error.t

    val initial_peers : t -> Mina_net2.Multiaddr.t list

    val add_peer :
      t -> Network_peer.Peer.t -> is_seed:bool -> unit Async.Deferred.Or_error.t

    val connection_gating : t -> Mina_net2.connection_gating Async.Deferred.t

    val set_connection_gating :
         t
      -> Mina_net2.connection_gating
      -> Mina_net2.connection_gating Async.Deferred.t

    val random_peers : t -> int -> Network_peer.Peer.t list Async.Deferred.t

    val random_peers_except :
         t
      -> int
      -> except:Network_peer.Peer.Hash_set.t
      -> Network_peer.Peer.t list Async.Deferred.t

    val query_peer' :
         ?how:Async.Monad_sequence.how
      -> ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q list
      -> 'r list Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_peer :
         ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_random_peers :
         t
      -> int
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t Core_kernel.List.t
         Async.Deferred.t

    val broadcast : t -> Message.msg -> unit

    val on_first_connect : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val received_message_reader :
         t
      -> ( Message.msg Network_peer.Envelope.Incoming.t
         * Mina_net2.Validation_callback.t )
         Pipe_lib.Strict_pipe.Reader.t

    val ban_notification_reader :
      t -> Intf.ban_notification Pipe_lib.Linear_pipe.Reader.t

    val create :
         Libp2p.Config.t
      -> pids:Child_processes.Termination.t
      -> Rpc_intf.rpc_handler list
      -> t Async.Deferred.t
  end

  module Fake : sig
    type t

    val restart_helper : t -> unit

    val peers : t -> Network_peer.Peer.t list Async.Deferred.t

    val bandwidth_info :
         t
      -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
         Async.Deferred.Or_error.t

    val set_node_status : t -> string -> unit Async.Deferred.Or_error.t

    val get_peer_node_status :
      t -> Network_peer.Peer.t -> string Async.Deferred.Or_error.t

    val initial_peers : t -> Mina_net2.Multiaddr.t list

    val add_peer :
      t -> Network_peer.Peer.t -> is_seed:bool -> unit Async.Deferred.Or_error.t

    val connection_gating : t -> Mina_net2.connection_gating Async.Deferred.t

    val set_connection_gating :
         t
      -> Mina_net2.connection_gating
      -> Mina_net2.connection_gating Async.Deferred.t

    val random_peers : t -> int -> Network_peer.Peer.t list Async.Deferred.t

    val random_peers_except :
         t
      -> int
      -> except:Network_peer.Peer.Hash_set.t
      -> Network_peer.Peer.t list Async.Deferred.t

    val query_peer' :
         ?how:Async.Monad_sequence.how
      -> ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q list
      -> 'r list Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_peer :
         ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
      -> ?timeout:Core_kernel.Time.Span.t
      -> t
      -> Network_peer.Peer.Id.t
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t

    val query_random_peers :
         t
      -> int
      -> ('q, 'r) Rpc_intf.rpc
      -> 'q
      -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t Core_kernel.List.t
         Async.Deferred.t

    val broadcast : t -> Message.msg -> unit

    val on_first_connect : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

    val received_message_reader :
         t
      -> ( Message.msg Network_peer.Envelope.Incoming.t
         * Mina_net2.Validation_callback.t )
         Pipe_lib.Strict_pipe.Reader.t

    val ban_notification_reader :
      t -> Intf.ban_notification Pipe_lib.Linear_pipe.Reader.t

    type network

    val create_network : Network_peer.Peer.t list -> network

    val create_instance :
         network
      -> Network_peer.Peer.t
      -> Rpc_intf.rpc_handler list
      -> t Async_kernel.Deferred.t
  end
end
