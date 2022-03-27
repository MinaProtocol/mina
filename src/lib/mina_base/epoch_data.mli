module Poly : sig
  module Stable : sig
    module V1 : sig
      type ( 'epoch_ledger
           , 'epoch_seed
           , 'start_checkpoint
           , 'lock_checkpoint
           , 'length )
           t =
        { ledger : 'epoch_ledger
        ; seed : 'epoch_seed
        ; start_checkpoint : 'start_checkpoint
        ; lock_checkpoint : 'lock_checkpoint
        ; epoch_length : 'length
        }

      val to_yojson :
           ('epoch_ledger -> Yojson.Safe.t)
        -> ('epoch_seed -> Yojson.Safe.t)
        -> ('start_checkpoint -> Yojson.Safe.t)
        -> ('lock_checkpoint -> Yojson.Safe.t)
        -> ('length -> Yojson.Safe.t)
        -> ( 'epoch_ledger
           , 'epoch_seed
           , 'start_checkpoint
           , 'lock_checkpoint
           , 'length )
           t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'epoch_ledger Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'epoch_seed Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'start_checkpoint Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'lock_checkpoint Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'length Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ( 'epoch_ledger
           , 'epoch_seed
           , 'start_checkpoint
           , 'lock_checkpoint
           , 'length )
           t
           Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val to_hlist :
           ( 'epoch_ledger
           , 'epoch_seed
           , 'start_checkpoint
           , 'lock_checkpoint
           , 'length )
           t
        -> ( unit
           ,    'epoch_ledger
             -> 'epoch_seed
             -> 'start_checkpoint
             -> 'lock_checkpoint
             -> 'length
             -> unit )
           H_list.t

      val of_hlist :
           ( unit
           ,    'epoch_ledger
             -> 'epoch_seed
             -> 'start_checkpoint
             -> 'lock_checkpoint
             -> 'length
             -> unit )
           H_list.t
        -> ( 'epoch_ledger
           , 'epoch_seed
           , 'start_checkpoint
           , 'lock_checkpoint
           , 'length )
           t

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'epoch_ledger)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'epoch_seed)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'start_checkpoint)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'lock_checkpoint)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'length)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ( 'epoch_ledger
           , 'epoch_seed
           , 'start_checkpoint
           , 'lock_checkpoint
           , 'length )
           t

      val sexp_of_t :
           ('epoch_ledger -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('epoch_seed -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('start_checkpoint -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('lock_checkpoint -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('length -> Ppx_sexp_conv_lib.Sexp.t)
        -> ( 'epoch_ledger
           , 'epoch_seed
           , 'start_checkpoint
           , 'lock_checkpoint
           , 'length )
           t
        -> Ppx_sexp_conv_lib.Sexp.t

      val equal :
           ('epoch_ledger -> 'epoch_ledger -> bool)
        -> ('epoch_seed -> 'epoch_seed -> bool)
        -> ('start_checkpoint -> 'start_checkpoint -> bool)
        -> ('lock_checkpoint -> 'lock_checkpoint -> bool)
        -> ('length -> 'length -> bool)
        -> ( 'epoch_ledger
           , 'epoch_seed
           , 'start_checkpoint
           , 'lock_checkpoint
           , 'length )
           t
        -> ( 'epoch_ledger
           , 'epoch_seed
           , 'start_checkpoint
           , 'lock_checkpoint
           , 'length )
           t
        -> bool

      val compare :
           ('epoch_ledger -> 'epoch_ledger -> int)
        -> ('epoch_seed -> 'epoch_seed -> int)
        -> ('start_checkpoint -> 'start_checkpoint -> int)
        -> ('lock_checkpoint -> 'lock_checkpoint -> int)
        -> ('length -> 'length -> int)
        -> ( 'epoch_ledger
           , 'epoch_seed
           , 'start_checkpoint
           , 'lock_checkpoint
           , 'length )
           t
        -> ( 'epoch_ledger
           , 'epoch_seed
           , 'start_checkpoint
           , 'lock_checkpoint
           , 'length )
           t
        -> int

      val hash_fold_t :
           (   Ppx_hash_lib.Std.Hash.state
            -> 'epoch_ledger
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'epoch_seed
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'start_checkpoint
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'lock_checkpoint
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'length
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ( 'epoch_ledger
           , 'epoch_seed
           , 'start_checkpoint
           , 'lock_checkpoint
           , 'length )
           t
        -> Ppx_hash_lib.Std.Hash.state

      val epoch_length : ('a, 'b, 'c, 'd, 'e) t -> 'e

      val lock_checkpoint : ('a, 'b, 'c, 'd, 'e) t -> 'd

      val start_checkpoint : ('a, 'b, 'c, 'd, 'e) t -> 'c

      val seed : ('a, 'b, 'c, 'd, 'e) t -> 'b

      val ledger : ('a, 'b, 'c, 'd, 'e) t -> 'a

      module Fields : sig
        val names : string list

        val epoch_length :
          ( [< `Read | `Set_and_create ]
          , ('a, 'b, 'c, 'd, 'length) t
          , 'length )
          Fieldslib.Field.t_with_perm

        val lock_checkpoint :
          ( [< `Read | `Set_and_create ]
          , ('a, 'b, 'c, 'lock_checkpoint, 'd) t
          , 'lock_checkpoint )
          Fieldslib.Field.t_with_perm

        val start_checkpoint :
          ( [< `Read | `Set_and_create ]
          , ('a, 'b, 'start_checkpoint, 'c, 'd) t
          , 'start_checkpoint )
          Fieldslib.Field.t_with_perm

        val seed :
          ( [< `Read | `Set_and_create ]
          , ('a, 'epoch_seed, 'b, 'c, 'd) t
          , 'epoch_seed )
          Fieldslib.Field.t_with_perm

        val ledger :
          ( [< `Read | `Set_and_create ]
          , ('epoch_ledger, 'a, 'b, 'c, 'd) t
          , 'epoch_ledger )
          Fieldslib.Field.t_with_perm

        val make_creator :
             ledger:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b, 'c, 'd, 'e) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> 'f
                -> ('g -> 'h) * 'i)
          -> seed:
               (   ( [< `Read | `Set_and_create ]
                   , ('j, 'k, 'l, 'm, 'n) t
                   , 'k )
                   Fieldslib.Field.t_with_perm
                -> 'i
                -> ('g -> 'o) * 'p)
          -> start_checkpoint:
               (   ( [< `Read | `Set_and_create ]
                   , ('q, 'r, 's, 't, 'u) t
                   , 's )
                   Fieldslib.Field.t_with_perm
                -> 'p
                -> ('g -> 'v) * 'w)
          -> lock_checkpoint:
               (   ( [< `Read | `Set_and_create ]
                   , ('x, 'y, 'z, 'a1, 'b1) t
                   , 'a1 )
                   Fieldslib.Field.t_with_perm
                -> 'w
                -> ('g -> 'c1) * 'd1)
          -> epoch_length:
               (   ( [< `Read | `Set_and_create ]
                   , ('e1, 'f1, 'g1, 'h1, 'i1) t
                   , 'i1 )
                   Fieldslib.Field.t_with_perm
                -> 'd1
                -> ('g -> 'j1) * 'k1)
          -> 'f
          -> ('g -> ('h, 'o, 'v, 'c1, 'j1) t) * 'k1

        val create :
             ledger:'a
          -> seed:'b
          -> start_checkpoint:'c
          -> lock_checkpoint:'d
          -> epoch_length:'e
          -> ('a, 'b, 'c, 'd, 'e) t

        val map :
             ledger:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b, 'c, 'd, 'e) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> 'f)
          -> seed:
               (   ( [< `Read | `Set_and_create ]
                   , ('g, 'h, 'i, 'j, 'k) t
                   , 'h )
                   Fieldslib.Field.t_with_perm
                -> 'l)
          -> start_checkpoint:
               (   ( [< `Read | `Set_and_create ]
                   , ('m, 'n, 'o, 'p, 'q) t
                   , 'o )
                   Fieldslib.Field.t_with_perm
                -> 'r)
          -> lock_checkpoint:
               (   ( [< `Read | `Set_and_create ]
                   , ('s, 't, 'u, 'v, 'w) t
                   , 'v )
                   Fieldslib.Field.t_with_perm
                -> 'x)
          -> epoch_length:
               (   ( [< `Read | `Set_and_create ]
                   , ('y, 'z, 'a1, 'b1, 'c1) t
                   , 'c1 )
                   Fieldslib.Field.t_with_perm
                -> 'd1)
          -> ('f, 'l, 'r, 'x, 'd1) t

        val iter :
             ledger:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b, 'c, 'd, 'e) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> seed:
               (   ( [< `Read | `Set_and_create ]
                   , ('f, 'g, 'h, 'i, 'j) t
                   , 'g )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> start_checkpoint:
               (   ( [< `Read | `Set_and_create ]
                   , ('k, 'l, 'm, 'n, 'o) t
                   , 'm )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> lock_checkpoint:
               (   ( [< `Read | `Set_and_create ]
                   , ('p, 'q, 'r, 's, 't) t
                   , 's )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> epoch_length:
               (   ( [< `Read | `Set_and_create ]
                   , ('u, 'v, 'w, 'x, 'y) t
                   , 'y )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> unit

        val fold :
             init:'a
          -> ledger:
               (   'a
                -> ( [< `Read | `Set_and_create ]
                   , ('b, 'c, 'd, 'e, 'f) t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> 'g)
          -> seed:
               (   'g
                -> ( [< `Read | `Set_and_create ]
                   , ('h, 'i, 'j, 'k, 'l) t
                   , 'i )
                   Fieldslib.Field.t_with_perm
                -> 'm)
          -> start_checkpoint:
               (   'm
                -> ( [< `Read | `Set_and_create ]
                   , ('n, 'o, 'p, 'q, 'r) t
                   , 'p )
                   Fieldslib.Field.t_with_perm
                -> 's)
          -> lock_checkpoint:
               (   's
                -> ( [< `Read | `Set_and_create ]
                   , ('t, 'u, 'v, 'w, 'x) t
                   , 'w )
                   Fieldslib.Field.t_with_perm
                -> 'y)
          -> epoch_length:
               (   'y
                -> ( [< `Read | `Set_and_create ]
                   , ('z, 'a1, 'b1, 'c1, 'd1) t
                   , 'd1 )
                   Fieldslib.Field.t_with_perm
                -> 'e1)
          -> 'e1

        val map_poly :
             ( [< `Read | `Set_and_create ]
             , ('a, 'b, 'c, 'd, 'e) t
             , 'f )
             Fieldslib.Field.user
          -> 'f list

        val for_all :
             ledger:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b, 'c, 'd, 'e) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> seed:
               (   ( [< `Read | `Set_and_create ]
                   , ('f, 'g, 'h, 'i, 'j) t
                   , 'g )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> start_checkpoint:
               (   ( [< `Read | `Set_and_create ]
                   , ('k, 'l, 'm, 'n, 'o) t
                   , 'm )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> lock_checkpoint:
               (   ( [< `Read | `Set_and_create ]
                   , ('p, 'q, 'r, 's, 't) t
                   , 's )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> epoch_length:
               (   ( [< `Read | `Set_and_create ]
                   , ('u, 'v, 'w, 'x, 'y) t
                   , 'y )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bool

        val exists :
             ledger:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b, 'c, 'd, 'e) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> seed:
               (   ( [< `Read | `Set_and_create ]
                   , ('f, 'g, 'h, 'i, 'j) t
                   , 'g )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> start_checkpoint:
               (   ( [< `Read | `Set_and_create ]
                   , ('k, 'l, 'm, 'n, 'o) t
                   , 'm )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> lock_checkpoint:
               (   ( [< `Read | `Set_and_create ]
                   , ('p, 'q, 'r, 's, 't) t
                   , 's )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> epoch_length:
               (   ( [< `Read | `Set_and_create ]
                   , ('u, 'v, 'w, 'x, 'y) t
                   , 'y )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bool

        val to_list :
             ledger:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b, 'c, 'd, 'e) t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> 'f)
          -> seed:
               (   ( [< `Read | `Set_and_create ]
                   , ('g, 'h, 'i, 'j, 'k) t
                   , 'h )
                   Fieldslib.Field.t_with_perm
                -> 'f)
          -> start_checkpoint:
               (   ( [< `Read | `Set_and_create ]
                   , ('l, 'm, 'n, 'o, 'p) t
                   , 'n )
                   Fieldslib.Field.t_with_perm
                -> 'f)
          -> lock_checkpoint:
               (   ( [< `Read | `Set_and_create ]
                   , ('q, 'r, 's, 't, 'u) t
                   , 't )
                   Fieldslib.Field.t_with_perm
                -> 'f)
          -> epoch_length:
               (   ( [< `Read | `Set_and_create ]
                   , ('v, 'w, 'x, 'y, 'z) t
                   , 'z )
                   Fieldslib.Field.t_with_perm
                -> 'f)
          -> 'f list

        module Direct : sig
          val iter :
               ('a, 'b, 'c, 'd, 'e) t
            -> ledger:
                 (   ( [< `Read | `Set_and_create ]
                     , ('f, 'g, 'h, 'i, 'j) t
                     , 'f )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'a
                  -> unit)
            -> seed:
                 (   ( [< `Read | `Set_and_create ]
                     , ('k, 'l, 'm, 'n, 'o) t
                     , 'l )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'b
                  -> unit)
            -> start_checkpoint:
                 (   ( [< `Read | `Set_and_create ]
                     , ('p, 'q, 'r, 's, 't) t
                     , 'r )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'c
                  -> unit)
            -> lock_checkpoint:
                 (   ( [< `Read | `Set_and_create ]
                     , ('u, 'v, 'w, 'x, 'y) t
                     , 'x )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'd
                  -> unit)
            -> epoch_length:
                 (   ( [< `Read | `Set_and_create ]
                     , ('z, 'a1, 'b1, 'c1, 'd1) t
                     , 'd1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'e
                  -> 'e1)
            -> 'e1

          val fold :
               ('a, 'b, 'c, 'd, 'e) t
            -> init:'f
            -> ledger:
                 (   'f
                  -> ( [< `Read | `Set_and_create ]
                     , ('g, 'h, 'i, 'j, 'k) t
                     , 'g )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'a
                  -> 'l)
            -> seed:
                 (   'l
                  -> ( [< `Read | `Set_and_create ]
                     , ('m, 'n, 'o, 'p, 'q) t
                     , 'n )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'b
                  -> 'r)
            -> start_checkpoint:
                 (   'r
                  -> ( [< `Read | `Set_and_create ]
                     , ('s, 't, 'u, 'v, 'w) t
                     , 'u )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'c
                  -> 'x)
            -> lock_checkpoint:
                 (   'x
                  -> ( [< `Read | `Set_and_create ]
                     , ('y, 'z, 'a1, 'b1, 'c1) t
                     , 'b1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'd
                  -> 'd1)
            -> epoch_length:
                 (   'd1
                  -> ( [< `Read | `Set_and_create ]
                     , ('e1, 'f1, 'g1, 'h1, 'i1) t
                     , 'i1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'e
                  -> 'j1)
            -> 'j1

          val for_all :
               ('a, 'b, 'c, 'd, 'e) t
            -> ledger:
                 (   ( [< `Read | `Set_and_create ]
                     , ('f, 'g, 'h, 'i, 'j) t
                     , 'f )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'a
                  -> bool)
            -> seed:
                 (   ( [< `Read | `Set_and_create ]
                     , ('k, 'l, 'm, 'n, 'o) t
                     , 'l )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'b
                  -> bool)
            -> start_checkpoint:
                 (   ( [< `Read | `Set_and_create ]
                     , ('p, 'q, 'r, 's, 't) t
                     , 'r )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'c
                  -> bool)
            -> lock_checkpoint:
                 (   ( [< `Read | `Set_and_create ]
                     , ('u, 'v, 'w, 'x, 'y) t
                     , 'x )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'd
                  -> bool)
            -> epoch_length:
                 (   ( [< `Read | `Set_and_create ]
                     , ('z, 'a1, 'b1, 'c1, 'd1) t
                     , 'd1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'e
                  -> bool)
            -> bool

          val exists :
               ('a, 'b, 'c, 'd, 'e) t
            -> ledger:
                 (   ( [< `Read | `Set_and_create ]
                     , ('f, 'g, 'h, 'i, 'j) t
                     , 'f )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'a
                  -> bool)
            -> seed:
                 (   ( [< `Read | `Set_and_create ]
                     , ('k, 'l, 'm, 'n, 'o) t
                     , 'l )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'b
                  -> bool)
            -> start_checkpoint:
                 (   ( [< `Read | `Set_and_create ]
                     , ('p, 'q, 'r, 's, 't) t
                     , 'r )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'c
                  -> bool)
            -> lock_checkpoint:
                 (   ( [< `Read | `Set_and_create ]
                     , ('u, 'v, 'w, 'x, 'y) t
                     , 'x )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'd
                  -> bool)
            -> epoch_length:
                 (   ( [< `Read | `Set_and_create ]
                     , ('z, 'a1, 'b1, 'c1, 'd1) t
                     , 'd1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'e
                  -> bool)
            -> bool

          val to_list :
               ('a, 'b, 'c, 'd, 'e) t
            -> ledger:
                 (   ( [< `Read | `Set_and_create ]
                     , ('f, 'g, 'h, 'i, 'j) t
                     , 'f )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'a
                  -> 'k)
            -> seed:
                 (   ( [< `Read | `Set_and_create ]
                     , ('l, 'm, 'n, 'o, 'p) t
                     , 'm )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'b
                  -> 'k)
            -> start_checkpoint:
                 (   ( [< `Read | `Set_and_create ]
                     , ('q, 'r, 's, 't, 'u) t
                     , 's )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'c
                  -> 'k)
            -> lock_checkpoint:
                 (   ( [< `Read | `Set_and_create ]
                     , ('v, 'w, 'x, 'y, 'z) t
                     , 'y )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'd
                  -> 'k)
            -> epoch_length:
                 (   ( [< `Read | `Set_and_create ]
                     , ('a1, 'b1, 'c1, 'd1, 'e1) t
                     , 'e1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'e
                  -> 'k)
            -> 'k list

          val map :
               ('a, 'b, 'c, 'd, 'e) t
            -> ledger:
                 (   ( [< `Read | `Set_and_create ]
                     , ('f, 'g, 'h, 'i, 'j) t
                     , 'f )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'a
                  -> 'k)
            -> seed:
                 (   ( [< `Read | `Set_and_create ]
                     , ('l, 'm, 'n, 'o, 'p) t
                     , 'm )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'b
                  -> 'q)
            -> start_checkpoint:
                 (   ( [< `Read | `Set_and_create ]
                     , ('r, 's, 't, 'u, 'v) t
                     , 't )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'c
                  -> 'w)
            -> lock_checkpoint:
                 (   ( [< `Read | `Set_and_create ]
                     , ('x, 'y, 'z, 'a1, 'b1) t
                     , 'a1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'd
                  -> 'c1)
            -> epoch_length:
                 (   ( [< `Read | `Set_and_create ]
                     , ('d1, 'e1, 'f1, 'g1, 'h1) t
                     , 'h1 )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b, 'c, 'd, 'e) t
                  -> 'e
                  -> 'i1)
            -> ('k, 'q, 'w, 'c1, 'i1) t

          val set_all_mutable_fields : 'a -> unit
        end
      end

      module With_version : sig
        type ( 'epoch_ledger
             , 'epoch_seed
             , 'start_checkpoint
             , 'lock_checkpoint
             , 'length )
             typ =
          ( 'epoch_ledger
          , 'epoch_seed
          , 'start_checkpoint
          , 'lock_checkpoint
          , 'length )
          t

        val bin_shape_typ :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'epoch_ledger Core_kernel.Bin_prot.Size.sizer
          -> 'epoch_seed Core_kernel.Bin_prot.Size.sizer
          -> 'start_checkpoint Core_kernel.Bin_prot.Size.sizer
          -> 'lock_checkpoint Core_kernel.Bin_prot.Size.sizer
          -> 'length Core_kernel.Bin_prot.Size.sizer
          -> ( 'epoch_ledger
             , 'epoch_seed
             , 'start_checkpoint
             , 'lock_checkpoint
             , 'length )
             typ
             Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'epoch_ledger Core_kernel.Bin_prot.Write.writer
          -> 'epoch_seed Core_kernel.Bin_prot.Write.writer
          -> 'start_checkpoint Core_kernel.Bin_prot.Write.writer
          -> 'lock_checkpoint Core_kernel.Bin_prot.Write.writer
          -> 'length Core_kernel.Bin_prot.Write.writer
          -> ( 'epoch_ledger
             , 'epoch_seed
             , 'start_checkpoint
             , 'lock_checkpoint
             , 'length )
             typ
             Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> 'd Core_kernel.Bin_prot.Type_class.writer
          -> 'e Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c, 'd, 'e) typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'epoch_ledger Core_kernel.Bin_prot.Read.reader
          -> 'epoch_seed Core_kernel.Bin_prot.Read.reader
          -> 'start_checkpoint Core_kernel.Bin_prot.Read.reader
          -> 'lock_checkpoint Core_kernel.Bin_prot.Read.reader
          -> 'length Core_kernel.Bin_prot.Read.reader
          -> (   int
              -> ( 'epoch_ledger
                 , 'epoch_seed
                 , 'start_checkpoint
                 , 'lock_checkpoint
                 , 'length )
                 typ)
             Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'epoch_ledger Core_kernel.Bin_prot.Read.reader
          -> 'epoch_seed Core_kernel.Bin_prot.Read.reader
          -> 'start_checkpoint Core_kernel.Bin_prot.Read.reader
          -> 'lock_checkpoint Core_kernel.Bin_prot.Read.reader
          -> 'length Core_kernel.Bin_prot.Read.reader
          -> ( 'epoch_ledger
             , 'epoch_seed
             , 'start_checkpoint
             , 'lock_checkpoint
             , 'length )
             typ
             Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> 'c Core_kernel.Bin_prot.Type_class.reader
          -> 'd Core_kernel.Bin_prot.Type_class.reader
          -> 'e Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c, 'd, 'e) typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> 'd Core_kernel.Bin_prot.Type_class.t
          -> 'e Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c, 'd, 'e) typ Core_kernel.Bin_prot.Type_class.t

        type ( 'epoch_ledger
             , 'epoch_seed
             , 'start_checkpoint
             , 'lock_checkpoint
             , 'length )
             t =
          { version : int
          ; t :
              ( 'epoch_ledger
              , 'epoch_seed
              , 'start_checkpoint
              , 'lock_checkpoint
              , 'length )
              typ
          }

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'epoch_ledger Core_kernel.Bin_prot.Size.sizer
          -> 'epoch_seed Core_kernel.Bin_prot.Size.sizer
          -> 'start_checkpoint Core_kernel.Bin_prot.Size.sizer
          -> 'lock_checkpoint Core_kernel.Bin_prot.Size.sizer
          -> 'length Core_kernel.Bin_prot.Size.sizer
          -> ( 'epoch_ledger
             , 'epoch_seed
             , 'start_checkpoint
             , 'lock_checkpoint
             , 'length )
             t
             Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'epoch_ledger Core_kernel.Bin_prot.Write.writer
          -> 'epoch_seed Core_kernel.Bin_prot.Write.writer
          -> 'start_checkpoint Core_kernel.Bin_prot.Write.writer
          -> 'lock_checkpoint Core_kernel.Bin_prot.Write.writer
          -> 'length Core_kernel.Bin_prot.Write.writer
          -> ( 'epoch_ledger
             , 'epoch_seed
             , 'start_checkpoint
             , 'lock_checkpoint
             , 'length )
             t
             Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> 'd Core_kernel.Bin_prot.Type_class.writer
          -> 'e Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'epoch_ledger Core_kernel.Bin_prot.Read.reader
          -> 'epoch_seed Core_kernel.Bin_prot.Read.reader
          -> 'start_checkpoint Core_kernel.Bin_prot.Read.reader
          -> 'lock_checkpoint Core_kernel.Bin_prot.Read.reader
          -> 'length Core_kernel.Bin_prot.Read.reader
          -> (   int
              -> ( 'epoch_ledger
                 , 'epoch_seed
                 , 'start_checkpoint
                 , 'lock_checkpoint
                 , 'length )
                 t)
             Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'epoch_ledger Core_kernel.Bin_prot.Read.reader
          -> 'epoch_seed Core_kernel.Bin_prot.Read.reader
          -> 'start_checkpoint Core_kernel.Bin_prot.Read.reader
          -> 'lock_checkpoint Core_kernel.Bin_prot.Read.reader
          -> 'length Core_kernel.Bin_prot.Read.reader
          -> ( 'epoch_ledger
             , 'epoch_seed
             , 'start_checkpoint
             , 'lock_checkpoint
             , 'length )
             t
             Core_kernel.Bin_prot.Read.reader

        val bin_reader_t :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> 'c Core_kernel.Bin_prot.Type_class.reader
          -> 'd Core_kernel.Bin_prot.Type_class.reader
          -> 'e Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.reader

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> 'd Core_kernel.Bin_prot.Type_class.t
          -> 'e Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.t

        val create : ('a, 'b, 'c, 'd, 'e) typ -> ('a, 'b, 'c, 'd, 'e) t
      end

      val bin_read_t :
           'a Core_kernel.Bin_prot.Read.reader
        -> 'b Core_kernel.Bin_prot.Read.reader
        -> 'c Core_kernel.Bin_prot.Read.reader
        -> 'd Core_kernel.Bin_prot.Read.reader
        -> 'e Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> ('a, 'b, 'c, 'd, 'e) t

      val __bin_read_t__ :
           'a Core_kernel.Bin_prot.Read.reader
        -> 'b Core_kernel.Bin_prot.Read.reader
        -> 'c Core_kernel.Bin_prot.Read.reader
        -> 'd Core_kernel.Bin_prot.Read.reader
        -> 'e Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> int
        -> ('a, 'b, 'c, 'd, 'e) t

      val bin_size_t :
           'a Core_kernel.Bin_prot.Size.sizer
        -> 'b Core_kernel.Bin_prot.Size.sizer
        -> 'c Core_kernel.Bin_prot.Size.sizer
        -> 'd Core_kernel.Bin_prot.Size.sizer
        -> 'e Core_kernel.Bin_prot.Size.sizer
        -> ('a, 'b, 'c, 'd, 'e) t
        -> int

      val bin_write_t :
           'a Core_kernel.Bin_prot.Write.writer
        -> 'b Core_kernel.Bin_prot.Write.writer
        -> 'c Core_kernel.Bin_prot.Write.writer
        -> 'd Core_kernel.Bin_prot.Write.writer
        -> 'e Core_kernel.Bin_prot.Write.writer
        -> Bin_prot.Common.buf
        -> pos:Bin_prot.Common.pos
        -> ('a, 'b, 'c, 'd, 'e) t
        -> Bin_prot.Common.pos

      val bin_shape_t :
           Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t

      val bin_reader_t :
           'a Core_kernel.Bin_prot.Type_class.reader
        -> 'b Core_kernel.Bin_prot.Type_class.reader
        -> 'c Core_kernel.Bin_prot.Type_class.reader
        -> 'd Core_kernel.Bin_prot.Type_class.reader
        -> 'e Core_kernel.Bin_prot.Type_class.reader
        -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.reader

      val bin_writer_t :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'b Core_kernel.Bin_prot.Type_class.writer
        -> 'c Core_kernel.Bin_prot.Type_class.writer
        -> 'd Core_kernel.Bin_prot.Type_class.writer
        -> 'e Core_kernel.Bin_prot.Type_class.writer
        -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.writer

      val bin_t :
           'a Core_kernel.Bin_prot.Type_class.t
        -> 'b Core_kernel.Bin_prot.Type_class.t
        -> 'c Core_kernel.Bin_prot.Type_class.t
        -> 'd Core_kernel.Bin_prot.Type_class.t
        -> 'e Core_kernel.Bin_prot.Type_class.t
        -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.t

      val __ :
        (   'a Core_kernel.Bin_prot.Read.reader
         -> 'b Core_kernel.Bin_prot.Read.reader
         -> 'c Core_kernel.Bin_prot.Read.reader
         -> 'd Core_kernel.Bin_prot.Read.reader
         -> 'e Core_kernel.Bin_prot.Read.reader
         -> Bin_prot.Common.buf
         -> pos_ref:Bin_prot.Common.pos_ref
         -> ('a, 'b, 'c, 'd, 'e) t)
        * (   'f Core_kernel.Bin_prot.Read.reader
           -> 'g Core_kernel.Bin_prot.Read.reader
           -> 'h Core_kernel.Bin_prot.Read.reader
           -> 'i Core_kernel.Bin_prot.Read.reader
           -> 'j Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> int
           -> ('f, 'g, 'h, 'i, 'j) t)
        * (   'k Core_kernel.Bin_prot.Size.sizer
           -> 'l Core_kernel.Bin_prot.Size.sizer
           -> 'm Core_kernel.Bin_prot.Size.sizer
           -> 'n Core_kernel.Bin_prot.Size.sizer
           -> 'o Core_kernel.Bin_prot.Size.sizer
           -> ('k, 'l, 'm, 'n, 'o) t
           -> int)
        * (   'p Core_kernel.Bin_prot.Write.writer
           -> 'q Core_kernel.Bin_prot.Write.writer
           -> 'r Core_kernel.Bin_prot.Write.writer
           -> 's Core_kernel.Bin_prot.Write.writer
           -> 't Core_kernel.Bin_prot.Write.writer
           -> Bin_prot.Common.buf
           -> pos:Bin_prot.Common.pos
           -> ('p, 'q, 'r, 's, 't) t
           -> Bin_prot.Common.pos)
        * (   Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t)
        * (   'u Core_kernel.Bin_prot.Type_class.reader
           -> 'v Core_kernel.Bin_prot.Type_class.reader
           -> 'w Core_kernel.Bin_prot.Type_class.reader
           -> 'x Core_kernel.Bin_prot.Type_class.reader
           -> 'y Core_kernel.Bin_prot.Type_class.reader
           -> ('u, 'v, 'w, 'x, 'y) t Core_kernel.Bin_prot.Type_class.reader)
        * (   'z Core_kernel.Bin_prot.Type_class.writer
           -> 'a1 Core_kernel.Bin_prot.Type_class.writer
           -> 'b1 Core_kernel.Bin_prot.Type_class.writer
           -> 'c1 Core_kernel.Bin_prot.Type_class.writer
           -> 'd1 Core_kernel.Bin_prot.Type_class.writer
           -> ('z, 'a1, 'b1, 'c1, 'd1) t Core_kernel.Bin_prot.Type_class.writer)
        * (   'e1 Core_kernel.Bin_prot.Type_class.t
           -> 'f1 Core_kernel.Bin_prot.Type_class.t
           -> 'g1 Core_kernel.Bin_prot.Type_class.t
           -> 'h1 Core_kernel.Bin_prot.Type_class.t
           -> 'i1 Core_kernel.Bin_prot.Type_class.t
           -> ('e1, 'f1, 'g1, 'h1, 'i1) t Core_kernel.Bin_prot.Type_class.t)
    end

    module Latest = V1
  end

  type ( 'epoch_ledger
       , 'epoch_seed
       , 'start_checkpoint
       , 'lock_checkpoint
       , 'length )
       t =
        ( 'epoch_ledger
        , 'epoch_seed
        , 'start_checkpoint
        , 'lock_checkpoint
        , 'length )
        Stable.V1.t =
    { ledger : 'epoch_ledger
    ; seed : 'epoch_seed
    ; start_checkpoint : 'start_checkpoint
    ; lock_checkpoint : 'lock_checkpoint
    ; epoch_length : 'length
    }

  val to_yojson :
       ('epoch_ledger -> Yojson.Safe.t)
    -> ('epoch_seed -> Yojson.Safe.t)
    -> ('start_checkpoint -> Yojson.Safe.t)
    -> ('lock_checkpoint -> Yojson.Safe.t)
    -> ('length -> Yojson.Safe.t)
    -> ( 'epoch_ledger
       , 'epoch_seed
       , 'start_checkpoint
       , 'lock_checkpoint
       , 'length )
       t
    -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'epoch_ledger Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'epoch_seed Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'start_checkpoint Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'lock_checkpoint Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'length Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> ( 'epoch_ledger
       , 'epoch_seed
       , 'start_checkpoint
       , 'lock_checkpoint
       , 'length )
       t
       Ppx_deriving_yojson_runtime.error_or

  val to_hlist :
       ( 'epoch_ledger
       , 'epoch_seed
       , 'start_checkpoint
       , 'lock_checkpoint
       , 'length )
       t
    -> ( unit
       ,    'epoch_ledger
         -> 'epoch_seed
         -> 'start_checkpoint
         -> 'lock_checkpoint
         -> 'length
         -> unit )
       H_list.t

  val of_hlist :
       ( unit
       ,    'epoch_ledger
         -> 'epoch_seed
         -> 'start_checkpoint
         -> 'lock_checkpoint
         -> 'length
         -> unit )
       H_list.t
    -> ( 'epoch_ledger
       , 'epoch_seed
       , 'start_checkpoint
       , 'lock_checkpoint
       , 'length )
       t

  val t_of_sexp :
       (Ppx_sexp_conv_lib.Sexp.t -> 'epoch_ledger)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'epoch_seed)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'start_checkpoint)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'lock_checkpoint)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'length)
    -> Ppx_sexp_conv_lib.Sexp.t
    -> ( 'epoch_ledger
       , 'epoch_seed
       , 'start_checkpoint
       , 'lock_checkpoint
       , 'length )
       t

  val sexp_of_t :
       ('epoch_ledger -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('epoch_seed -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('start_checkpoint -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('lock_checkpoint -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('length -> Ppx_sexp_conv_lib.Sexp.t)
    -> ( 'epoch_ledger
       , 'epoch_seed
       , 'start_checkpoint
       , 'lock_checkpoint
       , 'length )
       t
    -> Ppx_sexp_conv_lib.Sexp.t

  val equal :
       ('epoch_ledger -> 'epoch_ledger -> bool)
    -> ('epoch_seed -> 'epoch_seed -> bool)
    -> ('start_checkpoint -> 'start_checkpoint -> bool)
    -> ('lock_checkpoint -> 'lock_checkpoint -> bool)
    -> ('length -> 'length -> bool)
    -> ( 'epoch_ledger
       , 'epoch_seed
       , 'start_checkpoint
       , 'lock_checkpoint
       , 'length )
       t
    -> ( 'epoch_ledger
       , 'epoch_seed
       , 'start_checkpoint
       , 'lock_checkpoint
       , 'length )
       t
    -> bool

  val compare :
       ('epoch_ledger -> 'epoch_ledger -> int)
    -> ('epoch_seed -> 'epoch_seed -> int)
    -> ('start_checkpoint -> 'start_checkpoint -> int)
    -> ('lock_checkpoint -> 'lock_checkpoint -> int)
    -> ('length -> 'length -> int)
    -> ( 'epoch_ledger
       , 'epoch_seed
       , 'start_checkpoint
       , 'lock_checkpoint
       , 'length )
       t
    -> ( 'epoch_ledger
       , 'epoch_seed
       , 'start_checkpoint
       , 'lock_checkpoint
       , 'length )
       t
    -> int

  val hash_fold_t :
       (   Ppx_hash_lib.Std.Hash.state
        -> 'epoch_ledger
        -> Ppx_hash_lib.Std.Hash.state)
    -> (   Ppx_hash_lib.Std.Hash.state
        -> 'epoch_seed
        -> Ppx_hash_lib.Std.Hash.state)
    -> (   Ppx_hash_lib.Std.Hash.state
        -> 'start_checkpoint
        -> Ppx_hash_lib.Std.Hash.state)
    -> (   Ppx_hash_lib.Std.Hash.state
        -> 'lock_checkpoint
        -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'length -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> ( 'epoch_ledger
       , 'epoch_seed
       , 'start_checkpoint
       , 'lock_checkpoint
       , 'length )
       t
    -> Ppx_hash_lib.Std.Hash.state

  val epoch_length : ('a, 'b, 'c, 'd, 'e) t -> 'e

  val lock_checkpoint : ('a, 'b, 'c, 'd, 'e) t -> 'd

  val start_checkpoint : ('a, 'b, 'c, 'd, 'e) t -> 'c

  val seed : ('a, 'b, 'c, 'd, 'e) t -> 'b

  val ledger : ('a, 'b, 'c, 'd, 'e) t -> 'a

  module Fields : sig
    val names : string list

    val epoch_length :
      ( [< `Read | `Set_and_create ]
      , ('a, 'b, 'c, 'd, 'length) t
      , 'length )
      Fieldslib.Field.t_with_perm

    val lock_checkpoint :
      ( [< `Read | `Set_and_create ]
      , ('a, 'b, 'c, 'lock_checkpoint, 'd) t
      , 'lock_checkpoint )
      Fieldslib.Field.t_with_perm

    val start_checkpoint :
      ( [< `Read | `Set_and_create ]
      , ('a, 'b, 'start_checkpoint, 'c, 'd) t
      , 'start_checkpoint )
      Fieldslib.Field.t_with_perm

    val seed :
      ( [< `Read | `Set_and_create ]
      , ('a, 'epoch_seed, 'b, 'c, 'd) t
      , 'epoch_seed )
      Fieldslib.Field.t_with_perm

    val ledger :
      ( [< `Read | `Set_and_create ]
      , ('epoch_ledger, 'a, 'b, 'c, 'd) t
      , 'epoch_ledger )
      Fieldslib.Field.t_with_perm

    val make_creator :
         ledger:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b, 'c, 'd, 'e) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'f
            -> ('g -> 'h) * 'i)
      -> seed:
           (   ( [< `Read | `Set_and_create ]
               , ('j, 'k, 'l, 'm, 'n) t
               , 'k )
               Fieldslib.Field.t_with_perm
            -> 'i
            -> ('g -> 'o) * 'p)
      -> start_checkpoint:
           (   ( [< `Read | `Set_and_create ]
               , ('q, 'r, 's, 't, 'u) t
               , 's )
               Fieldslib.Field.t_with_perm
            -> 'p
            -> ('g -> 'v) * 'w)
      -> lock_checkpoint:
           (   ( [< `Read | `Set_and_create ]
               , ('x, 'y, 'z, 'a1, 'b1) t
               , 'a1 )
               Fieldslib.Field.t_with_perm
            -> 'w
            -> ('g -> 'c1) * 'd1)
      -> epoch_length:
           (   ( [< `Read | `Set_and_create ]
               , ('e1, 'f1, 'g1, 'h1, 'i1) t
               , 'i1 )
               Fieldslib.Field.t_with_perm
            -> 'd1
            -> ('g -> 'j1) * 'k1)
      -> 'f
      -> ('g -> ('h, 'o, 'v, 'c1, 'j1) t) * 'k1

    val create :
         ledger:'a
      -> seed:'b
      -> start_checkpoint:'c
      -> lock_checkpoint:'d
      -> epoch_length:'e
      -> ('a, 'b, 'c, 'd, 'e) t

    val map :
         ledger:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b, 'c, 'd, 'e) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'f)
      -> seed:
           (   ( [< `Read | `Set_and_create ]
               , ('g, 'h, 'i, 'j, 'k) t
               , 'h )
               Fieldslib.Field.t_with_perm
            -> 'l)
      -> start_checkpoint:
           (   ( [< `Read | `Set_and_create ]
               , ('m, 'n, 'o, 'p, 'q) t
               , 'o )
               Fieldslib.Field.t_with_perm
            -> 'r)
      -> lock_checkpoint:
           (   ( [< `Read | `Set_and_create ]
               , ('s, 't, 'u, 'v, 'w) t
               , 'v )
               Fieldslib.Field.t_with_perm
            -> 'x)
      -> epoch_length:
           (   ( [< `Read | `Set_and_create ]
               , ('y, 'z, 'a1, 'b1, 'c1) t
               , 'c1 )
               Fieldslib.Field.t_with_perm
            -> 'd1)
      -> ('f, 'l, 'r, 'x, 'd1) t

    val iter :
         ledger:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b, 'c, 'd, 'e) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> seed:
           (   ( [< `Read | `Set_and_create ]
               , ('f, 'g, 'h, 'i, 'j) t
               , 'g )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> start_checkpoint:
           (   ( [< `Read | `Set_and_create ]
               , ('k, 'l, 'm, 'n, 'o) t
               , 'm )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> lock_checkpoint:
           (   ( [< `Read | `Set_and_create ]
               , ('p, 'q, 'r, 's, 't) t
               , 's )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> epoch_length:
           (   ( [< `Read | `Set_and_create ]
               , ('u, 'v, 'w, 'x, 'y) t
               , 'y )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> unit

    val fold :
         init:'a
      -> ledger:
           (   'a
            -> ( [< `Read | `Set_and_create ]
               , ('b, 'c, 'd, 'e, 'f) t
               , 'b )
               Fieldslib.Field.t_with_perm
            -> 'g)
      -> seed:
           (   'g
            -> ( [< `Read | `Set_and_create ]
               , ('h, 'i, 'j, 'k, 'l) t
               , 'i )
               Fieldslib.Field.t_with_perm
            -> 'm)
      -> start_checkpoint:
           (   'm
            -> ( [< `Read | `Set_and_create ]
               , ('n, 'o, 'p, 'q, 'r) t
               , 'p )
               Fieldslib.Field.t_with_perm
            -> 's)
      -> lock_checkpoint:
           (   's
            -> ( [< `Read | `Set_and_create ]
               , ('t, 'u, 'v, 'w, 'x) t
               , 'w )
               Fieldslib.Field.t_with_perm
            -> 'y)
      -> epoch_length:
           (   'y
            -> ( [< `Read | `Set_and_create ]
               , ('z, 'a1, 'b1, 'c1, 'd1) t
               , 'd1 )
               Fieldslib.Field.t_with_perm
            -> 'e1)
      -> 'e1

    val map_poly :
         ( [< `Read | `Set_and_create ]
         , ('a, 'b, 'c, 'd, 'e) t
         , 'f )
         Fieldslib.Field.user
      -> 'f list

    val for_all :
         ledger:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b, 'c, 'd, 'e) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> seed:
           (   ( [< `Read | `Set_and_create ]
               , ('f, 'g, 'h, 'i, 'j) t
               , 'g )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> start_checkpoint:
           (   ( [< `Read | `Set_and_create ]
               , ('k, 'l, 'm, 'n, 'o) t
               , 'm )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> lock_checkpoint:
           (   ( [< `Read | `Set_and_create ]
               , ('p, 'q, 'r, 's, 't) t
               , 's )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> epoch_length:
           (   ( [< `Read | `Set_and_create ]
               , ('u, 'v, 'w, 'x, 'y) t
               , 'y )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val exists :
         ledger:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b, 'c, 'd, 'e) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> seed:
           (   ( [< `Read | `Set_and_create ]
               , ('f, 'g, 'h, 'i, 'j) t
               , 'g )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> start_checkpoint:
           (   ( [< `Read | `Set_and_create ]
               , ('k, 'l, 'm, 'n, 'o) t
               , 'm )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> lock_checkpoint:
           (   ( [< `Read | `Set_and_create ]
               , ('p, 'q, 'r, 's, 't) t
               , 's )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> epoch_length:
           (   ( [< `Read | `Set_and_create ]
               , ('u, 'v, 'w, 'x, 'y) t
               , 'y )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val to_list :
         ledger:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b, 'c, 'd, 'e) t
               , 'a )
               Fieldslib.Field.t_with_perm
            -> 'f)
      -> seed:
           (   ( [< `Read | `Set_and_create ]
               , ('g, 'h, 'i, 'j, 'k) t
               , 'h )
               Fieldslib.Field.t_with_perm
            -> 'f)
      -> start_checkpoint:
           (   ( [< `Read | `Set_and_create ]
               , ('l, 'm, 'n, 'o, 'p) t
               , 'n )
               Fieldslib.Field.t_with_perm
            -> 'f)
      -> lock_checkpoint:
           (   ( [< `Read | `Set_and_create ]
               , ('q, 'r, 's, 't, 'u) t
               , 't )
               Fieldslib.Field.t_with_perm
            -> 'f)
      -> epoch_length:
           (   ( [< `Read | `Set_and_create ]
               , ('v, 'w, 'x, 'y, 'z) t
               , 'z )
               Fieldslib.Field.t_with_perm
            -> 'f)
      -> 'f list

    module Direct : sig
      val iter :
           ('a, 'b, 'c, 'd, 'e) t
        -> ledger:
             (   ( [< `Read | `Set_and_create ]
                 , ('f, 'g, 'h, 'i, 'j) t
                 , 'f )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'a
              -> unit)
        -> seed:
             (   ( [< `Read | `Set_and_create ]
                 , ('k, 'l, 'm, 'n, 'o) t
                 , 'l )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'b
              -> unit)
        -> start_checkpoint:
             (   ( [< `Read | `Set_and_create ]
                 , ('p, 'q, 'r, 's, 't) t
                 , 'r )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'c
              -> unit)
        -> lock_checkpoint:
             (   ( [< `Read | `Set_and_create ]
                 , ('u, 'v, 'w, 'x, 'y) t
                 , 'x )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'd
              -> unit)
        -> epoch_length:
             (   ( [< `Read | `Set_and_create ]
                 , ('z, 'a1, 'b1, 'c1, 'd1) t
                 , 'd1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'e
              -> 'e1)
        -> 'e1

      val fold :
           ('a, 'b, 'c, 'd, 'e) t
        -> init:'f
        -> ledger:
             (   'f
              -> ( [< `Read | `Set_and_create ]
                 , ('g, 'h, 'i, 'j, 'k) t
                 , 'g )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'a
              -> 'l)
        -> seed:
             (   'l
              -> ( [< `Read | `Set_and_create ]
                 , ('m, 'n, 'o, 'p, 'q) t
                 , 'n )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'b
              -> 'r)
        -> start_checkpoint:
             (   'r
              -> ( [< `Read | `Set_and_create ]
                 , ('s, 't, 'u, 'v, 'w) t
                 , 'u )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'c
              -> 'x)
        -> lock_checkpoint:
             (   'x
              -> ( [< `Read | `Set_and_create ]
                 , ('y, 'z, 'a1, 'b1, 'c1) t
                 , 'b1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'd
              -> 'd1)
        -> epoch_length:
             (   'd1
              -> ( [< `Read | `Set_and_create ]
                 , ('e1, 'f1, 'g1, 'h1, 'i1) t
                 , 'i1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'e
              -> 'j1)
        -> 'j1

      val for_all :
           ('a, 'b, 'c, 'd, 'e) t
        -> ledger:
             (   ( [< `Read | `Set_and_create ]
                 , ('f, 'g, 'h, 'i, 'j) t
                 , 'f )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'a
              -> bool)
        -> seed:
             (   ( [< `Read | `Set_and_create ]
                 , ('k, 'l, 'm, 'n, 'o) t
                 , 'l )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'b
              -> bool)
        -> start_checkpoint:
             (   ( [< `Read | `Set_and_create ]
                 , ('p, 'q, 'r, 's, 't) t
                 , 'r )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'c
              -> bool)
        -> lock_checkpoint:
             (   ( [< `Read | `Set_and_create ]
                 , ('u, 'v, 'w, 'x, 'y) t
                 , 'x )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'd
              -> bool)
        -> epoch_length:
             (   ( [< `Read | `Set_and_create ]
                 , ('z, 'a1, 'b1, 'c1, 'd1) t
                 , 'd1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'e
              -> bool)
        -> bool

      val exists :
           ('a, 'b, 'c, 'd, 'e) t
        -> ledger:
             (   ( [< `Read | `Set_and_create ]
                 , ('f, 'g, 'h, 'i, 'j) t
                 , 'f )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'a
              -> bool)
        -> seed:
             (   ( [< `Read | `Set_and_create ]
                 , ('k, 'l, 'm, 'n, 'o) t
                 , 'l )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'b
              -> bool)
        -> start_checkpoint:
             (   ( [< `Read | `Set_and_create ]
                 , ('p, 'q, 'r, 's, 't) t
                 , 'r )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'c
              -> bool)
        -> lock_checkpoint:
             (   ( [< `Read | `Set_and_create ]
                 , ('u, 'v, 'w, 'x, 'y) t
                 , 'x )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'd
              -> bool)
        -> epoch_length:
             (   ( [< `Read | `Set_and_create ]
                 , ('z, 'a1, 'b1, 'c1, 'd1) t
                 , 'd1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'e
              -> bool)
        -> bool

      val to_list :
           ('a, 'b, 'c, 'd, 'e) t
        -> ledger:
             (   ( [< `Read | `Set_and_create ]
                 , ('f, 'g, 'h, 'i, 'j) t
                 , 'f )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'a
              -> 'k)
        -> seed:
             (   ( [< `Read | `Set_and_create ]
                 , ('l, 'm, 'n, 'o, 'p) t
                 , 'm )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'b
              -> 'k)
        -> start_checkpoint:
             (   ( [< `Read | `Set_and_create ]
                 , ('q, 'r, 's, 't, 'u) t
                 , 's )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'c
              -> 'k)
        -> lock_checkpoint:
             (   ( [< `Read | `Set_and_create ]
                 , ('v, 'w, 'x, 'y, 'z) t
                 , 'y )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'd
              -> 'k)
        -> epoch_length:
             (   ( [< `Read | `Set_and_create ]
                 , ('a1, 'b1, 'c1, 'd1, 'e1) t
                 , 'e1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'e
              -> 'k)
        -> 'k list

      val map :
           ('a, 'b, 'c, 'd, 'e) t
        -> ledger:
             (   ( [< `Read | `Set_and_create ]
                 , ('f, 'g, 'h, 'i, 'j) t
                 , 'f )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'a
              -> 'k)
        -> seed:
             (   ( [< `Read | `Set_and_create ]
                 , ('l, 'm, 'n, 'o, 'p) t
                 , 'm )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'b
              -> 'q)
        -> start_checkpoint:
             (   ( [< `Read | `Set_and_create ]
                 , ('r, 's, 't, 'u, 'v) t
                 , 't )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'c
              -> 'w)
        -> lock_checkpoint:
             (   ( [< `Read | `Set_and_create ]
                 , ('x, 'y, 'z, 'a1, 'b1) t
                 , 'a1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'd
              -> 'c1)
        -> epoch_length:
             (   ( [< `Read | `Set_and_create ]
                 , ('d1, 'e1, 'f1, 'g1, 'h1) t
                 , 'h1 )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b, 'c, 'd, 'e) t
              -> 'e
              -> 'i1)
        -> ('k, 'q, 'w, 'c1, 'i1) t

      val set_all_mutable_fields : 'a -> unit
    end
  end
end

type var =
  ( Epoch_ledger.var
  , Epoch_seed.var
  , State_hash.var
  , State_hash.var
  , Mina_numbers.Length.Checked.t )
  Poly.t

val if_ :
     Snark_params.Tick.Boolean.var
  -> then_:var
  -> else_:var
  -> ( ( (Frozen_ledger_hash0.var, Currency.Amount.var) Epoch_ledger.Poly.t
       , Epoch_seed.var
       , State_hash.var
       , State_hash.var
       , Mina_numbers.Length.Checked.t )
       Poly.t
     , 'a )
     Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

module Value : sig
  module Stable : sig
    module V1 : sig
      type t =
        ( Epoch_ledger.Value.Stable.V1.t
        , Epoch_seed.Stable.V1.t
        , State_hash.Stable.V1.t
        , State_hash.Stable.V1.t
        , Mina_numbers.Length.Stable.V1.t )
        Poly.t

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val compare : t -> t -> int

      val equal : t -> t -> bool

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

      val to_latest : 'a -> 'a

      module With_version : sig
        type typ = t

        val bin_shape_typ : Core_kernel.Bin_prot.Shape.t

        val bin_size_typ : typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ : typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ : typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ : (int -> typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ : typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ : typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ : typ Core_kernel.Bin_prot.Type_class.t

        type t = { version : int; t : typ }

        val bin_shape_t : Core_kernel.Bin_prot.Shape.t

        val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t : t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t : t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

        val bin_t : t Core_kernel.Bin_prot.Type_class.t

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

      val bin_shape_t : Core_kernel.Bin_prot.Shape.t

      val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

      val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

      val bin_t : t Core_kernel.Bin_prot.Type_class.t

      val __ :
        (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t)
        * (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> int -> t)
        * (t -> int)
        * (   Bin_prot.Common.buf
           -> pos:Bin_prot.Common.pos
           -> t
           -> Bin_prot.Common.pos)
        * Core_kernel.Bin_prot.Shape.t
        * t Core_kernel.Bin_prot.Type_class.reader
        * t Core_kernel.Bin_prot.Type_class.writer
        * t Core_kernel.Bin_prot.Type_class.t
    end

    module Latest = V1

    val versions :
      ( int
      * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t) )
      array

    val bin_read_to_latest_opt :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> Latest.t option

    val __ :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> Latest.t option
  end

  type t = Stable.Latest.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val compare : t -> t -> int

  val equal : t -> t -> bool

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
end
