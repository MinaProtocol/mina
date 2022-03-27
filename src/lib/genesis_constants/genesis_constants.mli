module Proof_level : sig
  type t = Full | Check | None

  val bin_shape_t : Core_kernel.Bin_prot.Shape.t

  val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

  val bin_read_t : t Core_kernel.Bin_prot.Read.reader

  val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

  val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

  val bin_write_t : t Core_kernel.Bin_prot.Write.writer

  val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

  val bin_t : t Core_kernel.Bin_prot.Type_class.t

  val equal : t -> t -> bool

  val to_string : t -> string

  val of_string : string -> t

  val compiled : t

  val for_unit_tests : t
end

module Fork_constants : sig
  type t =
    { previous_state_hash : Pickles.Backend.Tick.Field.Stable.Latest.t
    ; previous_length : Mina_numbers.Length.Stable.Latest.t
    ; previous_global_slot : Mina_numbers.Global_slot.Stable.Latest.t
    }

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val bin_shape_t : Core_kernel.Bin_prot.Shape.t

  val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

  val bin_read_t : t Core_kernel.Bin_prot.Read.reader

  val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

  val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

  val bin_write_t : t Core_kernel.Bin_prot.Write.writer

  val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

  val bin_t : t Core_kernel.Bin_prot.Type_class.t

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val equal : t -> t -> bool

  val compare : t -> t -> int
end

module Constraint_constants : sig
  type t =
    { sub_windows_per_window : int
    ; ledger_depth : int
    ; work_delay : int
    ; block_window_duration_ms : int
    ; transaction_capacity_log_2 : int
    ; pending_coinbase_depth : int
    ; coinbase_amount : Currency.Amount.Stable.Latest.t
    ; supercharged_coinbase_factor : int
    ; account_creation_fee : Currency.Fee.Stable.Latest.t
    ; fork : Fork_constants.t option
    }

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val bin_shape_t : Core_kernel.Bin_prot.Shape.t

  val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

  val bin_read_t : t Core_kernel.Bin_prot.Read.reader

  val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

  val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

  val bin_write_t : t Core_kernel.Bin_prot.Write.writer

  val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

  val bin_t : t Core_kernel.Bin_prot.Type_class.t

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val equal : t -> t -> bool

  val compare : t -> t -> int

  val to_snark_keys_header : t -> Snark_keys_header.Constraint_constants.t

  val compiled : t

  val for_unit_tests : t
end

val genesis_timestamp_of_string :
  Core_kernel__.Import.string -> Core_kernel.Time.t

val of_time : Core_kernel.Time.t -> Core_kernel.Int64.t

val validate_time :
     Core_kernel__.Import.string option
  -> (Core_kernel.Int64.t, string) Core_kernel._result

val genesis_timestamp_to_string :
  Core_kernel.Int64.t -> Core_kernel__.Import.string

