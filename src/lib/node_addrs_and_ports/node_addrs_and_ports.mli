type t =
  { external_ip : Core.Unix.Inet_addr.Blocking_sexp.t
  ; bind_ip : Core.Unix.Inet_addr.Blocking_sexp.t
  ; mutable peer : Network_peer.Peer.Stable.Latest.t option
  ; libp2p_port : int
  ; client_port : int
  }

val client_port : t -> int

val libp2p_port : t -> int

val peer : t -> Network_peer.Peer.Stable.Latest.t option

val set_peer : t -> Network_peer.Peer.Stable.Latest.t option -> unit

val bind_ip : t -> Core.Unix.Inet_addr.Blocking_sexp.t

val external_ip : t -> Core.Unix.Inet_addr.Blocking_sexp.t

module Fields : sig
  val names : string list

  val client_port :
    ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm

  val libp2p_port :
    ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm

  val peer :
    ( [< `Read | `Set_and_create ]
    , t
    , Network_peer.Peer.Stable.Latest.t option )
    Fieldslib.Field.t_with_perm

  val bind_ip :
    ( [< `Read | `Set_and_create ]
    , t
    , Core.Unix.Inet_addr.Blocking_sexp.t )
    Fieldslib.Field.t_with_perm

  val external_ip :
    ( [< `Read | `Set_and_create ]
    , t
    , Core.Unix.Inet_addr.Blocking_sexp.t )
    Fieldslib.Field.t_with_perm

  val make_creator :
       external_ip:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Core.Unix.Inet_addr.Blocking_sexp.t )
             Fieldslib.Field.t_with_perm
          -> 'a
          -> ('b -> Core.Unix.Inet_addr.Blocking_sexp.t) * 'c)
    -> bind_ip:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Core.Unix.Inet_addr.Blocking_sexp.t )
             Fieldslib.Field.t_with_perm
          -> 'c
          -> ('b -> Core.Unix.Inet_addr.Blocking_sexp.t) * 'd)
    -> peer:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Network_peer.Peer.Stable.Latest.t option )
             Fieldslib.Field.t_with_perm
          -> 'd
          -> ('b -> Network_peer.Peer.Stable.Latest.t option) * 'e)
    -> libp2p_port:
         (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
          -> 'e
          -> ('b -> int) * 'f)
    -> client_port:
         (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
          -> 'f
          -> ('b -> int) * 'g)
    -> 'a
    -> ('b -> t) * 'g

  val create :
       external_ip:Core.Unix.Inet_addr.Blocking_sexp.t
    -> bind_ip:Core.Unix.Inet_addr.Blocking_sexp.t
    -> peer:Network_peer.Peer.Stable.Latest.t option
    -> libp2p_port:int
    -> client_port:int
    -> t

  val map :
       external_ip:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Core.Unix.Inet_addr.Blocking_sexp.t )
             Fieldslib.Field.t_with_perm
          -> Core.Unix.Inet_addr.Blocking_sexp.t)
    -> bind_ip:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Core.Unix.Inet_addr.Blocking_sexp.t )
             Fieldslib.Field.t_with_perm
          -> Core.Unix.Inet_addr.Blocking_sexp.t)
    -> peer:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Network_peer.Peer.Stable.Latest.t option )
             Fieldslib.Field.t_with_perm
          -> Network_peer.Peer.Stable.Latest.t option)
    -> libp2p_port:
         (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
          -> int)
    -> client_port:
         (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
          -> int)
    -> t

  val iter :
       external_ip:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Core.Unix.Inet_addr.Blocking_sexp.t )
             Fieldslib.Field.t_with_perm
          -> unit)
    -> bind_ip:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Core.Unix.Inet_addr.Blocking_sexp.t )
             Fieldslib.Field.t_with_perm
          -> unit)
    -> peer:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Network_peer.Peer.Stable.Latest.t option )
             Fieldslib.Field.t_with_perm
          -> unit)
    -> libp2p_port:
         (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
          -> unit)
    -> client_port:
         (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
          -> unit)
    -> unit

  val fold :
       init:'a
    -> external_ip:
         (   'a
          -> ( [< `Read | `Set_and_create ]
             , t
             , Core.Unix.Inet_addr.Blocking_sexp.t )
             Fieldslib.Field.t_with_perm
          -> 'b)
    -> bind_ip:
         (   'b
          -> ( [< `Read | `Set_and_create ]
             , t
             , Core.Unix.Inet_addr.Blocking_sexp.t )
             Fieldslib.Field.t_with_perm
          -> 'c)
    -> peer:
         (   'c
          -> ( [< `Read | `Set_and_create ]
             , t
             , Network_peer.Peer.Stable.Latest.t option )
             Fieldslib.Field.t_with_perm
          -> 'd)
    -> libp2p_port:
         (   'd
          -> ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
          -> 'e)
    -> client_port:
         (   'e
          -> ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
          -> 'f)
    -> 'f

  val map_poly :
    ([< `Read | `Set_and_create ], t, 'a) Fieldslib.Field.user -> 'a list

  val for_all :
       external_ip:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Core.Unix.Inet_addr.Blocking_sexp.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> bind_ip:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Core.Unix.Inet_addr.Blocking_sexp.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> peer:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Network_peer.Peer.Stable.Latest.t option )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> libp2p_port:
         (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
          -> bool)
    -> client_port:
         (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
          -> bool)
    -> bool

  val exists :
       external_ip:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Core.Unix.Inet_addr.Blocking_sexp.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> bind_ip:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Core.Unix.Inet_addr.Blocking_sexp.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> peer:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Network_peer.Peer.Stable.Latest.t option )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> libp2p_port:
         (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
          -> bool)
    -> client_port:
         (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
          -> bool)
    -> bool

  val to_list :
       external_ip:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Core.Unix.Inet_addr.Blocking_sexp.t )
             Fieldslib.Field.t_with_perm
          -> 'a)
    -> bind_ip:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Core.Unix.Inet_addr.Blocking_sexp.t )
             Fieldslib.Field.t_with_perm
          -> 'a)
    -> peer:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Network_peer.Peer.Stable.Latest.t option )
             Fieldslib.Field.t_with_perm
          -> 'a)
    -> libp2p_port:
         (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
          -> 'a)
    -> client_port:
         (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
          -> 'a)
    -> 'a list

  module Direct : sig
    val iter :
         t
      -> external_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Core.Unix.Inet_addr.Blocking_sexp.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Core.Unix.Inet_addr.Blocking_sexp.t
            -> unit)
      -> bind_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Core.Unix.Inet_addr.Blocking_sexp.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Core.Unix.Inet_addr.Blocking_sexp.t
            -> unit)
      -> peer:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Stable.Latest.t option )
               Fieldslib.Field.t_with_perm
            -> t
            -> Network_peer.Peer.Stable.Latest.t option
            -> unit)
      -> libp2p_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> t
            -> int
            -> unit)
      -> client_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> t
            -> int
            -> 'a)
      -> 'a

    val fold :
         t
      -> init:'a
      -> external_ip:
           (   'a
            -> ( [< `Read | `Set_and_create ]
               , t
               , Core.Unix.Inet_addr.Blocking_sexp.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Core.Unix.Inet_addr.Blocking_sexp.t
            -> 'b)
      -> bind_ip:
           (   'b
            -> ( [< `Read | `Set_and_create ]
               , t
               , Core.Unix.Inet_addr.Blocking_sexp.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Core.Unix.Inet_addr.Blocking_sexp.t
            -> 'c)
      -> peer:
           (   'c
            -> ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Stable.Latest.t option )
               Fieldslib.Field.t_with_perm
            -> t
            -> Network_peer.Peer.Stable.Latest.t option
            -> 'd)
      -> libp2p_port:
           (   'd
            -> ( [< `Read | `Set_and_create ]
               , t
               , int )
               Fieldslib.Field.t_with_perm
            -> t
            -> int
            -> 'e)
      -> client_port:
           (   'e
            -> ( [< `Read | `Set_and_create ]
               , t
               , int )
               Fieldslib.Field.t_with_perm
            -> t
            -> int
            -> 'f)
      -> 'f

    val for_all :
         t
      -> external_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Core.Unix.Inet_addr.Blocking_sexp.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Core.Unix.Inet_addr.Blocking_sexp.t
            -> bool)
      -> bind_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Core.Unix.Inet_addr.Blocking_sexp.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Core.Unix.Inet_addr.Blocking_sexp.t
            -> bool)
      -> peer:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Stable.Latest.t option )
               Fieldslib.Field.t_with_perm
            -> t
            -> Network_peer.Peer.Stable.Latest.t option
            -> bool)
      -> libp2p_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> t
            -> int
            -> bool)
      -> client_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> t
            -> int
            -> bool)
      -> bool

    val exists :
         t
      -> external_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Core.Unix.Inet_addr.Blocking_sexp.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Core.Unix.Inet_addr.Blocking_sexp.t
            -> bool)
      -> bind_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Core.Unix.Inet_addr.Blocking_sexp.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Core.Unix.Inet_addr.Blocking_sexp.t
            -> bool)
      -> peer:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Stable.Latest.t option )
               Fieldslib.Field.t_with_perm
            -> t
            -> Network_peer.Peer.Stable.Latest.t option
            -> bool)
      -> libp2p_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> t
            -> int
            -> bool)
      -> client_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> t
            -> int
            -> bool)
      -> bool

    val to_list :
         t
      -> external_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Core.Unix.Inet_addr.Blocking_sexp.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Core.Unix.Inet_addr.Blocking_sexp.t
            -> 'a)
      -> bind_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Core.Unix.Inet_addr.Blocking_sexp.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Core.Unix.Inet_addr.Blocking_sexp.t
            -> 'a)
      -> peer:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Stable.Latest.t option )
               Fieldslib.Field.t_with_perm
            -> t
            -> Network_peer.Peer.Stable.Latest.t option
            -> 'a)
      -> libp2p_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> t
            -> int
            -> 'a)
      -> client_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> t
            -> int
            -> 'a)
      -> 'a list

    val map :
         t
      -> external_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Core.Unix.Inet_addr.Blocking_sexp.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Core.Unix.Inet_addr.Blocking_sexp.t
            -> Core.Unix.Inet_addr.Blocking_sexp.t)
      -> bind_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Core.Unix.Inet_addr.Blocking_sexp.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Core.Unix.Inet_addr.Blocking_sexp.t
            -> Core.Unix.Inet_addr.Blocking_sexp.t)
      -> peer:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Stable.Latest.t option )
               Fieldslib.Field.t_with_perm
            -> t
            -> Network_peer.Peer.Stable.Latest.t option
            -> Network_peer.Peer.Stable.Latest.t option)
      -> libp2p_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> t
            -> int
            -> int)
      -> client_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> t
            -> int
            -> int)
      -> t

    val set_all_mutable_fields :
      t -> peer:Network_peer.Peer.Stable.Latest.t option -> unit
  end