module Protocol : sig
  module Poly : sig
    module Stable : sig
      module V1 : sig
        type ('length, 'delta, 'genesis_state_timestamp) t =
          { k : 'length
          ; slots_per_epoch : 'length
          ; slots_per_sub_window : 'length
          ; delta : 'delta
          ; genesis_state_timestamp : 'genesis_state_timestamp
          }

        val compare :
             ('length -> 'length -> Ppx_deriving_runtime.int)
          -> ('delta -> 'delta -> Ppx_deriving_runtime.int)
          -> (   'genesis_state_timestamp
              -> 'genesis_state_timestamp
              -> Ppx_deriving_runtime.int)
          -> ('length, 'delta, 'genesis_state_timestamp) t
          -> ('length, 'delta, 'genesis_state_timestamp) t
          -> Ppx_deriving_runtime.int

        val to_yojson :
             ('length -> Yojson.Safe.t)
          -> ('delta -> Yojson.Safe.t)
          -> ('genesis_state_timestamp -> Yojson.Safe.t)
          -> ('length, 'delta, 'genesis_state_timestamp) t
          -> Yojson.Safe.t

        val of_yojson :
             (Yojson.Safe.t -> 'length Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'delta Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'genesis_state_timestamp Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ('length, 'delta, 'genesis_state_timestamp) t
             Ppx_deriving_yojson_runtime.error_or

        val version : int

        val __versioned__ : unit

        val equal :
             ('length -> 'length -> bool)
          -> ('delta -> 'delta -> bool)
          -> ('genesis_state_timestamp -> 'genesis_state_timestamp -> bool)
          -> ('length, 'delta, 'genesis_state_timestamp) t
          -> ('length, 'delta, 'genesis_state_timestamp) t
          -> bool

        val hash_fold_t :
             (   Ppx_hash_lib.Std.Hash.state
              -> 'length
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'delta
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'genesis_state_timestamp
              -> Ppx_hash_lib.Std.Hash.state)
          -> Ppx_hash_lib.Std.Hash.state
          -> ('length, 'delta, 'genesis_state_timestamp) t
          -> Ppx_hash_lib.Std.Hash.state

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'length)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'delta)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'genesis_state_timestamp)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ('length, 'delta, 'genesis_state_timestamp) t

        val sexp_of_t :
             ('length -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('delta -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('genesis_state_timestamp -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('length, 'delta, 'genesis_state_timestamp) t
          -> Ppx_sexp_conv_lib.Sexp.t

        val to_hlist :
             ('length, 'delta, 'genesis_state_timestamp) t
          -> ( unit
             ,    'length
               -> 'length
               -> 'length
               -> 'delta
               -> 'genesis_state_timestamp
               -> unit )
             H_list.t

        val of_hlist :
             ( unit
             ,    'length
               -> 'length
               -> 'length
               -> 'delta
               -> 'genesis_state_timestamp
               -> unit )
             H_list.t
          -> ('length, 'delta, 'genesis_state_timestamp) t

        val genesis_state_timestamp : ('a, 'b, 'c) t -> 'c

        val delta : ('a, 'b, 'c) t -> 'b

        val slots_per_sub_window : ('a, 'b, 'c) t -> 'a

        val slots_per_epoch : ('a, 'b, 'c) t -> 'a

        val k : ('a, 'b, 'c) t -> 'a

        module Fields : sig
          val names : string list

          val genesis_state_timestamp :
            ( [< `Read | `Set_and_create ]
            , ('a, 'b, 'genesis_state_timestamp) t
            , 'genesis_state_timestamp )
            Fieldslib.Field.t_with_perm

          val delta :
            ( [< `Read | `Set_and_create ]
            , ('a, 'delta, 'b) t
            , 'delta )
            Fieldslib.Field.t_with_perm

          val slots_per_sub_window :
            ( [< `Read | `Set_and_create ]
            , ('length, 'a, 'b) t
            , 'length )
            Fieldslib.Field.t_with_perm

          val slots_per_epoch :
            ( [< `Read | `Set_and_create ]
            , ('length, 'a, 'b) t
            , 'length )
            Fieldslib.Field.t_with_perm

          val k :
            ( [< `Read | `Set_and_create ]
            , ('length, 'a, 'b) t
            , 'length )
            Fieldslib.Field.t_with_perm

          val make_creator :
               k:
                 (   ( [< `Read | `Set_and_create ]
                     , ('a, 'b, 'c) t
                     , 'a )
                     Fieldslib.Field.t_with_perm
                  -> 'd
                  -> ('e -> 'f) * 'g)
            -> slots_per_epoch:
                 (   ( [< `Read | `Set_and_create ]
                     , ('h, 'i, 'j) t
                     , 'h )
                     Fieldslib.Field.t_with_perm
                  -> 'g
                  -> ('e -> 'f) * 'k)
            -> slots_per_sub_window:
                 (   ( [< `Read | `Set_and_create ]
                     , ('l, 'm, 'n) t
                     , 'l )
                     Fieldslib.Field.t_with_perm
                  -> 'k
                  -> ('e -> 'f) * 'o)
            -> delta:
                 (   ( [< `Read | `Set_and_create ]
                     , ('p, 'q, 'r) t
                     , 'q )
                     Fieldslib.Field.t_with_perm
                  -> 'o
                  -> ('e -> 's) * 't)
            -> genesis_state_timestamp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('u, 'v, 'w) t
                     , 'w )
                     Fieldslib.Field.t_with_perm
                  -> 't
                  -> ('e -> 'x) * 'y)
            -> 'd
            -> ('e -> ('f, 's, 'x) t) * 'y

          val create :
               k:'a
            -> slots_per_epoch:'a
            -> slots_per_sub_window:'a
            -> delta:'b
            -> genesis_state_timestamp:'c
            -> ('a, 'b, 'c) t

          val map :
               k:
                 (   ( [< `Read | `Set_and_create ]
                     , ('a, 'b, 'c) t
                     , 'a )
                     Fieldslib.Field.t_with_perm
                  -> 'd)
            -> slots_per_epoch:
                 (   ( [< `Read | `Set_and_create ]
                     , ('e, 'f, 'g) t
                     , 'e )
                     Fieldslib.Field.t_with_perm
                  -> 'd)
            -> slots_per_sub_window:
                 (   ( [< `Read | `Set_and_create ]
                     , ('h, 'i, 'j) t
                     , 'h )
                     Fieldslib.Field.t_with_perm
                  -> 'd)
            -> delta:
                 (   ( [< `Read | `Set_and_create ]
                     , ('k, 'l, 'm) t
                     , 'l )
                     Fieldslib.Field.t_with_perm
                  -> 'n)
            -> genesis_state_timestamp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('o, 'p, 'q) t
                     , 'q )
                     Fieldslib.Field.t_with_perm
                  -> 'r)
            -> ('d, 'n, 'r) t

          val iter :
               k:
                 (   ( [< `Read | `Set_and_create ]
                     , ('a, 'b, 'c) t
                     , 'a )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> slots_per_epoch:
                 (   ( [< `Read | `Set_and_create ]
                     , ('d, 'e, 'f) t
                     , 'd )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> slots_per_sub_window:
                 (   ( [< `Read | `Set_and_create ]
                     , ('g, 'h, 'i) t
                     , 'g )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> delta:
                 (   ( [< `Read | `Set_and_create ]
                     , ('j, 'k, 'l) t
                     , 'k )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> genesis_state_timestamp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('m, 'n, 'o) t
                     , 'o )
                     Fieldslib.Field.t_with_perm
                  -> unit)
            -> unit

          val fold :
               init:'a
            -> k:
                 (   'a
                  -> ( [< `Read | `Set_and_create ]
                     , ('b, 'c, 'd) t
                     , 'b )
                     Fieldslib.Field.t_with_perm
                  -> 'e)
            -> slots_per_epoch:
                 (   'e
                  -> ( [< `Read | `Set_and_create ]
                     , ('f, 'g, 'h) t
                     , 'f )
                     Fieldslib.Field.t_with_perm
                  -> 'i)
            -> slots_per_sub_window:
                 (   'i
                  -> ( [< `Read | `Set_and_create ]
                     , ('j, 'k, 'l) t
                     , 'j )
                     Fieldslib.Field.t_with_perm
                  -> 'm)
            -> delta:
                 (   'm
                  -> ( [< `Read | `Set_and_create ]
                     , ('n, 'o, 'p) t
                     , 'o )
                     Fieldslib.Field.t_with_perm
                  -> 'q)
            -> genesis_state_timestamp:
                 (   'q
                  -> ( [< `Read | `Set_and_create ]
                     , ('r, 's, 't) t
                     , 't )
                     Fieldslib.Field.t_with_perm
                  -> 'u)
            -> 'u

          val map_poly :
               ( [< `Read | `Set_and_create ]
               , ('a, 'b, 'c) t
               , 'd )
               Fieldslib.Field.user
            -> 'd list

          val for_all :
               k:
                 (   ( [< `Read | `Set_and_create ]
                     , ('a, 'b, 'c) t
                     , 'a )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> slots_per_epoch:
                 (   ( [< `Read | `Set_and_create ]
                     , ('d, 'e, 'f) t
                     , 'd )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> slots_per_sub_window:
                 (   ( [< `Read | `Set_and_create ]
                     , ('g, 'h, 'i) t
                     , 'g )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> delta:
                 (   ( [< `Read | `Set_and_create ]
                     , ('j, 'k, 'l) t
                     , 'k )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> genesis_state_timestamp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('m, 'n, 'o) t
                     , 'o )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> bool

          val exists :
               k:
                 (   ( [< `Read | `Set_and_create ]
                     , ('a, 'b, 'c) t
                     , 'a )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> slots_per_epoch:
                 (   ( [< `Read | `Set_and_create ]
                     , ('d, 'e, 'f) t
                     , 'd )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> slots_per_sub_window:
                 (   ( [< `Read | `Set_and_create ]
                     , ('g, 'h, 'i) t
                     , 'g )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> delta:
                 (   ( [< `Read | `Set_and_create ]
                     , ('j, 'k, 'l) t
                     , 'k )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> genesis_state_timestamp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('m, 'n, 'o) t
                     , 'o )
                     Fieldslib.Field.t_with_perm
                  -> bool)
            -> bool

          val to_list :
               k:
                 (   ( [< `Read | `Set_and_create ]
                     , ('a, 'b, 'c) t
                     , 'a )
                     Fieldslib.Field.t_with_perm
                  -> 'd)
            -> slots_per_epoch:
                 (   ( [< `Read | `Set_and_create ]
                     , ('e, 'f, 'g) t
                     , 'e )
                     Fieldslib.Field.t_with_perm
                  -> 'd)
            -> slots_per_sub_window:
                 (   ( [< `Read | `Set_and_create ]
                     , ('h, 'i, 'j) t
                     , 'h )
                     Fieldslib.Field.t_with_perm
                  -> 'd)
            -> delta:
                 (   ( [< `Read | `Set_and_create ]
                     , ('k, 'l, 'm) t
                     , 'l )
                     Fieldslib.Field.t_with_perm
                  -> 'd)
            -> genesis_state_timestamp:
                 (   ( [< `Read | `Set_and_create ]
                     , ('n, 'o, 'p) t
                     , 'p )
                     Fieldslib.Field.t_with_perm
                  -> 'd)
            -> 'd list

          module Direct : sig
            val iter :
                 ('a, 'b, 'c) t
              -> k:
                   (   ( [< `Read | `Set_and_create ]
                       , ('d, 'e, 'f) t
                       , 'd )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> unit)
              -> slots_per_epoch:
                   (   ( [< `Read | `Set_and_create ]
                       , ('g, 'h, 'i) t
                       , 'g )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> unit)
              -> slots_per_sub_window:
                   (   ( [< `Read | `Set_and_create ]
                       , ('j, 'k, 'l) t
                       , 'j )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> unit)
              -> delta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('m, 'n, 'o) t
                       , 'n )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'b
                    -> unit)
              -> genesis_state_timestamp:
                   (   ( [< `Read | `Set_and_create ]
                       , ('p, 'q, 'r) t
                       , 'r )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'c
                    -> 's)
              -> 's

            val fold :
                 ('a, 'b, 'c) t
              -> init:'d
              -> k:
                   (   'd
                    -> ( [< `Read | `Set_and_create ]
                       , ('e, 'f, 'g) t
                       , 'e )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> 'h)
              -> slots_per_epoch:
                   (   'h
                    -> ( [< `Read | `Set_and_create ]
                       , ('i, 'j, 'k) t
                       , 'i )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> 'l)
              -> slots_per_sub_window:
                   (   'l
                    -> ( [< `Read | `Set_and_create ]
                       , ('m, 'n, 'o) t
                       , 'm )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> 'p)
              -> delta:
                   (   'p
                    -> ( [< `Read | `Set_and_create ]
                       , ('q, 'r, 's) t
                       , 'r )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'b
                    -> 't)
              -> genesis_state_timestamp:
                   (   't
                    -> ( [< `Read | `Set_and_create ]
                       , ('u, 'v, 'w) t
                       , 'w )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'c
                    -> 'x)
              -> 'x

            val for_all :
                 ('a, 'b, 'c) t
              -> k:
                   (   ( [< `Read | `Set_and_create ]
                       , ('d, 'e, 'f) t
                       , 'd )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> bool)
              -> slots_per_epoch:
                   (   ( [< `Read | `Set_and_create ]
                       , ('g, 'h, 'i) t
                       , 'g )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> bool)
              -> slots_per_sub_window:
                   (   ( [< `Read | `Set_and_create ]
                       , ('j, 'k, 'l) t
                       , 'j )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> bool)
              -> delta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('m, 'n, 'o) t
                       , 'n )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'b
                    -> bool)
              -> genesis_state_timestamp:
                   (   ( [< `Read | `Set_and_create ]
                       , ('p, 'q, 'r) t
                       , 'r )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'c
                    -> bool)
              -> bool

            val exists :
                 ('a, 'b, 'c) t
              -> k:
                   (   ( [< `Read | `Set_and_create ]
                       , ('d, 'e, 'f) t
                       , 'd )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> bool)
              -> slots_per_epoch:
                   (   ( [< `Read | `Set_and_create ]
                       , ('g, 'h, 'i) t
                       , 'g )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> bool)
              -> slots_per_sub_window:
                   (   ( [< `Read | `Set_and_create ]
                       , ('j, 'k, 'l) t
                       , 'j )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> bool)
              -> delta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('m, 'n, 'o) t
                       , 'n )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'b
                    -> bool)
              -> genesis_state_timestamp:
                   (   ( [< `Read | `Set_and_create ]
                       , ('p, 'q, 'r) t
                       , 'r )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'c
                    -> bool)
              -> bool

            val to_list :
                 ('a, 'b, 'c) t
              -> k:
                   (   ( [< `Read | `Set_and_create ]
                       , ('d, 'e, 'f) t
                       , 'd )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> 'g)
              -> slots_per_epoch:
                   (   ( [< `Read | `Set_and_create ]
                       , ('h, 'i, 'j) t
                       , 'h )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> 'g)
              -> slots_per_sub_window:
                   (   ( [< `Read | `Set_and_create ]
                       , ('k, 'l, 'm) t
                       , 'k )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> 'g)
              -> delta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('n, 'o, 'p) t
                       , 'o )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'b
                    -> 'g)
              -> genesis_state_timestamp:
                   (   ( [< `Read | `Set_and_create ]
                       , ('q, 'r, 's) t
                       , 's )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'c
                    -> 'g)
              -> 'g list

            val map :
                 ('a, 'b, 'c) t
              -> k:
                   (   ( [< `Read | `Set_and_create ]
                       , ('d, 'e, 'f) t
                       , 'd )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> 'g)
              -> slots_per_epoch:
                   (   ( [< `Read | `Set_and_create ]
                       , ('h, 'i, 'j) t
                       , 'h )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> 'g)
              -> slots_per_sub_window:
                   (   ( [< `Read | `Set_and_create ]
                       , ('k, 'l, 'm) t
                       , 'k )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'a
                    -> 'g)
              -> delta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('n, 'o, 'p) t
                       , 'o )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'b
                    -> 'q)
              -> genesis_state_timestamp:
                   (   ( [< `Read | `Set_and_create ]
                       , ('r, 's, 't) t
                       , 't )
                       Fieldslib.Field.t_with_perm
                    -> ('a, 'b, 'c) t
                    -> 'c
                    -> 'u)
              -> ('g, 'q, 'u) t

            val set_all_mutable_fields : 'a -> unit
          end
        end

        module With_version : sig
          type ('length, 'delta, 'genesis_state_timestamp) typ =
            ('length, 'delta, 'genesis_state_timestamp) t

          val bin_shape_typ :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_typ :
               'length Core_kernel.Bin_prot.Size.sizer
            -> 'delta Core_kernel.Bin_prot.Size.sizer
            -> 'genesis_state_timestamp Core_kernel.Bin_prot.Size.sizer
            -> ('length, 'delta, 'genesis_state_timestamp) typ
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_typ :
               'length Core_kernel.Bin_prot.Write.writer
            -> 'delta Core_kernel.Bin_prot.Write.writer
            -> 'genesis_state_timestamp Core_kernel.Bin_prot.Write.writer
            -> ('length, 'delta, 'genesis_state_timestamp) typ
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_typ :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c) typ Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_typ__ :
               'length Core_kernel.Bin_prot.Read.reader
            -> 'delta Core_kernel.Bin_prot.Read.reader
            -> 'genesis_state_timestamp Core_kernel.Bin_prot.Read.reader
            -> (int -> ('length, 'delta, 'genesis_state_timestamp) typ)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_typ :
               'length Core_kernel.Bin_prot.Read.reader
            -> 'delta Core_kernel.Bin_prot.Read.reader
            -> 'genesis_state_timestamp Core_kernel.Bin_prot.Read.reader
            -> ('length, 'delta, 'genesis_state_timestamp) typ
               Core_kernel.Bin_prot.Read.reader

          val bin_reader_typ :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c) typ Core_kernel.Bin_prot.Type_class.reader

          val bin_typ :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c) typ Core_kernel.Bin_prot.Type_class.t

          type ('length, 'delta, 'genesis_state_timestamp) t =
            { version : int
            ; t : ('length, 'delta, 'genesis_state_timestamp) typ
            }

          val bin_shape_t :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_t :
               'length Core_kernel.Bin_prot.Size.sizer
            -> 'delta Core_kernel.Bin_prot.Size.sizer
            -> 'genesis_state_timestamp Core_kernel.Bin_prot.Size.sizer
            -> ('length, 'delta, 'genesis_state_timestamp) t
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_t :
               'length Core_kernel.Bin_prot.Write.writer
            -> 'delta Core_kernel.Bin_prot.Write.writer
            -> 'genesis_state_timestamp Core_kernel.Bin_prot.Write.writer
            -> ('length, 'delta, 'genesis_state_timestamp) t
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_t :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_t__ :
               'length Core_kernel.Bin_prot.Read.reader
            -> 'delta Core_kernel.Bin_prot.Read.reader
            -> 'genesis_state_timestamp Core_kernel.Bin_prot.Read.reader
            -> (int -> ('length, 'delta, 'genesis_state_timestamp) t)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_t :
               'length Core_kernel.Bin_prot.Read.reader
            -> 'delta Core_kernel.Bin_prot.Read.reader
            -> 'genesis_state_timestamp Core_kernel.Bin_prot.Read.reader
            -> ('length, 'delta, 'genesis_state_timestamp) t
               Core_kernel.Bin_prot.Read.reader

          val bin_reader_t :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.reader

          val bin_t :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.t

          val create : ('a, 'b, 'c) typ -> ('a, 'b, 'c) t
        end

        val bin_read_t :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> ('a, 'b, 'c) t

        val __bin_read_t__ :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> int
          -> ('a, 'b, 'c) t

        val bin_size_t :
             'a Core_kernel.Bin_prot.Size.sizer
          -> 'b Core_kernel.Bin_prot.Size.sizer
          -> 'c Core_kernel.Bin_prot.Size.sizer
          -> ('a, 'b, 'c) t
          -> int

        val bin_write_t :
             'a Core_kernel.Bin_prot.Write.writer
          -> 'b Core_kernel.Bin_prot.Write.writer
          -> 'c Core_kernel.Bin_prot.Write.writer
          -> Bin_prot.Common.buf
          -> pos:Bin_prot.Common.pos
          -> ('a, 'b, 'c) t
          -> Bin_prot.Common.pos

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_reader_t :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> 'c Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.reader

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.writer

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.t

        val __ :
          (   'a Core_kernel.Bin_prot.Read.reader
           -> 'b Core_kernel.Bin_prot.Read.reader
           -> 'c Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> ('a, 'b, 'c) t)
          * (   'd Core_kernel.Bin_prot.Read.reader
             -> 'e Core_kernel.Bin_prot.Read.reader
             -> 'f Core_kernel.Bin_prot.Read.reader
             -> Bin_prot.Common.buf
             -> pos_ref:Bin_prot.Common.pos_ref
             -> int
             -> ('d, 'e, 'f) t)
          * (   'g Core_kernel.Bin_prot.Size.sizer
             -> 'h Core_kernel.Bin_prot.Size.sizer
             -> 'i Core_kernel.Bin_prot.Size.sizer
             -> ('g, 'h, 'i) t
             -> int)
          * (   'j Core_kernel.Bin_prot.Write.writer
             -> 'k Core_kernel.Bin_prot.Write.writer
             -> 'l Core_kernel.Bin_prot.Write.writer
             -> Bin_prot.Common.buf
             -> pos:Bin_prot.Common.pos
             -> ('j, 'k, 'l) t
             -> Bin_prot.Common.pos)
          * (   Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t)
          * (   'm Core_kernel.Bin_prot.Type_class.reader
             -> 'n Core_kernel.Bin_prot.Type_class.reader
             -> 'o Core_kernel.Bin_prot.Type_class.reader
             -> ('m, 'n, 'o) t Core_kernel.Bin_prot.Type_class.reader)
          * (   'p Core_kernel.Bin_prot.Type_class.writer
             -> 'q Core_kernel.Bin_prot.Type_class.writer
             -> 'r Core_kernel.Bin_prot.Type_class.writer
             -> ('p, 'q, 'r) t Core_kernel.Bin_prot.Type_class.writer)
          * (   's Core_kernel.Bin_prot.Type_class.t
             -> 't Core_kernel.Bin_prot.Type_class.t
             -> 'u Core_kernel.Bin_prot.Type_class.t
             -> ('s, 't, 'u) t Core_kernel.Bin_prot.Type_class.t)
      end

      module Latest = V1
    end

    type ('length, 'delta, 'genesis_state_timestamp) t =
          ('length, 'delta, 'genesis_state_timestamp) Stable.V1.t =
      { k : 'length
      ; slots_per_epoch : 'length
      ; slots_per_sub_window : 'length
      ; delta : 'delta
      ; genesis_state_timestamp : 'genesis_state_timestamp
      }

    val compare :
         ('length -> 'length -> Ppx_deriving_runtime.int)
      -> ('delta -> 'delta -> Ppx_deriving_runtime.int)
      -> (   'genesis_state_timestamp
          -> 'genesis_state_timestamp
          -> Ppx_deriving_runtime.int)
      -> ('length, 'delta, 'genesis_state_timestamp) t
      -> ('length, 'delta, 'genesis_state_timestamp) t
      -> Ppx_deriving_runtime.int

    val to_yojson :
         ('length -> Yojson.Safe.t)
      -> ('delta -> Yojson.Safe.t)
      -> ('genesis_state_timestamp -> Yojson.Safe.t)
      -> ('length, 'delta, 'genesis_state_timestamp) t
      -> Yojson.Safe.t

    val of_yojson :
         (Yojson.Safe.t -> 'length Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'delta Ppx_deriving_yojson_runtime.error_or)
      -> (   Yojson.Safe.t
          -> 'genesis_state_timestamp Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> ('length, 'delta, 'genesis_state_timestamp) t
         Ppx_deriving_yojson_runtime.error_or

    val equal :
         ('length -> 'length -> bool)
      -> ('delta -> 'delta -> bool)
      -> ('genesis_state_timestamp -> 'genesis_state_timestamp -> bool)
      -> ('length, 'delta, 'genesis_state_timestamp) t
      -> ('length, 'delta, 'genesis_state_timestamp) t
      -> bool

    val hash_fold_t :
         (Ppx_hash_lib.Std.Hash.state -> 'length -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'delta -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'genesis_state_timestamp
          -> Ppx_hash_lib.Std.Hash.state)
      -> Ppx_hash_lib.Std.Hash.state
      -> ('length, 'delta, 'genesis_state_timestamp) t
      -> Ppx_hash_lib.Std.Hash.state

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'length)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'delta)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'genesis_state_timestamp)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> ('length, 'delta, 'genesis_state_timestamp) t

    val sexp_of_t :
         ('length -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('delta -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('genesis_state_timestamp -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('length, 'delta, 'genesis_state_timestamp) t
      -> Ppx_sexp_conv_lib.Sexp.t

    val to_hlist :
         ('length, 'delta, 'genesis_state_timestamp) t
      -> ( unit
         ,    'length
           -> 'length
           -> 'length
           -> 'delta
           -> 'genesis_state_timestamp
           -> unit )
         H_list.t

    val of_hlist :
         ( unit
         ,    'length
           -> 'length
           -> 'length
           -> 'delta
           -> 'genesis_state_timestamp
           -> unit )
         H_list.t
      -> ('length, 'delta, 'genesis_state_timestamp) t

    val genesis_state_timestamp : ('a, 'b, 'c) t -> 'c

    val delta : ('a, 'b, 'c) t -> 'b

    val slots_per_sub_window : ('a, 'b, 'c) t -> 'a

    val slots_per_epoch : ('a, 'b, 'c) t -> 'a

    val k : ('a, 'b, 'c) t -> 'a

    module Fields : sig
      val names : string list

      val genesis_state_timestamp :
        ( [< `Read | `Set_and_create ]
        , ('a, 'b, 'genesis_state_timestamp) t
        , 'genesis_state_timestamp )
        Fieldslib.Field.t_with_perm

      val delta :
        ( [< `Read | `Set_and_create ]
        , ('a, 'delta, 'b) t
        , 'delta )
        Fieldslib.Field.t_with_perm

      val slots_per_sub_window :
        ( [< `Read | `Set_and_create ]
        , ('length, 'a, 'b) t
        , 'length )
        Fieldslib.Field.t_with_perm

      val slots_per_epoch :
        ( [< `Read | `Set_and_create ]
        , ('length, 'a, 'b) t
        , 'length )
        Fieldslib.Field.t_with_perm

      val k :
        ( [< `Read | `Set_and_create ]
        , ('length, 'a, 'b) t
        , 'length )
        Fieldslib.Field.t_with_perm

      val make_creator :
           k:
             (   ( [< `Read | `Set_and_create ]
                 , ('a, 'b, 'c) t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> 'd
              -> ('e -> 'f) * 'g)
        -> slots_per_epoch:
             (   ( [< `Read | `Set_and_create ]
                 , ('h, 'i, 'j) t
                 , 'h )
                 Fieldslib.Field.t_with_perm
              -> 'g
              -> ('e -> 'f) * 'k)
        -> slots_per_sub_window:
             (   ( [< `Read | `Set_and_create ]
                 , ('l, 'm, 'n) t
                 , 'l )
                 Fieldslib.Field.t_with_perm
              -> 'k
              -> ('e -> 'f) * 'o)
        -> delta:
             (   ( [< `Read | `Set_and_create ]
                 , ('p, 'q, 'r) t
                 , 'q )
                 Fieldslib.Field.t_with_perm
              -> 'o
              -> ('e -> 's) * 't)
        -> genesis_state_timestamp:
             (   ( [< `Read | `Set_and_create ]
                 , ('u, 'v, 'w) t
                 , 'w )
                 Fieldslib.Field.t_with_perm
              -> 't
              -> ('e -> 'x) * 'y)
        -> 'd
        -> ('e -> ('f, 's, 'x) t) * 'y

      val create :
           k:'a
        -> slots_per_epoch:'a
        -> slots_per_sub_window:'a
        -> delta:'b
        -> genesis_state_timestamp:'c
        -> ('a, 'b, 'c) t

      val map :
           k:
             (   ( [< `Read | `Set_and_create ]
                 , ('a, 'b, 'c) t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> 'd)
        -> slots_per_epoch:
             (   ( [< `Read | `Set_and_create ]
                 , ('e, 'f, 'g) t
                 , 'e )
                 Fieldslib.Field.t_with_perm
              -> 'd)
        -> slots_per_sub_window:
             (   ( [< `Read | `Set_and_create ]
                 , ('h, 'i, 'j) t
                 , 'h )
                 Fieldslib.Field.t_with_perm
              -> 'd)
        -> delta:
             (   ( [< `Read | `Set_and_create ]
                 , ('k, 'l, 'm) t
                 , 'l )
                 Fieldslib.Field.t_with_perm
              -> 'n)
        -> genesis_state_timestamp:
             (   ( [< `Read | `Set_and_create ]
                 , ('o, 'p, 'q) t
                 , 'q )
                 Fieldslib.Field.t_with_perm
              -> 'r)
        -> ('d, 'n, 'r) t

      val iter :
           k:
             (   ( [< `Read | `Set_and_create ]
                 , ('a, 'b, 'c) t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> slots_per_epoch:
             (   ( [< `Read | `Set_and_create ]
                 , ('d, 'e, 'f) t
                 , 'd )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> slots_per_sub_window:
             (   ( [< `Read | `Set_and_create ]
                 , ('g, 'h, 'i) t
                 , 'g )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> delta:
             (   ( [< `Read | `Set_and_create ]
                 , ('j, 'k, 'l) t
                 , 'k )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> genesis_state_timestamp:
             (   ( [< `Read | `Set_and_create ]
                 , ('m, 'n, 'o) t
                 , 'o )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> unit

      val fold :
           init:'a
        -> k:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , ('b, 'c, 'd) t
                 , 'b )
                 Fieldslib.Field.t_with_perm
              -> 'e)
        -> slots_per_epoch:
             (   'e
              -> ( [< `Read | `Set_and_create ]
                 , ('f, 'g, 'h) t
                 , 'f )
                 Fieldslib.Field.t_with_perm
              -> 'i)
        -> slots_per_sub_window:
             (   'i
              -> ( [< `Read | `Set_and_create ]
                 , ('j, 'k, 'l) t
                 , 'j )
                 Fieldslib.Field.t_with_perm
              -> 'm)
        -> delta:
             (   'm
              -> ( [< `Read | `Set_and_create ]
                 , ('n, 'o, 'p) t
                 , 'o )
                 Fieldslib.Field.t_with_perm
              -> 'q)
        -> genesis_state_timestamp:
             (   'q
              -> ( [< `Read | `Set_and_create ]
                 , ('r, 's, 't) t
                 , 't )
                 Fieldslib.Field.t_with_perm
              -> 'u)
        -> 'u

      val map_poly :
           ( [< `Read | `Set_and_create ]
           , ('a, 'b, 'c) t
           , 'd )
           Fieldslib.Field.user
        -> 'd list

      val for_all :
           k:
             (   ( [< `Read | `Set_and_create ]
                 , ('a, 'b, 'c) t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> slots_per_epoch:
             (   ( [< `Read | `Set_and_create ]
                 , ('d, 'e, 'f) t
                 , 'd )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> slots_per_sub_window:
             (   ( [< `Read | `Set_and_create ]
                 , ('g, 'h, 'i) t
                 , 'g )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> delta:
             (   ( [< `Read | `Set_and_create ]
                 , ('j, 'k, 'l) t
                 , 'k )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> genesis_state_timestamp:
             (   ( [< `Read | `Set_and_create ]
                 , ('m, 'n, 'o) t
                 , 'o )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val exists :
           k:
             (   ( [< `Read | `Set_and_create ]
                 , ('a, 'b, 'c) t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> slots_per_epoch:
             (   ( [< `Read | `Set_and_create ]
                 , ('d, 'e, 'f) t
                 , 'd )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> slots_per_sub_window:
             (   ( [< `Read | `Set_and_create ]
                 , ('g, 'h, 'i) t
                 , 'g )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> delta:
             (   ( [< `Read | `Set_and_create ]
                 , ('j, 'k, 'l) t
                 , 'k )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> genesis_state_timestamp:
             (   ( [< `Read | `Set_and_create ]
                 , ('m, 'n, 'o) t
                 , 'o )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val to_list :
           k:
             (   ( [< `Read | `Set_and_create ]
                 , ('a, 'b, 'c) t
                 , 'a )
                 Fieldslib.Field.t_with_perm
              -> 'd)
        -> slots_per_epoch:
             (   ( [< `Read | `Set_and_create ]
                 , ('e, 'f, 'g) t
                 , 'e )
                 Fieldslib.Field.t_with_perm
              -> 'd)
        -> slots_per_sub_window:
             (   ( [< `Read | `Set_and_create ]
                 , ('h, 'i, 'j) t
                 , 'h )
                 Fieldslib.Field.t_with_perm
              -> 'd)
        -> delta:
             (   ( [< `Read | `Set_and_create ]
                 , ('k, 'l, 'm) t
                 , 'l )
                 Fieldslib.Field.t_with_perm
              -> 'd)
        -> genesis_state_timestamp:
             (   ( [< `Read | `Set_and_create ]
                 , ('n, 'o, 'p) t
                 , 'p )
                 Fieldslib.Field.t_with_perm
              -> 'd)
        -> 'd list

      module Direct : sig
        val iter :
             ('a, 'b, 'c) t
          -> k:
               (   ( [< `Read | `Set_and_create ]
                   , ('d, 'e, 'f) t
                   , 'd )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> unit)
          -> slots_per_epoch:
               (   ( [< `Read | `Set_and_create ]
                   , ('g, 'h, 'i) t
                   , 'g )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> unit)
          -> slots_per_sub_window:
               (   ( [< `Read | `Set_and_create ]
                   , ('j, 'k, 'l) t
                   , 'j )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> unit)
          -> delta:
               (   ( [< `Read | `Set_and_create ]
                   , ('m, 'n, 'o) t
                   , 'n )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'b
                -> unit)
          -> genesis_state_timestamp:
               (   ( [< `Read | `Set_and_create ]
                   , ('p, 'q, 'r) t
                   , 'r )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'c
                -> 's)
          -> 's

        val fold :
             ('a, 'b, 'c) t
          -> init:'d
          -> k:
               (   'd
                -> ( [< `Read | `Set_and_create ]
                   , ('e, 'f, 'g) t
                   , 'e )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> 'h)
          -> slots_per_epoch:
               (   'h
                -> ( [< `Read | `Set_and_create ]
                   , ('i, 'j, 'k) t
                   , 'i )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> 'l)
          -> slots_per_sub_window:
               (   'l
                -> ( [< `Read | `Set_and_create ]
                   , ('m, 'n, 'o) t
                   , 'm )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> 'p)
          -> delta:
               (   'p
                -> ( [< `Read | `Set_and_create ]
                   , ('q, 'r, 's) t
                   , 'r )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'b
                -> 't)
          -> genesis_state_timestamp:
               (   't
                -> ( [< `Read | `Set_and_create ]
                   , ('u, 'v, 'w) t
                   , 'w )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'c
                -> 'x)
          -> 'x

        val for_all :
             ('a, 'b, 'c) t
          -> k:
               (   ( [< `Read | `Set_and_create ]
                   , ('d, 'e, 'f) t
                   , 'd )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> bool)
          -> slots_per_epoch:
               (   ( [< `Read | `Set_and_create ]
                   , ('g, 'h, 'i) t
                   , 'g )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> bool)
          -> slots_per_sub_window:
               (   ( [< `Read | `Set_and_create ]
                   , ('j, 'k, 'l) t
                   , 'j )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> bool)
          -> delta:
               (   ( [< `Read | `Set_and_create ]
                   , ('m, 'n, 'o) t
                   , 'n )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'b
                -> bool)
          -> genesis_state_timestamp:
               (   ( [< `Read | `Set_and_create ]
                   , ('p, 'q, 'r) t
                   , 'r )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'c
                -> bool)
          -> bool

        val exists :
             ('a, 'b, 'c) t
          -> k:
               (   ( [< `Read | `Set_and_create ]
                   , ('d, 'e, 'f) t
                   , 'd )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> bool)
          -> slots_per_epoch:
               (   ( [< `Read | `Set_and_create ]
                   , ('g, 'h, 'i) t
                   , 'g )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> bool)
          -> slots_per_sub_window:
               (   ( [< `Read | `Set_and_create ]
                   , ('j, 'k, 'l) t
                   , 'j )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> bool)
          -> delta:
               (   ( [< `Read | `Set_and_create ]
                   , ('m, 'n, 'o) t
                   , 'n )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'b
                -> bool)
          -> genesis_state_timestamp:
               (   ( [< `Read | `Set_and_create ]
                   , ('p, 'q, 'r) t
                   , 'r )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'c
                -> bool)
          -> bool

        val to_list :
             ('a, 'b, 'c) t
          -> k:
               (   ( [< `Read | `Set_and_create ]
                   , ('d, 'e, 'f) t
                   , 'd )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> 'g)
          -> slots_per_epoch:
               (   ( [< `Read | `Set_and_create ]
                   , ('h, 'i, 'j) t
                   , 'h )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> 'g)
          -> slots_per_sub_window:
               (   ( [< `Read | `Set_and_create ]
                   , ('k, 'l, 'm) t
                   , 'k )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> 'g)
          -> delta:
               (   ( [< `Read | `Set_and_create ]
                   , ('n, 'o, 'p) t
                   , 'o )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'b
                -> 'g)
          -> genesis_state_timestamp:
               (   ( [< `Read | `Set_and_create ]
                   , ('q, 'r, 's) t
                   , 's )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'c
                -> 'g)
          -> 'g list

        val map :
             ('a, 'b, 'c) t
          -> k:
               (   ( [< `Read | `Set_and_create ]
                   , ('d, 'e, 'f) t
                   , 'd )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> 'g)
          -> slots_per_epoch:
               (   ( [< `Read | `Set_and_create ]
                   , ('h, 'i, 'j) t
                   , 'h )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> 'g)
          -> slots_per_sub_window:
               (   ( [< `Read | `Set_and_create ]
                   , ('k, 'l, 'm) t
                   , 'k )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'a
                -> 'g)
          -> delta:
               (   ( [< `Read | `Set_and_create ]
                   , ('n, 'o, 'p) t
                   , 'o )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'b
                -> 'q)
          -> genesis_state_timestamp:
               (   ( [< `Read | `Set_and_create ]
                   , ('r, 's, 't) t
                   , 't )
                   Fieldslib.Field.t_with_perm
                -> ('a, 'b, 'c) t
                -> 'c
                -> 'u)
          -> ('g, 'q, 'u) t

        val set_all_mutable_fields : 'a -> unit
      end
    end
  end

  module Stable : sig
    module V1 : sig
      type t = (int, int, Core_kernel.Int64.t) Poly.t

      val compare : t -> t -> Ppx_deriving_runtime.int

      val version : int

      val __versioned__ : unit

      val equal : t -> t -> bool

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

      val to_latest : 'a -> 'a

      val to_yojson :
           t
        -> [> `Assoc of
              ( string
              * [> `Int of int | `String of Core_kernel__.Import.string ] )
              list ]

      val of_yojson :
           [> `Assoc of
              ( string
              * [> `Int of 'a | `String of Core_kernel__.Import.string option ]
              )
              list ]
        -> (('a, 'a, Core_kernel.Int64.t) Poly.t, string) Core_kernel._result

      val t_of_sexp : 'a -> 'b

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

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

    module Tests : sig end
  end

  type t = Stable.Latest.t

  val compare : t -> t -> Ppx_deriving_runtime.int

  val equal : t -> t -> bool

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val to_yojson :
       t
    -> [> `Assoc of
          (string * [> `Int of int | `String of Core_kernel__.Import.string ])
          list ]
end

module T : sig
  type t =
    { protocol : Protocol.t; txpool_max_size : int; num_accounts : int option }

  val to_yojson : t -> Yojson.Safe.t

  val bin_shape_t : Core_kernel.Bin_prot.Shape.t

  val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

  val bin_read_t : t Core_kernel.Bin_prot.Read.reader

  val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

  val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

  val bin_write_t : t Core_kernel.Bin_prot.Write.writer

  val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

  val bin_t : t Core_kernel.Bin_prot.Type_class.t

  val hash : t -> string
end

type t = T.t =
  { protocol : Protocol.t; txpool_max_size : int; num_accounts : int option }

val to_yojson : t -> Yojson.Safe.t

val bin_shape_t : Core_kernel.Bin_prot.Shape.t

val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

val bin_read_t : t Core_kernel.Bin_prot.Read.reader

val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

val bin_write_t : t Core_kernel.Bin_prot.Write.writer

val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

val bin_t : t Core_kernel.Bin_prot.Type_class.t

val hash : t -> string

val genesis_state_timestamp_string : string

val k : int

val slots_per_epoch : int

val slots_per_sub_window : int

val delta : int

val pool_max_size : int

val compiled : t

val for_unit_tests : t