end

val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

module Display : sig
  module Stable : sig
    module V1 : sig
      type t =
        { external_ip : string
        ; bind_ip : string
        ; peer : Network_peer.Peer.Display.Stable.V1.t option
        ; libp2p_port : int
        ; client_port : int
        }

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val client_port : t -> int

      val libp2p_port : t -> int

      val peer : t -> Network_peer.Peer.Display.Stable.V1.t option

      val bind_ip : t -> string

      val external_ip : t -> string

      module Fields : sig
        val names : string list

        val client_port :
          ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm

        val libp2p_port :
          ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm

        val peer :
          ( [< `Read | `Set_and_create ]
          , t
          , Network_peer.Peer.Display.Stable.V1.t option )
          Fieldslib.Field.t_with_perm

        val bind_ip :
          ([< `Read | `Set_and_create ], t, string) Fieldslib.Field.t_with_perm

        val external_ip :
          ([< `Read | `Set_and_create ], t, string) Fieldslib.Field.t_with_perm

        val make_creator :
             external_ip:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , string )
                   Fieldslib.Field.t_with_perm
                -> 'a
                -> ('b -> string) * 'c)
          -> bind_ip:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , string )
                   Fieldslib.Field.t_with_perm
                -> 'c
                -> ('b -> string) * 'd)
          -> peer:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Network_peer.Peer.Display.Stable.V1.t option )
                   Fieldslib.Field.t_with_perm
                -> 'd
                -> ('b -> Network_peer.Peer.Display.Stable.V1.t option) * 'e)
          -> libp2p_port:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> 'e
                -> ('b -> int) * 'f)
          -> client_port:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> 'f
                -> ('b -> int) * 'g)
          -> 'a
          -> ('b -> t) * 'g

        val create :
             external_ip:string
          -> bind_ip:string
          -> peer:Network_peer.Peer.Display.Stable.V1.t option
          -> libp2p_port:int
          -> client_port:int
          -> t

        val map :
             external_ip:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , string )
                   Fieldslib.Field.t_with_perm
                -> string)
          -> bind_ip:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , string )
                   Fieldslib.Field.t_with_perm
                -> string)
          -> peer:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Network_peer.Peer.Display.Stable.V1.t option )
                   Fieldslib.Field.t_with_perm
                -> Network_peer.Peer.Display.Stable.V1.t option)
          -> libp2p_port:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> int)
          -> client_port:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> int)
          -> t

        val iter :
             external_ip:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , string )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> bind_ip:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , string )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> peer:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Network_peer.Peer.Display.Stable.V1.t option )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> libp2p_port:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> client_port:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> unit

        val fold :
             init:'a
          -> external_ip:
               (   'a
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , string )
                   Fieldslib.Field.t_with_perm
                -> 'b)
          -> bind_ip:
               (   'b
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , string )
                   Fieldslib.Field.t_with_perm
                -> 'c)
          -> peer:
               (   'c
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , Network_peer.Peer.Display.Stable.V1.t option )
                   Fieldslib.Field.t_with_perm
                -> 'd)
          -> libp2p_port:
               (   'd
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> 'e)
          -> client_port:
               (   'e
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> 'f)
          -> 'f

        val map_poly :
          ([< `Read | `Set_and_create ], t, 'a) Fieldslib.Field.user -> 'a list

        val for_all :
             external_ip:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , string )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bind_ip:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , string )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> peer:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Network_peer.Peer.Display.Stable.V1.t option )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> libp2p_port:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> client_port:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bool

        val exists :
             external_ip:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , string )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bind_ip:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , string )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> peer:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Network_peer.Peer.Display.Stable.V1.t option )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> libp2p_port:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> client_port:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bool

        val to_list :
             external_ip:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , string )
                   Fieldslib.Field.t_with_perm
                -> 'a)
          -> bind_ip:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , string )
                   Fieldslib.Field.t_with_perm
                -> 'a)
          -> peer:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Network_peer.Peer.Display.Stable.V1.t option )
                   Fieldslib.Field.t_with_perm
                -> 'a)
          -> libp2p_port:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> 'a)
          -> client_port:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , int )
                   Fieldslib.Field.t_with_perm
                -> 'a)
          -> 'a list

        module Direct : sig
          val iter :
               t
            -> external_ip:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , string )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> string
                  -> unit)
            -> bind_ip:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , string )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> string
                  -> unit)
            -> peer:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , Network_peer.Peer.Display.Stable.V1.t option )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> Network_peer.Peer.Display.Stable.V1.t option
                  -> unit)
            -> libp2p_port:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , int )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> int
                  -> unit)
            -> client_port:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , int )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> int
                  -> 'a)
            -> 'a

          val fold :
               t
            -> init:'a
            -> external_ip:
                 (   'a
                  -> ( [< `Read | `Set_and_create ]
                     , t
                     , string )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> string
                  -> 'b)
            -> bind_ip:
                 (   'b
                  -> ( [< `Read | `Set_and_create ]
                     , t
                     , string )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> string
                  -> 'c)
            -> peer:
                 (   'c
                  -> ( [< `Read | `Set_and_create ]
                     , t
                     , Network_peer.Peer.Display.Stable.V1.t option )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> Network_peer.Peer.Display.Stable.V1.t option
                  -> 'd)
            -> libp2p_port:
                 (   'd
                  -> ( [< `Read | `Set_and_create ]
                     , t
                     , int )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> int
                  -> 'e)
            -> client_port:
                 (   'e
                  -> ( [< `Read | `Set_and_create ]
                     , t
                     , int )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> int
                  -> 'f)
            -> 'f

          val for_all :
               t
            -> external_ip:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , string )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> string
                  -> bool)
            -> bind_ip:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , string )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> string
                  -> bool)
            -> peer:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , Network_peer.Peer.Display.Stable.V1.t option )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> Network_peer.Peer.Display.Stable.V1.t option
                  -> bool)
            -> libp2p_port:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , int )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> int
                  -> bool)
            -> client_port:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , int )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> int
                  -> bool)
            -> bool

          val exists :
               t
            -> external_ip:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , string )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> string
                  -> bool)
            -> bind_ip:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , string )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> string
                  -> bool)
            -> peer:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , Network_peer.Peer.Display.Stable.V1.t option )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> Network_peer.Peer.Display.Stable.V1.t option
                  -> bool)
            -> libp2p_port:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , int )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> int
                  -> bool)
            -> client_port:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , int )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> int
                  -> bool)
            -> bool

          val to_list :
               t
            -> external_ip:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , string )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> string
                  -> 'a)
            -> bind_ip:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , string )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> string
                  -> 'a)
            -> peer:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , Network_peer.Peer.Display.Stable.V1.t option )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> Network_peer.Peer.Display.Stable.V1.t option
                  -> 'a)
            -> libp2p_port:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , int )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> int
                  -> 'a)
            -> client_port:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , int )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> int
                  -> 'a)
            -> 'a list

          val map :
               t
            -> external_ip:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , string )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> string
                  -> string)
            -> bind_ip:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , string )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> string
                  -> string)
            -> peer:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , Network_peer.Peer.Display.Stable.V1.t option )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> Network_peer.Peer.Display.Stable.V1.t option
                  -> Network_peer.Peer.Display.Stable.V1.t option)
            -> libp2p_port:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , int )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> int
                  -> int)
            -> client_port:
                 (   ( [< `Read | `Set_and_create ]
                     , t
                     , int )
                     Fieldslib.Field.t_with_perm
                  -> t
                  -> int
                  -> int)
            -> t

          val set_all_mutable_fields : 'a -> unit
        end
      end

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val to_latest : 'a -> 'a

      module With_version : sig
        type typ = t

        val bin_shape_typ : Core.Bin_prot.Shape.t

        val bin_size_typ : typ Core.Bin_prot.Size.sizer

        val bin_write_typ : typ Core.Bin_prot.Write.writer

        val bin_writer_typ : typ Core.Bin_prot.Type_class.writer

        val __bin_read_typ__ : (int -> typ) Core.Bin_prot.Read.reader

        val bin_read_typ : typ Core.Bin_prot.Read.reader

        val bin_reader_typ : typ Core.Bin_prot.Type_class.reader

        val bin_typ : typ Core.Bin_prot.Type_class.t

        type t = { version : int; t : typ }

        val bin_shape_t : Core.Bin_prot.Shape.t

        val bin_size_t : t Core.Bin_prot.Size.sizer

        val bin_write_t : t Core.Bin_prot.Write.writer

        val bin_writer_t : t Core.Bin_prot.Type_class.writer

        val __bin_read_t__ : (int -> t) Core.Bin_prot.Read.reader

        val bin_read_t : t Core.Bin_prot.Read.reader

        val bin_reader_t : t Core.Bin_prot.Type_class.reader

        val bin_t : t Core.Bin_prot.Type_class.t

        val create : typ -> t
      end

      val bin_read_t :
        Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t

      val __bin_read_t__ :
        Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> int -> t

      val bin_size_t : t -> int

      val bin_write_t :
           Bin_prot.Common.buf
        -> pos:Bin_prot.Common.pos
        -> t
        -> Bin_prot.Common.pos

      val bin_shape_t : Core.Bin_prot.Shape.t

      val bin_reader_t : t Core.Bin_prot.Type_class.reader

      val bin_writer_t : t Core.Bin_prot.Type_class.writer

      val bin_t : t Core.Bin_prot.Type_class.t

      val __ :
        (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t)
        * (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> int -> t)
        * (t -> int)
        * (   Bin_prot.Common.buf
           -> pos:Bin_prot.Common.pos
           -> t
           -> Bin_prot.Common.pos)
        * Core.Bin_prot.Shape.t
        * t Core.Bin_prot.Type_class.reader
        * t Core.Bin_prot.Type_class.writer
        * t Core.Bin_prot.Type_class.t
    end

    module Latest = V1

    val versions :
      (int * (Core_kernel.Bigstring.t -> pos_ref:int Core.ref -> V1.t)) array

    val bin_read_to_latest_opt :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> V1.t option

    val __ :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> V1.t option
  end

  type t = Stable.V1.t =
    { external_ip : string
    ; bind_ip : string
    ; peer : Network_peer.Peer.Display.t option
    ; libp2p_port : int
    ; client_port : int
    }

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val client_port : t -> int

  val libp2p_port : t -> int

  val peer : t -> Network_peer.Peer.Display.t option

  val bind_ip : t -> string

  val external_ip : t -> string

  module Fields : sig
    val names : string list

    val client_port :
      ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm

    val libp2p_port :
      ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm

    val peer :
      ( [< `Read | `Set_and_create ]
      , t
      , Network_peer.Peer.Display.t option )
      Fieldslib.Field.t_with_perm

    val bind_ip :
      ([< `Read | `Set_and_create ], t, string) Fieldslib.Field.t_with_perm

    val external_ip :
      ([< `Read | `Set_and_create ], t, string) Fieldslib.Field.t_with_perm

    val make_creator :
         external_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , string )
               Fieldslib.Field.t_with_perm
            -> 'a
            -> ('b -> string) * 'c)
      -> bind_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , string )
               Fieldslib.Field.t_with_perm
            -> 'c
            -> ('b -> string) * 'd)
      -> peer:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Display.t option )
               Fieldslib.Field.t_with_perm
            -> 'd
            -> ('b -> Network_peer.Peer.Display.t option) * 'e)
      -> libp2p_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> 'e
            -> ('b -> int) * 'f)
      -> client_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> 'f
            -> ('b -> int) * 'g)
      -> 'a
      -> ('b -> t) * 'g

    val create :
         external_ip:string
      -> bind_ip:string
      -> peer:Network_peer.Peer.Display.t option
      -> libp2p_port:int
      -> client_port:int
      -> t

    val map :
         external_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , string )
               Fieldslib.Field.t_with_perm
            -> string)
      -> bind_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , string )
               Fieldslib.Field.t_with_perm
            -> string)
      -> peer:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Display.t option )
               Fieldslib.Field.t_with_perm
            -> Network_peer.Peer.Display.t option)
      -> libp2p_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> int)
      -> client_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> int)
      -> t

    val iter :
         external_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , string )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> bind_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , string )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> peer:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Display.t option )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> libp2p_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> unit)
      -> client_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> unit)
      -> unit

    val fold :
         init:'a
      -> external_ip:
           (   'a
            -> ( [< `Read | `Set_and_create ]
               , t
               , string )
               Fieldslib.Field.t_with_perm
            -> 'b)
      -> bind_ip:
           (   'b
            -> ( [< `Read | `Set_and_create ]
               , t
               , string )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> peer:
           (   'c
            -> ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Display.t option )
               Fieldslib.Field.t_with_perm
            -> 'd)
      -> libp2p_port:
           (   'd
            -> ( [< `Read | `Set_and_create ]
               , t
               , int )
               Fieldslib.Field.t_with_perm
            -> 'e)
      -> client_port:
           (   'e
            -> ( [< `Read | `Set_and_create ]
               , t
               , int )
               Fieldslib.Field.t_with_perm
            -> 'f)
      -> 'f

    val map_poly :
      ([< `Read | `Set_and_create ], t, 'a) Fieldslib.Field.user -> 'a list

    val for_all :
         external_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , string )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bind_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , string )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> peer:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Display.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> libp2p_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> bool)
      -> client_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val exists :
         external_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , string )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bind_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , string )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> peer:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Display.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> libp2p_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> bool)
      -> client_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val to_list :
         external_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , string )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> bind_ip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , string )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> peer:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Display.t option )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> libp2p_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> 'a)
      -> client_port:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> 'a)
      -> 'a list

    module Direct : sig
      val iter :
           t
        -> external_ip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , string )
                 Fieldslib.Field.t_with_perm
              -> t
              -> string
              -> unit)
        -> bind_ip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , string )
                 Fieldslib.Field.t_with_perm
              -> t
              -> string
              -> unit)
        -> peer:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Network_peer.Peer.Display.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Network_peer.Peer.Display.t option
              -> unit)
        -> libp2p_port:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> unit)
        -> client_port:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> 'a)
        -> 'a

      val fold :
           t
        -> init:'a
        -> external_ip:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , string )
                 Fieldslib.Field.t_with_perm
              -> t
              -> string
              -> 'b)
        -> bind_ip:
             (   'b
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , string )
                 Fieldslib.Field.t_with_perm
              -> t
              -> string
              -> 'c)
        -> peer:
             (   'c
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Network_peer.Peer.Display.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Network_peer.Peer.Display.t option
              -> 'd)
        -> libp2p_port:
             (   'd
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> 'e)
        -> client_port:
             (   'e
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> 'f)
        -> 'f

      val for_all :
           t
        -> external_ip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , string )
                 Fieldslib.Field.t_with_perm
              -> t
              -> string
              -> bool)
        -> bind_ip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , string )
                 Fieldslib.Field.t_with_perm
              -> t
              -> string
              -> bool)
        -> peer:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Network_peer.Peer.Display.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Network_peer.Peer.Display.t option
              -> bool)
        -> libp2p_port:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> bool)
        -> client_port:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> bool)
        -> bool

      val exists :
           t
        -> external_ip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , string )
                 Fieldslib.Field.t_with_perm
              -> t
              -> string
              -> bool)
        -> bind_ip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , string )
                 Fieldslib.Field.t_with_perm
              -> t
              -> string
              -> bool)
        -> peer:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Network_peer.Peer.Display.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Network_peer.Peer.Display.t option
              -> bool)
        -> libp2p_port:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> bool)
        -> client_port:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> bool)
        -> bool

      val to_list :
           t
        -> external_ip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , string )
                 Fieldslib.Field.t_with_perm
              -> t
              -> string
              -> 'a)
        -> bind_ip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , string )
                 Fieldslib.Field.t_with_perm
              -> t
              -> string
              -> 'a)
        -> peer:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Network_peer.Peer.Display.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Network_peer.Peer.Display.t option
              -> 'a)
        -> libp2p_port:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> 'a)
        -> client_port:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> 'a)
        -> 'a list

      val map :
           t
        -> external_ip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , string )
                 Fieldslib.Field.t_with_perm
              -> t
              -> string
              -> string)
        -> bind_ip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , string )
                 Fieldslib.Field.t_with_perm
              -> t
              -> string
              -> string)
        -> peer:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Network_peer.Peer.Display.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Network_peer.Peer.Display.t option
              -> Network_peer.Peer.Display.t option)
        -> libp2p_port:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> int)
        -> client_port:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> int)
        -> t

      val set_all_mutable_fields : 'a -> unit
    end
  end

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
end

val to_display : t -> Display.t

val of_display : Display.t -> t

val to_multiaddr : t -> string option

val to_multiaddr_exn : t -> string

val to_yojson : t -> Yojson.Safe.t

val to_peer_exn : t -> Network_peer.Peer.t
