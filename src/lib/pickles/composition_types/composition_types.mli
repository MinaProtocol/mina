module Scalar_challenge = Pickles_types.Scalar_challenge
module Bulletproof_challenge = Bulletproof_challenge
module Index = Index
module Digest = Digest
module Spec = Spec

val index_to_field_elements :
     'a Pickles_types.Plonk_verification_key_evals.t
  -> g:('a -> 'b Core_kernel.Array.t)
  -> 'b Core_kernel.Array.t

module Dlog_based : sig
  module Proof_state : sig
    module Deferred_values : sig
      module Plonk : sig
        module Minimal : sig
          module Stable : sig
            module V1 : sig
              type ('challenge, 'scalar_challenge) t =
                { alpha : 'scalar_challenge
                ; beta : 'challenge
                ; gamma : 'challenge
                ; zeta : 'scalar_challenge
                }

              val to_yojson :
                   ('challenge -> Yojson.Safe.t)
                -> ('scalar_challenge -> Yojson.Safe.t)
                -> ('challenge, 'scalar_challenge) t
                -> Yojson.Safe.t

              val of_yojson :
                   (   Yojson.Safe.t
                    -> 'challenge Ppx_deriving_yojson_runtime.error_or)
                -> (   Yojson.Safe.t
                    -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
                -> Yojson.Safe.t
                -> ('challenge, 'scalar_challenge) t
                   Ppx_deriving_yojson_runtime.error_or

              val version : int

              val __versioned__ : unit

              val t_of_sexp :
                   (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
                -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
                -> Ppx_sexp_conv_lib.Sexp.t
                -> ('challenge, 'scalar_challenge) t

              val sexp_of_t :
                   ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
                -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
                -> ('challenge, 'scalar_challenge) t
                -> Ppx_sexp_conv_lib.Sexp.t

              val compare :
                   ('challenge -> 'challenge -> int)
                -> ('scalar_challenge -> 'scalar_challenge -> int)
                -> ('challenge, 'scalar_challenge) t
                -> ('challenge, 'scalar_challenge) t
                -> int

              val to_hlist :
                   ('challenge, 'scalar_challenge) t
                -> ( unit
                   ,    'scalar_challenge
                     -> 'challenge
                     -> 'challenge
                     -> 'scalar_challenge
                     -> unit )
                   H_list.t

              val of_hlist :
                   ( unit
                   ,    'scalar_challenge
                     -> 'challenge
                     -> 'challenge
                     -> 'scalar_challenge
                     -> unit )
                   H_list.t
                -> ('challenge, 'scalar_challenge) t

              val hash_fold_t :
                   (   Ppx_hash_lib.Std.Hash.state
                    -> 'challenge
                    -> Ppx_hash_lib.Std.Hash.state)
                -> (   Ppx_hash_lib.Std.Hash.state
                    -> 'scalar_challenge
                    -> Ppx_hash_lib.Std.Hash.state)
                -> Ppx_hash_lib.Std.Hash.state
                -> ('challenge, 'scalar_challenge) t
                -> Ppx_hash_lib.Std.Hash.state

              val equal :
                   ('challenge -> 'challenge -> bool)
                -> ('scalar_challenge -> 'scalar_challenge -> bool)
                -> ('challenge, 'scalar_challenge) t
                -> ('challenge, 'scalar_challenge) t
                -> bool

              val to_latest : 'a -> 'a

              module With_version : sig
                type ('challenge, 'scalar_challenge) typ =
                  ('challenge, 'scalar_challenge) t

                val bin_shape_typ :
                     Core_kernel.Bin_prot.Shape.t
                  -> Core_kernel.Bin_prot.Shape.t
                  -> Core_kernel.Bin_prot.Shape.t

                val bin_size_typ :
                     'challenge Core_kernel.Bin_prot.Size.sizer
                  -> 'scalar_challenge Core_kernel.Bin_prot.Size.sizer
                  -> ('challenge, 'scalar_challenge) typ
                     Core_kernel.Bin_prot.Size.sizer

                val bin_write_typ :
                     'challenge Core_kernel.Bin_prot.Write.writer
                  -> 'scalar_challenge Core_kernel.Bin_prot.Write.writer
                  -> ('challenge, 'scalar_challenge) typ
                     Core_kernel.Bin_prot.Write.writer

                val bin_writer_typ :
                     'a Core_kernel.Bin_prot.Type_class.writer
                  -> 'b Core_kernel.Bin_prot.Type_class.writer
                  -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.writer

                val __bin_read_typ__ :
                     'challenge Core_kernel.Bin_prot.Read.reader
                  -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
                  -> (int -> ('challenge, 'scalar_challenge) typ)
                     Core_kernel.Bin_prot.Read.reader

                val bin_read_typ :
                     'challenge Core_kernel.Bin_prot.Read.reader
                  -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
                  -> ('challenge, 'scalar_challenge) typ
                     Core_kernel.Bin_prot.Read.reader

                val bin_reader_typ :
                     'a Core_kernel.Bin_prot.Type_class.reader
                  -> 'b Core_kernel.Bin_prot.Type_class.reader
                  -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.reader

                val bin_typ :
                     'a Core_kernel.Bin_prot.Type_class.t
                  -> 'b Core_kernel.Bin_prot.Type_class.t
                  -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.t

                type ('challenge, 'scalar_challenge) t =
                  { version : int; t : ('challenge, 'scalar_challenge) typ }

                val bin_shape_t :
                     Core_kernel.Bin_prot.Shape.t
                  -> Core_kernel.Bin_prot.Shape.t
                  -> Core_kernel.Bin_prot.Shape.t

                val bin_size_t :
                     'challenge Core_kernel.Bin_prot.Size.sizer
                  -> 'scalar_challenge Core_kernel.Bin_prot.Size.sizer
                  -> ('challenge, 'scalar_challenge) t
                     Core_kernel.Bin_prot.Size.sizer

                val bin_write_t :
                     'challenge Core_kernel.Bin_prot.Write.writer
                  -> 'scalar_challenge Core_kernel.Bin_prot.Write.writer
                  -> ('challenge, 'scalar_challenge) t
                     Core_kernel.Bin_prot.Write.writer

                val bin_writer_t :
                     'a Core_kernel.Bin_prot.Type_class.writer
                  -> 'b Core_kernel.Bin_prot.Type_class.writer
                  -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

                val __bin_read_t__ :
                     'challenge Core_kernel.Bin_prot.Read.reader
                  -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
                  -> (int -> ('challenge, 'scalar_challenge) t)
                     Core_kernel.Bin_prot.Read.reader

                val bin_read_t :
                     'challenge Core_kernel.Bin_prot.Read.reader
                  -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
                  -> ('challenge, 'scalar_challenge) t
                     Core_kernel.Bin_prot.Read.reader

                val bin_reader_t :
                     'a Core_kernel.Bin_prot.Type_class.reader
                  -> 'b Core_kernel.Bin_prot.Type_class.reader
                  -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.reader

                val bin_t :
                     'a Core_kernel.Bin_prot.Type_class.t
                  -> 'b Core_kernel.Bin_prot.Type_class.t
                  -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.t

                val create : ('a, 'b) typ -> ('a, 'b) t
              end

              val bin_read_t :
                   'a Core_kernel.Bin_prot.Read.reader
                -> 'b Core_kernel.Bin_prot.Read.reader
                -> Bin_prot.Common.buf
                -> pos_ref:Bin_prot.Common.pos_ref
                -> ('a, 'b) t

              val __bin_read_t__ :
                   'a Core_kernel.Bin_prot.Read.reader
                -> 'b Core_kernel.Bin_prot.Read.reader
                -> Bin_prot.Common.buf
                -> pos_ref:Bin_prot.Common.pos_ref
                -> int
                -> ('a, 'b) t

              val bin_size_t :
                   'a Core_kernel.Bin_prot.Size.sizer
                -> 'b Core_kernel.Bin_prot.Size.sizer
                -> ('a, 'b) t
                -> int

              val bin_write_t :
                   'a Core_kernel.Bin_prot.Write.writer
                -> 'b Core_kernel.Bin_prot.Write.writer
                -> Bin_prot.Common.buf
                -> pos:Bin_prot.Common.pos
                -> ('a, 'b) t
                -> Bin_prot.Common.pos

              val bin_shape_t :
                   Core_kernel.Bin_prot.Shape.t
                -> Core_kernel.Bin_prot.Shape.t
                -> Core_kernel.Bin_prot.Shape.t

              val bin_reader_t :
                   'a Core_kernel.Bin_prot.Type_class.reader
                -> 'b Core_kernel.Bin_prot.Type_class.reader
                -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.reader

              val bin_writer_t :
                   'a Core_kernel.Bin_prot.Type_class.writer
                -> 'b Core_kernel.Bin_prot.Type_class.writer
                -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

              val bin_t :
                   'a Core_kernel.Bin_prot.Type_class.t
                -> 'b Core_kernel.Bin_prot.Type_class.t
                -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.t

              val __ :
                (   'a Core_kernel.Bin_prot.Read.reader
                 -> 'b Core_kernel.Bin_prot.Read.reader
                 -> Bin_prot.Common.buf
                 -> pos_ref:Bin_prot.Common.pos_ref
                 -> ('a, 'b) t)
                * (   'c Core_kernel.Bin_prot.Read.reader
                   -> 'd Core_kernel.Bin_prot.Read.reader
                   -> Bin_prot.Common.buf
                   -> pos_ref:Bin_prot.Common.pos_ref
                   -> int
                   -> ('c, 'd) t)
                * (   'e Core_kernel.Bin_prot.Size.sizer
                   -> 'f Core_kernel.Bin_prot.Size.sizer
                   -> ('e, 'f) t
                   -> int)
                * (   'g Core_kernel.Bin_prot.Write.writer
                   -> 'h Core_kernel.Bin_prot.Write.writer
                   -> Bin_prot.Common.buf
                   -> pos:Bin_prot.Common.pos
                   -> ('g, 'h) t
                   -> Bin_prot.Common.pos)
                * (   Core_kernel.Bin_prot.Shape.t
                   -> Core_kernel.Bin_prot.Shape.t
                   -> Core_kernel.Bin_prot.Shape.t)
                * (   'i Core_kernel.Bin_prot.Type_class.reader
                   -> 'j Core_kernel.Bin_prot.Type_class.reader
                   -> ('i, 'j) t Core_kernel.Bin_prot.Type_class.reader)
                * (   'k Core_kernel.Bin_prot.Type_class.writer
                   -> 'l Core_kernel.Bin_prot.Type_class.writer
                   -> ('k, 'l) t Core_kernel.Bin_prot.Type_class.writer)
                * (   'm Core_kernel.Bin_prot.Type_class.t
                   -> 'n Core_kernel.Bin_prot.Type_class.t
                   -> ('m, 'n) t Core_kernel.Bin_prot.Type_class.t)
            end

            module Latest = V1
          end

          type ('challenge, 'scalar_challenge) t =
                ('challenge, 'scalar_challenge) Stable.V1.t =
            { alpha : 'scalar_challenge
            ; beta : 'challenge
            ; gamma : 'challenge
            ; zeta : 'scalar_challenge
            }

          val to_yojson :
               ('challenge -> Yojson.Safe.t)
            -> ('scalar_challenge -> Yojson.Safe.t)
            -> ('challenge, 'scalar_challenge) t
            -> Yojson.Safe.t

          val of_yojson :
               (Yojson.Safe.t -> 'challenge Ppx_deriving_yojson_runtime.error_or)
            -> (   Yojson.Safe.t
                -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
            -> Yojson.Safe.t
            -> ('challenge, 'scalar_challenge) t
               Ppx_deriving_yojson_runtime.error_or

          val t_of_sexp :
               (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
            -> Ppx_sexp_conv_lib.Sexp.t
            -> ('challenge, 'scalar_challenge) t

          val sexp_of_t :
               ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('challenge, 'scalar_challenge) t
            -> Ppx_sexp_conv_lib.Sexp.t

          val compare :
               ('challenge -> 'challenge -> int)
            -> ('scalar_challenge -> 'scalar_challenge -> int)
            -> ('challenge, 'scalar_challenge) t
            -> ('challenge, 'scalar_challenge) t
            -> int

          val to_hlist :
               ('challenge, 'scalar_challenge) t
            -> ( unit
               ,    'scalar_challenge
                 -> 'challenge
                 -> 'challenge
                 -> 'scalar_challenge
                 -> unit )
               H_list.t

          val of_hlist :
               ( unit
               ,    'scalar_challenge
                 -> 'challenge
                 -> 'challenge
                 -> 'scalar_challenge
                 -> unit )
               H_list.t
            -> ('challenge, 'scalar_challenge) t

          val hash_fold_t :
               (   Ppx_hash_lib.Std.Hash.state
                -> 'challenge
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'scalar_challenge
                -> Ppx_hash_lib.Std.Hash.state)
            -> Ppx_hash_lib.Std.Hash.state
            -> ('challenge, 'scalar_challenge) t
            -> Ppx_hash_lib.Std.Hash.state

          val equal :
               ('challenge -> 'challenge -> bool)
            -> ('scalar_challenge -> 'scalar_challenge -> bool)
            -> ('challenge, 'scalar_challenge) t
            -> ('challenge, 'scalar_challenge) t
            -> bool
        end

        module In_circuit : sig
          type ('challenge, 'scalar_challenge, 'fp) t =
            { alpha : 'scalar_challenge
            ; beta : 'challenge
            ; gamma : 'challenge
            ; zeta : 'scalar_challenge
            ; perm0 : 'fp
            ; perm1 : 'fp
            ; gnrc_l : 'fp
            ; gnrc_r : 'fp
            ; gnrc_o : 'fp
            ; psdn0 : 'fp
            ; ecad0 : 'fp
            ; vbmul0 : 'fp
            ; vbmul1 : 'fp
            ; endomul0 : 'fp
            ; endomul1 : 'fp
            ; endomul2 : 'fp
            }

          val to_yojson :
               ('challenge -> Yojson.Safe.t)
            -> ('scalar_challenge -> Yojson.Safe.t)
            -> ('fp -> Yojson.Safe.t)
            -> ('challenge, 'scalar_challenge, 'fp) t
            -> Yojson.Safe.t

          val of_yojson :
               (Yojson.Safe.t -> 'challenge Ppx_deriving_yojson_runtime.error_or)
            -> (   Yojson.Safe.t
                -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
            -> (Yojson.Safe.t -> 'fp Ppx_deriving_yojson_runtime.error_or)
            -> Yojson.Safe.t
            -> ('challenge, 'scalar_challenge, 'fp) t
               Ppx_deriving_yojson_runtime.error_or

          val t_of_sexp :
               (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'fp)
            -> Ppx_sexp_conv_lib.Sexp.t
            -> ('challenge, 'scalar_challenge, 'fp) t

          val sexp_of_t :
               ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('fp -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('challenge, 'scalar_challenge, 'fp) t
            -> Ppx_sexp_conv_lib.Sexp.t

          val compare :
               ('challenge -> 'challenge -> int)
            -> ('scalar_challenge -> 'scalar_challenge -> int)
            -> ('fp -> 'fp -> int)
            -> ('challenge, 'scalar_challenge, 'fp) t
            -> ('challenge, 'scalar_challenge, 'fp) t
            -> int

          val to_hlist :
               ('challenge, 'scalar_challenge, 'fp) t
            -> ( unit
               ,    'scalar_challenge
                 -> 'challenge
                 -> 'challenge
                 -> 'scalar_challenge
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> unit )
               H_list.t

          val of_hlist :
               ( unit
               ,    'scalar_challenge
                 -> 'challenge
                 -> 'challenge
                 -> 'scalar_challenge
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> 'fp
                 -> unit )
               H_list.t
            -> ('challenge, 'scalar_challenge, 'fp) t

          val hash_fold_t :
               (   Ppx_hash_lib.Std.Hash.state
                -> 'challenge
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'scalar_challenge
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'fp
                -> Ppx_hash_lib.Std.Hash.state)
            -> Ppx_hash_lib.Std.Hash.state
            -> ('challenge, 'scalar_challenge, 'fp) t
            -> Ppx_hash_lib.Std.Hash.state

          val equal :
               ('challenge -> 'challenge -> bool)
            -> ('scalar_challenge -> 'scalar_challenge -> bool)
            -> ('fp -> 'fp -> bool)
            -> ('challenge, 'scalar_challenge, 'fp) t
            -> ('challenge, 'scalar_challenge, 'fp) t
            -> bool

          val endomul2 : ('a, 'b, 'c) t -> 'c

          val endomul1 : ('a, 'b, 'c) t -> 'c

          val endomul0 : ('a, 'b, 'c) t -> 'c

          val vbmul1 : ('a, 'b, 'c) t -> 'c

          val vbmul0 : ('a, 'b, 'c) t -> 'c

          val ecad0 : ('a, 'b, 'c) t -> 'c

          val psdn0 : ('a, 'b, 'c) t -> 'c

          val gnrc_o : ('a, 'b, 'c) t -> 'c

          val gnrc_r : ('a, 'b, 'c) t -> 'c

          val gnrc_l : ('a, 'b, 'c) t -> 'c

          val perm1 : ('a, 'b, 'c) t -> 'c

          val perm0 : ('a, 'b, 'c) t -> 'c

          val zeta : ('a, 'b, 'c) t -> 'b

          val gamma : ('a, 'b, 'c) t -> 'a

          val beta : ('a, 'b, 'c) t -> 'a

          val alpha : ('a, 'b, 'c) t -> 'b

          module Fields : sig
            val names : string list

            val endomul2 :
              ( [< `Read | `Set_and_create ]
              , ('a, 'b, 'fp) t
              , 'fp )
              Fieldslib.Field.t_with_perm

            val endomul1 :
              ( [< `Read | `Set_and_create ]
              , ('a, 'b, 'fp) t
              , 'fp )
              Fieldslib.Field.t_with_perm

            val endomul0 :
              ( [< `Read | `Set_and_create ]
              , ('a, 'b, 'fp) t
              , 'fp )
              Fieldslib.Field.t_with_perm

            val vbmul1 :
              ( [< `Read | `Set_and_create ]
              , ('a, 'b, 'fp) t
              , 'fp )
              Fieldslib.Field.t_with_perm

            val vbmul0 :
              ( [< `Read | `Set_and_create ]
              , ('a, 'b, 'fp) t
              , 'fp )
              Fieldslib.Field.t_with_perm

            val ecad0 :
              ( [< `Read | `Set_and_create ]
              , ('a, 'b, 'fp) t
              , 'fp )
              Fieldslib.Field.t_with_perm

            val psdn0 :
              ( [< `Read | `Set_and_create ]
              , ('a, 'b, 'fp) t
              , 'fp )
              Fieldslib.Field.t_with_perm

            val gnrc_o :
              ( [< `Read | `Set_and_create ]
              , ('a, 'b, 'fp) t
              , 'fp )
              Fieldslib.Field.t_with_perm

            val gnrc_r :
              ( [< `Read | `Set_and_create ]
              , ('a, 'b, 'fp) t
              , 'fp )
              Fieldslib.Field.t_with_perm

            val gnrc_l :
              ( [< `Read | `Set_and_create ]
              , ('a, 'b, 'fp) t
              , 'fp )
              Fieldslib.Field.t_with_perm

            val perm1 :
              ( [< `Read | `Set_and_create ]
              , ('a, 'b, 'fp) t
              , 'fp )
              Fieldslib.Field.t_with_perm

            val perm0 :
              ( [< `Read | `Set_and_create ]
              , ('a, 'b, 'fp) t
              , 'fp )
              Fieldslib.Field.t_with_perm

            val zeta :
              ( [< `Read | `Set_and_create ]
              , ('a, 'scalar_challenge, 'b) t
              , 'scalar_challenge )
              Fieldslib.Field.t_with_perm

            val gamma :
              ( [< `Read | `Set_and_create ]
              , ('challenge, 'a, 'b) t
              , 'challenge )
              Fieldslib.Field.t_with_perm

            val beta :
              ( [< `Read | `Set_and_create ]
              , ('challenge, 'a, 'b) t
              , 'challenge )
              Fieldslib.Field.t_with_perm

            val alpha :
              ( [< `Read | `Set_and_create ]
              , ('a, 'scalar_challenge, 'b) t
              , 'scalar_challenge )
              Fieldslib.Field.t_with_perm

            val make_creator :
                 alpha:
                   (   ( [< `Read | `Set_and_create ]
                       , ('a, 'b, 'c) t
                       , 'b )
                       Fieldslib.Field.t_with_perm
                    -> 'd
                    -> ('e -> 'f) * 'g)
              -> beta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('h, 'i, 'j) t
                       , 'h )
                       Fieldslib.Field.t_with_perm
                    -> 'g
                    -> ('e -> 'k) * 'l)
              -> gamma:
                   (   ( [< `Read | `Set_and_create ]
                       , ('m, 'n, 'o) t
                       , 'm )
                       Fieldslib.Field.t_with_perm
                    -> 'l
                    -> ('e -> 'k) * 'p)
              -> zeta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('q, 'r, 's) t
                       , 'r )
                       Fieldslib.Field.t_with_perm
                    -> 'p
                    -> ('e -> 'f) * 't)
              -> perm0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('u, 'v, 'w) t
                       , 'w )
                       Fieldslib.Field.t_with_perm
                    -> 't
                    -> ('e -> 'x) * 'y)
              -> perm1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('z, 'a1, 'b1) t
                       , 'b1 )
                       Fieldslib.Field.t_with_perm
                    -> 'y
                    -> ('e -> 'x) * 'c1)
              -> gnrc_l:
                   (   ( [< `Read | `Set_and_create ]
                       , ('d1, 'e1, 'f1) t
                       , 'f1 )
                       Fieldslib.Field.t_with_perm
                    -> 'c1
                    -> ('e -> 'x) * 'g1)
              -> gnrc_r:
                   (   ( [< `Read | `Set_and_create ]
                       , ('h1, 'i1, 'j1) t
                       , 'j1 )
                       Fieldslib.Field.t_with_perm
                    -> 'g1
                    -> ('e -> 'x) * 'k1)
              -> gnrc_o:
                   (   ( [< `Read | `Set_and_create ]
                       , ('l1, 'm1, 'n1) t
                       , 'n1 )
                       Fieldslib.Field.t_with_perm
                    -> 'k1
                    -> ('e -> 'x) * 'o1)
              -> psdn0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('p1, 'q1, 'r1) t
                       , 'r1 )
                       Fieldslib.Field.t_with_perm
                    -> 'o1
                    -> ('e -> 'x) * 's1)
              -> ecad0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('t1, 'u1, 'v1) t
                       , 'v1 )
                       Fieldslib.Field.t_with_perm
                    -> 's1
                    -> ('e -> 'x) * 'w1)
              -> vbmul0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('x1, 'y1, 'z1) t
                       , 'z1 )
                       Fieldslib.Field.t_with_perm
                    -> 'w1
                    -> ('e -> 'x) * 'a2)
              -> vbmul1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('b2, 'c2, 'd2) t
                       , 'd2 )
                       Fieldslib.Field.t_with_perm
                    -> 'a2
                    -> ('e -> 'x) * 'e2)
              -> endomul0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('f2, 'g2, 'h2) t
                       , 'h2 )
                       Fieldslib.Field.t_with_perm
                    -> 'e2
                    -> ('e -> 'x) * 'i2)
              -> endomul1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('j2, 'k2, 'l2) t
                       , 'l2 )
                       Fieldslib.Field.t_with_perm
                    -> 'i2
                    -> ('e -> 'x) * 'm2)
              -> endomul2:
                   (   ( [< `Read | `Set_and_create ]
                       , ('n2, 'o2, 'p2) t
                       , 'p2 )
                       Fieldslib.Field.t_with_perm
                    -> 'm2
                    -> ('e -> 'x) * 'q2)
              -> 'd
              -> ('e -> ('k, 'f, 'x) t) * 'q2

            val create :
                 alpha:'a
              -> beta:'b
              -> gamma:'b
              -> zeta:'a
              -> perm0:'c
              -> perm1:'c
              -> gnrc_l:'c
              -> gnrc_r:'c
              -> gnrc_o:'c
              -> psdn0:'c
              -> ecad0:'c
              -> vbmul0:'c
              -> vbmul1:'c
              -> endomul0:'c
              -> endomul1:'c
              -> endomul2:'c
              -> ('b, 'a, 'c) t

            val map :
                 alpha:
                   (   ( [< `Read | `Set_and_create ]
                       , ('a, 'b, 'c) t
                       , 'b )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> beta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('e, 'f, 'g) t
                       , 'e )
                       Fieldslib.Field.t_with_perm
                    -> 'h)
              -> gamma:
                   (   ( [< `Read | `Set_and_create ]
                       , ('i, 'j, 'k) t
                       , 'i )
                       Fieldslib.Field.t_with_perm
                    -> 'h)
              -> zeta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('l, 'm, 'n) t
                       , 'm )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> perm0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('o, 'p, 'q) t
                       , 'q )
                       Fieldslib.Field.t_with_perm
                    -> 'r)
              -> perm1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('s, 't, 'u) t
                       , 'u )
                       Fieldslib.Field.t_with_perm
                    -> 'r)
              -> gnrc_l:
                   (   ( [< `Read | `Set_and_create ]
                       , ('v, 'w, 'x) t
                       , 'x )
                       Fieldslib.Field.t_with_perm
                    -> 'r)
              -> gnrc_r:
                   (   ( [< `Read | `Set_and_create ]
                       , ('y, 'z, 'a1) t
                       , 'a1 )
                       Fieldslib.Field.t_with_perm
                    -> 'r)
              -> gnrc_o:
                   (   ( [< `Read | `Set_and_create ]
                       , ('b1, 'c1, 'd1) t
                       , 'd1 )
                       Fieldslib.Field.t_with_perm
                    -> 'r)
              -> psdn0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('e1, 'f1, 'g1) t
                       , 'g1 )
                       Fieldslib.Field.t_with_perm
                    -> 'r)
              -> ecad0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('h1, 'i1, 'j1) t
                       , 'j1 )
                       Fieldslib.Field.t_with_perm
                    -> 'r)
              -> vbmul0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('k1, 'l1, 'm1) t
                       , 'm1 )
                       Fieldslib.Field.t_with_perm
                    -> 'r)
              -> vbmul1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('n1, 'o1, 'p1) t
                       , 'p1 )
                       Fieldslib.Field.t_with_perm
                    -> 'r)
              -> endomul0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('q1, 'r1, 's1) t
                       , 's1 )
                       Fieldslib.Field.t_with_perm
                    -> 'r)
              -> endomul1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('t1, 'u1, 'v1) t
                       , 'v1 )
                       Fieldslib.Field.t_with_perm
                    -> 'r)
              -> endomul2:
                   (   ( [< `Read | `Set_and_create ]
                       , ('w1, 'x1, 'y1) t
                       , 'y1 )
                       Fieldslib.Field.t_with_perm
                    -> 'r)
              -> ('h, 'd, 'r) t

            val iter :
                 alpha:
                   (   ( [< `Read | `Set_and_create ]
                       , ('a, 'b, 'c) t
                       , 'b )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> beta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('d, 'e, 'f) t
                       , 'd )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> gamma:
                   (   ( [< `Read | `Set_and_create ]
                       , ('g, 'h, 'i) t
                       , 'g )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> zeta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('j, 'k, 'l) t
                       , 'k )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> perm0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('m, 'n, 'o) t
                       , 'o )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> perm1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('p, 'q, 'r) t
                       , 'r )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> gnrc_l:
                   (   ( [< `Read | `Set_and_create ]
                       , ('s, 't, 'u) t
                       , 'u )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> gnrc_r:
                   (   ( [< `Read | `Set_and_create ]
                       , ('v, 'w, 'x) t
                       , 'x )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> gnrc_o:
                   (   ( [< `Read | `Set_and_create ]
                       , ('y, 'z, 'a1) t
                       , 'a1 )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> psdn0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('b1, 'c1, 'd1) t
                       , 'd1 )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> ecad0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('e1, 'f1, 'g1) t
                       , 'g1 )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> vbmul0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('h1, 'i1, 'j1) t
                       , 'j1 )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> vbmul1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('k1, 'l1, 'm1) t
                       , 'm1 )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> endomul0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('n1, 'o1, 'p1) t
                       , 'p1 )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> endomul1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('q1, 'r1, 's1) t
                       , 's1 )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> endomul2:
                   (   ( [< `Read | `Set_and_create ]
                       , ('t1, 'u1, 'v1) t
                       , 'v1 )
                       Fieldslib.Field.t_with_perm
                    -> unit)
              -> unit

            val fold :
                 init:'a
              -> alpha:
                   (   'a
                    -> ( [< `Read | `Set_and_create ]
                       , ('b, 'c, 'd) t
                       , 'c )
                       Fieldslib.Field.t_with_perm
                    -> 'e)
              -> beta:
                   (   'e
                    -> ( [< `Read | `Set_and_create ]
                       , ('f, 'g, 'h) t
                       , 'f )
                       Fieldslib.Field.t_with_perm
                    -> 'i)
              -> gamma:
                   (   'i
                    -> ( [< `Read | `Set_and_create ]
                       , ('j, 'k, 'l) t
                       , 'j )
                       Fieldslib.Field.t_with_perm
                    -> 'm)
              -> zeta:
                   (   'm
                    -> ( [< `Read | `Set_and_create ]
                       , ('n, 'o, 'p) t
                       , 'o )
                       Fieldslib.Field.t_with_perm
                    -> 'q)
              -> perm0:
                   (   'q
                    -> ( [< `Read | `Set_and_create ]
                       , ('r, 's, 't) t
                       , 't )
                       Fieldslib.Field.t_with_perm
                    -> 'u)
              -> perm1:
                   (   'u
                    -> ( [< `Read | `Set_and_create ]
                       , ('v, 'w, 'x) t
                       , 'x )
                       Fieldslib.Field.t_with_perm
                    -> 'y)
              -> gnrc_l:
                   (   'y
                    -> ( [< `Read | `Set_and_create ]
                       , ('z, 'a1, 'b1) t
                       , 'b1 )
                       Fieldslib.Field.t_with_perm
                    -> 'c1)
              -> gnrc_r:
                   (   'c1
                    -> ( [< `Read | `Set_and_create ]
                       , ('d1, 'e1, 'f1) t
                       , 'f1 )
                       Fieldslib.Field.t_with_perm
                    -> 'g1)
              -> gnrc_o:
                   (   'g1
                    -> ( [< `Read | `Set_and_create ]
                       , ('h1, 'i1, 'j1) t
                       , 'j1 )
                       Fieldslib.Field.t_with_perm
                    -> 'k1)
              -> psdn0:
                   (   'k1
                    -> ( [< `Read | `Set_and_create ]
                       , ('l1, 'm1, 'n1) t
                       , 'n1 )
                       Fieldslib.Field.t_with_perm
                    -> 'o1)
              -> ecad0:
                   (   'o1
                    -> ( [< `Read | `Set_and_create ]
                       , ('p1, 'q1, 'r1) t
                       , 'r1 )
                       Fieldslib.Field.t_with_perm
                    -> 's1)
              -> vbmul0:
                   (   's1
                    -> ( [< `Read | `Set_and_create ]
                       , ('t1, 'u1, 'v1) t
                       , 'v1 )
                       Fieldslib.Field.t_with_perm
                    -> 'w1)
              -> vbmul1:
                   (   'w1
                    -> ( [< `Read | `Set_and_create ]
                       , ('x1, 'y1, 'z1) t
                       , 'z1 )
                       Fieldslib.Field.t_with_perm
                    -> 'a2)
              -> endomul0:
                   (   'a2
                    -> ( [< `Read | `Set_and_create ]
                       , ('b2, 'c2, 'd2) t
                       , 'd2 )
                       Fieldslib.Field.t_with_perm
                    -> 'e2)
              -> endomul1:
                   (   'e2
                    -> ( [< `Read | `Set_and_create ]
                       , ('f2, 'g2, 'h2) t
                       , 'h2 )
                       Fieldslib.Field.t_with_perm
                    -> 'i2)
              -> endomul2:
                   (   'i2
                    -> ( [< `Read | `Set_and_create ]
                       , ('j2, 'k2, 'l2) t
                       , 'l2 )
                       Fieldslib.Field.t_with_perm
                    -> 'm2)
              -> 'm2

            val map_poly :
                 ( [< `Read | `Set_and_create ]
                 , ('a, 'b, 'c) t
                 , 'd )
                 Fieldslib.Field.user
              -> 'd list

            val for_all :
                 alpha:
                   (   ( [< `Read | `Set_and_create ]
                       , ('a, 'b, 'c) t
                       , 'b )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> beta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('d, 'e, 'f) t
                       , 'd )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> gamma:
                   (   ( [< `Read | `Set_and_create ]
                       , ('g, 'h, 'i) t
                       , 'g )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> zeta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('j, 'k, 'l) t
                       , 'k )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> perm0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('m, 'n, 'o) t
                       , 'o )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> perm1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('p, 'q, 'r) t
                       , 'r )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> gnrc_l:
                   (   ( [< `Read | `Set_and_create ]
                       , ('s, 't, 'u) t
                       , 'u )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> gnrc_r:
                   (   ( [< `Read | `Set_and_create ]
                       , ('v, 'w, 'x) t
                       , 'x )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> gnrc_o:
                   (   ( [< `Read | `Set_and_create ]
                       , ('y, 'z, 'a1) t
                       , 'a1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> psdn0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('b1, 'c1, 'd1) t
                       , 'd1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> ecad0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('e1, 'f1, 'g1) t
                       , 'g1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> vbmul0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('h1, 'i1, 'j1) t
                       , 'j1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> vbmul1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('k1, 'l1, 'm1) t
                       , 'm1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> endomul0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('n1, 'o1, 'p1) t
                       , 'p1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> endomul1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('q1, 'r1, 's1) t
                       , 's1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> endomul2:
                   (   ( [< `Read | `Set_and_create ]
                       , ('t1, 'u1, 'v1) t
                       , 'v1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> bool

            val exists :
                 alpha:
                   (   ( [< `Read | `Set_and_create ]
                       , ('a, 'b, 'c) t
                       , 'b )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> beta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('d, 'e, 'f) t
                       , 'd )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> gamma:
                   (   ( [< `Read | `Set_and_create ]
                       , ('g, 'h, 'i) t
                       , 'g )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> zeta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('j, 'k, 'l) t
                       , 'k )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> perm0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('m, 'n, 'o) t
                       , 'o )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> perm1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('p, 'q, 'r) t
                       , 'r )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> gnrc_l:
                   (   ( [< `Read | `Set_and_create ]
                       , ('s, 't, 'u) t
                       , 'u )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> gnrc_r:
                   (   ( [< `Read | `Set_and_create ]
                       , ('v, 'w, 'x) t
                       , 'x )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> gnrc_o:
                   (   ( [< `Read | `Set_and_create ]
                       , ('y, 'z, 'a1) t
                       , 'a1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> psdn0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('b1, 'c1, 'd1) t
                       , 'd1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> ecad0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('e1, 'f1, 'g1) t
                       , 'g1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> vbmul0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('h1, 'i1, 'j1) t
                       , 'j1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> vbmul1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('k1, 'l1, 'm1) t
                       , 'm1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> endomul0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('n1, 'o1, 'p1) t
                       , 'p1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> endomul1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('q1, 'r1, 's1) t
                       , 's1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> endomul2:
                   (   ( [< `Read | `Set_and_create ]
                       , ('t1, 'u1, 'v1) t
                       , 'v1 )
                       Fieldslib.Field.t_with_perm
                    -> bool)
              -> bool

            val to_list :
                 alpha:
                   (   ( [< `Read | `Set_and_create ]
                       , ('a, 'b, 'c) t
                       , 'b )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> beta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('e, 'f, 'g) t
                       , 'e )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> gamma:
                   (   ( [< `Read | `Set_and_create ]
                       , ('h, 'i, 'j) t
                       , 'h )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> zeta:
                   (   ( [< `Read | `Set_and_create ]
                       , ('k, 'l, 'm) t
                       , 'l )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> perm0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('n, 'o, 'p) t
                       , 'p )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> perm1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('q, 'r, 's) t
                       , 's )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> gnrc_l:
                   (   ( [< `Read | `Set_and_create ]
                       , ('t, 'u, 'v) t
                       , 'v )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> gnrc_r:
                   (   ( [< `Read | `Set_and_create ]
                       , ('w, 'x, 'y) t
                       , 'y )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> gnrc_o:
                   (   ( [< `Read | `Set_and_create ]
                       , ('z, 'a1, 'b1) t
                       , 'b1 )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> psdn0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('c1, 'd1, 'e1) t
                       , 'e1 )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> ecad0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('f1, 'g1, 'h1) t
                       , 'h1 )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> vbmul0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('i1, 'j1, 'k1) t
                       , 'k1 )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> vbmul1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('l1, 'm1, 'n1) t
                       , 'n1 )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> endomul0:
                   (   ( [< `Read | `Set_and_create ]
                       , ('o1, 'p1, 'q1) t
                       , 'q1 )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> endomul1:
                   (   ( [< `Read | `Set_and_create ]
                       , ('r1, 's1, 't1) t
                       , 't1 )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> endomul2:
                   (   ( [< `Read | `Set_and_create ]
                       , ('u1, 'v1, 'w1) t
                       , 'w1 )
                       Fieldslib.Field.t_with_perm
                    -> 'd)
              -> 'd list

            module Direct : sig
              val iter :
                   ('a, 'b, 'c) t
                -> alpha:
                     (   ( [< `Read | `Set_and_create ]
                         , ('d, 'e, 'f) t
                         , 'e )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'b
                      -> 'g)
                -> beta:
                     (   ( [< `Read | `Set_and_create ]
                         , ('h, 'i, 'j) t
                         , 'h )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'a
                      -> 'k)
                -> gamma:
                     (   ( [< `Read | `Set_and_create ]
                         , ('l, 'm, 'n) t
                         , 'l )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'a
                      -> 'o)
                -> zeta:
                     (   ( [< `Read | `Set_and_create ]
                         , ('p, 'q, 'r) t
                         , 'q )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'b
                      -> 's)
                -> perm0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('t, 'u, 'v) t
                         , 'v )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'w)
                -> perm1:
                     (   ( [< `Read | `Set_and_create ]
                         , ('x, 'y, 'z) t
                         , 'z )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'a1)
                -> gnrc_l:
                     (   ( [< `Read | `Set_and_create ]
                         , ('b1, 'c1, 'd1) t
                         , 'd1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'e1)
                -> gnrc_r:
                     (   ( [< `Read | `Set_and_create ]
                         , ('f1, 'g1, 'h1) t
                         , 'h1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'i1)
                -> gnrc_o:
                     (   ( [< `Read | `Set_and_create ]
                         , ('j1, 'k1, 'l1) t
                         , 'l1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'm1)
                -> psdn0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('n1, 'o1, 'p1) t
                         , 'p1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'q1)
                -> ecad0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('r1, 's1, 't1) t
                         , 't1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'u1)
                -> vbmul0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('v1, 'w1, 'x1) t
                         , 'x1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'y1)
                -> vbmul1:
                     (   ( [< `Read | `Set_and_create ]
                         , ('z1, 'a2, 'b2) t
                         , 'b2 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'c2)
                -> endomul0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('d2, 'e2, 'f2) t
                         , 'f2 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'g2)
                -> endomul1:
                     (   ( [< `Read | `Set_and_create ]
                         , ('h2, 'i2, 'j2) t
                         , 'j2 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'k2)
                -> endomul2:
                     (   ( [< `Read | `Set_and_create ]
                         , ('l2, 'm2, 'n2) t
                         , 'n2 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'o2)
                -> 'o2

              val fold :
                   ('a, 'b, 'c) t
                -> init:'d
                -> alpha:
                     (   'd
                      -> ( [< `Read | `Set_and_create ]
                         , ('e, 'f, 'g) t
                         , 'f )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'b
                      -> 'h)
                -> beta:
                     (   'h
                      -> ( [< `Read | `Set_and_create ]
                         , ('i, 'j, 'k) t
                         , 'i )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'a
                      -> 'l)
                -> gamma:
                     (   'l
                      -> ( [< `Read | `Set_and_create ]
                         , ('m, 'n, 'o) t
                         , 'm )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'a
                      -> 'p)
                -> zeta:
                     (   'p
                      -> ( [< `Read | `Set_and_create ]
                         , ('q, 'r, 's) t
                         , 'r )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'b
                      -> 't)
                -> perm0:
                     (   't
                      -> ( [< `Read | `Set_and_create ]
                         , ('u, 'v, 'w) t
                         , 'w )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'x)
                -> perm1:
                     (   'x
                      -> ( [< `Read | `Set_and_create ]
                         , ('y, 'z, 'a1) t
                         , 'a1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'b1)
                -> gnrc_l:
                     (   'b1
                      -> ( [< `Read | `Set_and_create ]
                         , ('c1, 'd1, 'e1) t
                         , 'e1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'f1)
                -> gnrc_r:
                     (   'f1
                      -> ( [< `Read | `Set_and_create ]
                         , ('g1, 'h1, 'i1) t
                         , 'i1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'j1)
                -> gnrc_o:
                     (   'j1
                      -> ( [< `Read | `Set_and_create ]
                         , ('k1, 'l1, 'm1) t
                         , 'm1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'n1)
                -> psdn0:
                     (   'n1
                      -> ( [< `Read | `Set_and_create ]
                         , ('o1, 'p1, 'q1) t
                         , 'q1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'r1)
                -> ecad0:
                     (   'r1
                      -> ( [< `Read | `Set_and_create ]
                         , ('s1, 't1, 'u1) t
                         , 'u1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'v1)
                -> vbmul0:
                     (   'v1
                      -> ( [< `Read | `Set_and_create ]
                         , ('w1, 'x1, 'y1) t
                         , 'y1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'z1)
                -> vbmul1:
                     (   'z1
                      -> ( [< `Read | `Set_and_create ]
                         , ('a2, 'b2, 'c2) t
                         , 'c2 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'd2)
                -> endomul0:
                     (   'd2
                      -> ( [< `Read | `Set_and_create ]
                         , ('e2, 'f2, 'g2) t
                         , 'g2 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'h2)
                -> endomul1:
                     (   'h2
                      -> ( [< `Read | `Set_and_create ]
                         , ('i2, 'j2, 'k2) t
                         , 'k2 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'l2)
                -> endomul2:
                     (   'l2
                      -> ( [< `Read | `Set_and_create ]
                         , ('m2, 'n2, 'o2) t
                         , 'o2 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'p2)
                -> 'p2

              val for_all :
                   ('a, 'b, 'c) t
                -> alpha:
                     (   ( [< `Read | `Set_and_create ]
                         , ('d, 'e, 'f) t
                         , 'e )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'b
                      -> bool)
                -> beta:
                     (   ( [< `Read | `Set_and_create ]
                         , ('g, 'h, 'i) t
                         , 'g )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'a
                      -> bool)
                -> gamma:
                     (   ( [< `Read | `Set_and_create ]
                         , ('j, 'k, 'l) t
                         , 'j )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'a
                      -> bool)
                -> zeta:
                     (   ( [< `Read | `Set_and_create ]
                         , ('m, 'n, 'o) t
                         , 'n )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'b
                      -> bool)
                -> perm0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('p, 'q, 'r) t
                         , 'r )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> perm1:
                     (   ( [< `Read | `Set_and_create ]
                         , ('s, 't, 'u) t
                         , 'u )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> gnrc_l:
                     (   ( [< `Read | `Set_and_create ]
                         , ('v, 'w, 'x) t
                         , 'x )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> gnrc_r:
                     (   ( [< `Read | `Set_and_create ]
                         , ('y, 'z, 'a1) t
                         , 'a1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> gnrc_o:
                     (   ( [< `Read | `Set_and_create ]
                         , ('b1, 'c1, 'd1) t
                         , 'd1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> psdn0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('e1, 'f1, 'g1) t
                         , 'g1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> ecad0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('h1, 'i1, 'j1) t
                         , 'j1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> vbmul0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('k1, 'l1, 'm1) t
                         , 'm1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> vbmul1:
                     (   ( [< `Read | `Set_and_create ]
                         , ('n1, 'o1, 'p1) t
                         , 'p1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> endomul0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('q1, 'r1, 's1) t
                         , 's1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> endomul1:
                     (   ( [< `Read | `Set_and_create ]
                         , ('t1, 'u1, 'v1) t
                         , 'v1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> endomul2:
                     (   ( [< `Read | `Set_and_create ]
                         , ('w1, 'x1, 'y1) t
                         , 'y1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> bool

              val exists :
                   ('a, 'b, 'c) t
                -> alpha:
                     (   ( [< `Read | `Set_and_create ]
                         , ('d, 'e, 'f) t
                         , 'e )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'b
                      -> bool)
                -> beta:
                     (   ( [< `Read | `Set_and_create ]
                         , ('g, 'h, 'i) t
                         , 'g )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'a
                      -> bool)
                -> gamma:
                     (   ( [< `Read | `Set_and_create ]
                         , ('j, 'k, 'l) t
                         , 'j )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'a
                      -> bool)
                -> zeta:
                     (   ( [< `Read | `Set_and_create ]
                         , ('m, 'n, 'o) t
                         , 'n )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'b
                      -> bool)
                -> perm0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('p, 'q, 'r) t
                         , 'r )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> perm1:
                     (   ( [< `Read | `Set_and_create ]
                         , ('s, 't, 'u) t
                         , 'u )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> gnrc_l:
                     (   ( [< `Read | `Set_and_create ]
                         , ('v, 'w, 'x) t
                         , 'x )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> gnrc_r:
                     (   ( [< `Read | `Set_and_create ]
                         , ('y, 'z, 'a1) t
                         , 'a1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> gnrc_o:
                     (   ( [< `Read | `Set_and_create ]
                         , ('b1, 'c1, 'd1) t
                         , 'd1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> psdn0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('e1, 'f1, 'g1) t
                         , 'g1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> ecad0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('h1, 'i1, 'j1) t
                         , 'j1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> vbmul0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('k1, 'l1, 'm1) t
                         , 'm1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> vbmul1:
                     (   ( [< `Read | `Set_and_create ]
                         , ('n1, 'o1, 'p1) t
                         , 'p1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> endomul0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('q1, 'r1, 's1) t
                         , 's1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> endomul1:
                     (   ( [< `Read | `Set_and_create ]
                         , ('t1, 'u1, 'v1) t
                         , 'v1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> endomul2:
                     (   ( [< `Read | `Set_and_create ]
                         , ('w1, 'x1, 'y1) t
                         , 'y1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> bool)
                -> bool

              val to_list :
                   ('a, 'b, 'c) t
                -> alpha:
                     (   ( [< `Read | `Set_and_create ]
                         , ('d, 'e, 'f) t
                         , 'e )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'b
                      -> 'g)
                -> beta:
                     (   ( [< `Read | `Set_and_create ]
                         , ('h, 'i, 'j) t
                         , 'h )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'a
                      -> 'g)
                -> gamma:
                     (   ( [< `Read | `Set_and_create ]
                         , ('k, 'l, 'm) t
                         , 'k )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'a
                      -> 'g)
                -> zeta:
                     (   ( [< `Read | `Set_and_create ]
                         , ('n, 'o, 'p) t
                         , 'o )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'b
                      -> 'g)
                -> perm0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('q, 'r, 's) t
                         , 's )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'g)
                -> perm1:
                     (   ( [< `Read | `Set_and_create ]
                         , ('t, 'u, 'v) t
                         , 'v )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'g)
                -> gnrc_l:
                     (   ( [< `Read | `Set_and_create ]
                         , ('w, 'x, 'y) t
                         , 'y )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'g)
                -> gnrc_r:
                     (   ( [< `Read | `Set_and_create ]
                         , ('z, 'a1, 'b1) t
                         , 'b1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'g)
                -> gnrc_o:
                     (   ( [< `Read | `Set_and_create ]
                         , ('c1, 'd1, 'e1) t
                         , 'e1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'g)
                -> psdn0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('f1, 'g1, 'h1) t
                         , 'h1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'g)
                -> ecad0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('i1, 'j1, 'k1) t
                         , 'k1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'g)
                -> vbmul0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('l1, 'm1, 'n1) t
                         , 'n1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'g)
                -> vbmul1:
                     (   ( [< `Read | `Set_and_create ]
                         , ('o1, 'p1, 'q1) t
                         , 'q1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'g)
                -> endomul0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('r1, 's1, 't1) t
                         , 't1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'g)
                -> endomul1:
                     (   ( [< `Read | `Set_and_create ]
                         , ('u1, 'v1, 'w1) t
                         , 'w1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'g)
                -> endomul2:
                     (   ( [< `Read | `Set_and_create ]
                         , ('x1, 'y1, 'z1) t
                         , 'z1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'g)
                -> 'g list

              val map :
                   ('a, 'b, 'c) t
                -> alpha:
                     (   ( [< `Read | `Set_and_create ]
                         , ('d, 'e, 'f) t
                         , 'e )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'b
                      -> 'g)
                -> beta:
                     (   ( [< `Read | `Set_and_create ]
                         , ('h, 'i, 'j) t
                         , 'h )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'a
                      -> 'k)
                -> gamma:
                     (   ( [< `Read | `Set_and_create ]
                         , ('l, 'm, 'n) t
                         , 'l )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'a
                      -> 'k)
                -> zeta:
                     (   ( [< `Read | `Set_and_create ]
                         , ('o, 'p, 'q) t
                         , 'p )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'b
                      -> 'g)
                -> perm0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('r, 's, 't) t
                         , 't )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'u)
                -> perm1:
                     (   ( [< `Read | `Set_and_create ]
                         , ('v, 'w, 'x) t
                         , 'x )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'u)
                -> gnrc_l:
                     (   ( [< `Read | `Set_and_create ]
                         , ('y, 'z, 'a1) t
                         , 'a1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'u)
                -> gnrc_r:
                     (   ( [< `Read | `Set_and_create ]
                         , ('b1, 'c1, 'd1) t
                         , 'd1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'u)
                -> gnrc_o:
                     (   ( [< `Read | `Set_and_create ]
                         , ('e1, 'f1, 'g1) t
                         , 'g1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'u)
                -> psdn0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('h1, 'i1, 'j1) t
                         , 'j1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'u)
                -> ecad0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('k1, 'l1, 'm1) t
                         , 'm1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'u)
                -> vbmul0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('n1, 'o1, 'p1) t
                         , 'p1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'u)
                -> vbmul1:
                     (   ( [< `Read | `Set_and_create ]
                         , ('q1, 'r1, 's1) t
                         , 's1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'u)
                -> endomul0:
                     (   ( [< `Read | `Set_and_create ]
                         , ('t1, 'u1, 'v1) t
                         , 'v1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'u)
                -> endomul1:
                     (   ( [< `Read | `Set_and_create ]
                         , ('w1, 'x1, 'y1) t
                         , 'y1 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'u)
                -> endomul2:
                     (   ( [< `Read | `Set_and_create ]
                         , ('z1, 'a2, 'b2) t
                         , 'b2 )
                         Fieldslib.Field.t_with_perm
                      -> ('a, 'b, 'c) t
                      -> 'c
                      -> 'u)
                -> ('k, 'g, 'u) t

              val set_all_mutable_fields : 'a -> unit
            end
          end

          val map_challenges :
               ('a, 'b, 'c) t
            -> f:('a -> 'd)
            -> scalar:('b -> 'e)
            -> ('d, 'e, 'c) t

          val map_fields : ('a, 'b, 'c) t -> f:('c -> 'd) -> ('a, 'b, 'd) t

          val typ :
               challenge:
                 ( 'a
                 , 'b
                 , 'f Snarky_backendless__.Checked.field
                 , ( unit
                   , unit
                   , 'f Snarky_backendless__.Checked.field )
                   Snarky_backendless__.Checked.t )
                 Snarky_backendless__.Types.Typ.t
            -> scalar_challenge:
                 ( 'c
                 , 'd
                 , 'f Snarky_backendless__.Checked.field )
                 Snarky_backendless.Typ.t
            -> ('fp, 'e, 'f) Snarky_backendless.Typ.t
            -> ( ('a, 'c Pickles_types.Scalar_challenge.t, 'fp) t
               , ('b, 'd Pickles_types.Scalar_challenge.t, 'e) t
               , 'f Snarky_backendless__.Checked.field )
               Snarky_backendless.Typ.t
        end

        val to_minimal : ('a, 'b, 'c) In_circuit.t -> ('a, 'b) Minimal.t
      end

      module Stable : sig
        module V1 : sig
          type ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'bulletproof_challenges
               , 'index )
               t =
            { plonk : 'plonk
            ; combined_inner_product : 'fp
            ; b : 'fp
            ; xi : 'scalar_challenge
            ; bulletproof_challenges : 'bulletproof_challenges
            ; which_branch : 'index
            }

          val to_yojson :
               ('plonk -> Yojson.Safe.t)
            -> ('scalar_challenge -> Yojson.Safe.t)
            -> ('fp -> Yojson.Safe.t)
            -> ('fq -> Yojson.Safe.t)
            -> ('bulletproof_challenges -> Yojson.Safe.t)
            -> ('index -> Yojson.Safe.t)
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'bulletproof_challenges
               , 'index )
               t
            -> Yojson.Safe.t

          val of_yojson :
               (Yojson.Safe.t -> 'plonk Ppx_deriving_yojson_runtime.error_or)
            -> (   Yojson.Safe.t
                -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
            -> (Yojson.Safe.t -> 'fp Ppx_deriving_yojson_runtime.error_or)
            -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
            -> (   Yojson.Safe.t
                -> 'bulletproof_challenges Ppx_deriving_yojson_runtime.error_or)
            -> (Yojson.Safe.t -> 'index Ppx_deriving_yojson_runtime.error_or)
            -> Yojson.Safe.t
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'bulletproof_challenges
               , 'index )
               t
               Ppx_deriving_yojson_runtime.error_or

          val version : int

          val __versioned__ : unit

          val t_of_sexp :
               (Ppx_sexp_conv_lib.Sexp.t -> 'plonk)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'fp)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'bulletproof_challenges)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'index)
            -> Ppx_sexp_conv_lib.Sexp.t
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'bulletproof_challenges
               , 'index )
               t

          val sexp_of_t :
               ('plonk -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('fp -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('bulletproof_challenges -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('index -> Ppx_sexp_conv_lib.Sexp.t)
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'bulletproof_challenges
               , 'index )
               t
            -> Ppx_sexp_conv_lib.Sexp.t

          val compare :
               ('plonk -> 'plonk -> int)
            -> ('scalar_challenge -> 'scalar_challenge -> int)
            -> ('fp -> 'fp -> int)
            -> ('fq -> 'fq -> int)
            -> ('bulletproof_challenges -> 'bulletproof_challenges -> int)
            -> ('index -> 'index -> int)
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'bulletproof_challenges
               , 'index )
               t
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'bulletproof_challenges
               , 'index )
               t
            -> int

          val to_hlist :
               ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'bulletproof_challenges
               , 'index )
               t
            -> ( unit
               ,    'plonk
                 -> 'fp
                 -> 'fp
                 -> 'scalar_challenge
                 -> 'bulletproof_challenges
                 -> 'index
                 -> unit )
               H_list.t

          val of_hlist :
               ( unit
               ,    'plonk
                 -> 'fp
                 -> 'fp
                 -> 'scalar_challenge
                 -> 'bulletproof_challenges
                 -> 'index
                 -> unit )
               H_list.t
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'bulletproof_challenges
               , 'index )
               t

          val hash_fold_t :
               (   Ppx_hash_lib.Std.Hash.state
                -> 'plonk
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'scalar_challenge
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'fp
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'fq
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'bulletproof_challenges
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'index
                -> Ppx_hash_lib.Std.Hash.state)
            -> Ppx_hash_lib.Std.Hash.state
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'bulletproof_challenges
               , 'index )
               t
            -> Ppx_hash_lib.Std.Hash.state

          val equal :
               ('plonk -> 'plonk -> bool)
            -> ('scalar_challenge -> 'scalar_challenge -> bool)
            -> ('fp -> 'fp -> bool)
            -> ('fq -> 'fq -> bool)
            -> ('bulletproof_challenges -> 'bulletproof_challenges -> bool)
            -> ('index -> 'index -> bool)
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'bulletproof_challenges
               , 'index )
               t
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'bulletproof_challenges
               , 'index )
               t
            -> bool

          val to_latest : 'a -> 'a

          module With_version : sig
            type ( 'plonk
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'bulletproof_challenges
                 , 'index )
                 typ =
              ( 'plonk
              , 'scalar_challenge
              , 'fp
              , 'fq
              , 'bulletproof_challenges
              , 'index )
              t

            val bin_shape_typ :
                 Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t

            val bin_size_typ :
                 'plonk Core_kernel.Bin_prot.Size.sizer
              -> 'scalar_challenge Core_kernel.Bin_prot.Size.sizer
              -> 'fp Core_kernel.Bin_prot.Size.sizer
              -> 'fq Core_kernel.Bin_prot.Size.sizer
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Size.sizer
              -> 'index Core_kernel.Bin_prot.Size.sizer
              -> ( 'plonk
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'bulletproof_challenges
                 , 'index )
                 typ
                 Core_kernel.Bin_prot.Size.sizer

            val bin_write_typ :
                 'plonk Core_kernel.Bin_prot.Write.writer
              -> 'scalar_challenge Core_kernel.Bin_prot.Write.writer
              -> 'fp Core_kernel.Bin_prot.Write.writer
              -> 'fq Core_kernel.Bin_prot.Write.writer
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Write.writer
              -> 'index Core_kernel.Bin_prot.Write.writer
              -> ( 'plonk
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'bulletproof_challenges
                 , 'index )
                 typ
                 Core_kernel.Bin_prot.Write.writer

            val bin_writer_typ :
                 'a Core_kernel.Bin_prot.Type_class.writer
              -> 'b Core_kernel.Bin_prot.Type_class.writer
              -> 'c Core_kernel.Bin_prot.Type_class.writer
              -> 'd Core_kernel.Bin_prot.Type_class.writer
              -> 'e Core_kernel.Bin_prot.Type_class.writer
              -> 'f Core_kernel.Bin_prot.Type_class.writer
              -> ('a, 'b, 'c, 'd, 'e, 'f) typ
                 Core_kernel.Bin_prot.Type_class.writer

            val __bin_read_typ__ :
                 'plonk Core_kernel.Bin_prot.Read.reader
              -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
              -> 'fp Core_kernel.Bin_prot.Read.reader
              -> 'fq Core_kernel.Bin_prot.Read.reader
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Read.reader
              -> 'index Core_kernel.Bin_prot.Read.reader
              -> (   int
                  -> ( 'plonk
                     , 'scalar_challenge
                     , 'fp
                     , 'fq
                     , 'bulletproof_challenges
                     , 'index )
                     typ)
                 Core_kernel.Bin_prot.Read.reader

            val bin_read_typ :
                 'plonk Core_kernel.Bin_prot.Read.reader
              -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
              -> 'fp Core_kernel.Bin_prot.Read.reader
              -> 'fq Core_kernel.Bin_prot.Read.reader
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Read.reader
              -> 'index Core_kernel.Bin_prot.Read.reader
              -> ( 'plonk
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'bulletproof_challenges
                 , 'index )
                 typ
                 Core_kernel.Bin_prot.Read.reader

            val bin_reader_typ :
                 'a Core_kernel.Bin_prot.Type_class.reader
              -> 'b Core_kernel.Bin_prot.Type_class.reader
              -> 'c Core_kernel.Bin_prot.Type_class.reader
              -> 'd Core_kernel.Bin_prot.Type_class.reader
              -> 'e Core_kernel.Bin_prot.Type_class.reader
              -> 'f Core_kernel.Bin_prot.Type_class.reader
              -> ('a, 'b, 'c, 'd, 'e, 'f) typ
                 Core_kernel.Bin_prot.Type_class.reader

            val bin_typ :
                 'a Core_kernel.Bin_prot.Type_class.t
              -> 'b Core_kernel.Bin_prot.Type_class.t
              -> 'c Core_kernel.Bin_prot.Type_class.t
              -> 'd Core_kernel.Bin_prot.Type_class.t
              -> 'e Core_kernel.Bin_prot.Type_class.t
              -> 'f Core_kernel.Bin_prot.Type_class.t
              -> ('a, 'b, 'c, 'd, 'e, 'f) typ Core_kernel.Bin_prot.Type_class.t

            type ( 'plonk
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'bulletproof_challenges
                 , 'index )
                 t =
              { version : int
              ; t :
                  ( 'plonk
                  , 'scalar_challenge
                  , 'fp
                  , 'fq
                  , 'bulletproof_challenges
                  , 'index )
                  typ
              }

            val bin_shape_t :
                 Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t

            val bin_size_t :
                 'plonk Core_kernel.Bin_prot.Size.sizer
              -> 'scalar_challenge Core_kernel.Bin_prot.Size.sizer
              -> 'fp Core_kernel.Bin_prot.Size.sizer
              -> 'fq Core_kernel.Bin_prot.Size.sizer
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Size.sizer
              -> 'index Core_kernel.Bin_prot.Size.sizer
              -> ( 'plonk
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'bulletproof_challenges
                 , 'index )
                 t
                 Core_kernel.Bin_prot.Size.sizer

            val bin_write_t :
                 'plonk Core_kernel.Bin_prot.Write.writer
              -> 'scalar_challenge Core_kernel.Bin_prot.Write.writer
              -> 'fp Core_kernel.Bin_prot.Write.writer
              -> 'fq Core_kernel.Bin_prot.Write.writer
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Write.writer
              -> 'index Core_kernel.Bin_prot.Write.writer
              -> ( 'plonk
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'bulletproof_challenges
                 , 'index )
                 t
                 Core_kernel.Bin_prot.Write.writer

            val bin_writer_t :
                 'a Core_kernel.Bin_prot.Type_class.writer
              -> 'b Core_kernel.Bin_prot.Type_class.writer
              -> 'c Core_kernel.Bin_prot.Type_class.writer
              -> 'd Core_kernel.Bin_prot.Type_class.writer
              -> 'e Core_kernel.Bin_prot.Type_class.writer
              -> 'f Core_kernel.Bin_prot.Type_class.writer
              -> ('a, 'b, 'c, 'd, 'e, 'f) t
                 Core_kernel.Bin_prot.Type_class.writer

            val __bin_read_t__ :
                 'plonk Core_kernel.Bin_prot.Read.reader
              -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
              -> 'fp Core_kernel.Bin_prot.Read.reader
              -> 'fq Core_kernel.Bin_prot.Read.reader
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Read.reader
              -> 'index Core_kernel.Bin_prot.Read.reader
              -> (   int
                  -> ( 'plonk
                     , 'scalar_challenge
                     , 'fp
                     , 'fq
                     , 'bulletproof_challenges
                     , 'index )
                     t)
                 Core_kernel.Bin_prot.Read.reader

            val bin_read_t :
                 'plonk Core_kernel.Bin_prot.Read.reader
              -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
              -> 'fp Core_kernel.Bin_prot.Read.reader
              -> 'fq Core_kernel.Bin_prot.Read.reader
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Read.reader
              -> 'index Core_kernel.Bin_prot.Read.reader
              -> ( 'plonk
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'bulletproof_challenges
                 , 'index )
                 t
                 Core_kernel.Bin_prot.Read.reader

            val bin_reader_t :
                 'a Core_kernel.Bin_prot.Type_class.reader
              -> 'b Core_kernel.Bin_prot.Type_class.reader
              -> 'c Core_kernel.Bin_prot.Type_class.reader
              -> 'd Core_kernel.Bin_prot.Type_class.reader
              -> 'e Core_kernel.Bin_prot.Type_class.reader
              -> 'f Core_kernel.Bin_prot.Type_class.reader
              -> ('a, 'b, 'c, 'd, 'e, 'f) t
                 Core_kernel.Bin_prot.Type_class.reader

            val bin_t :
                 'a Core_kernel.Bin_prot.Type_class.t
              -> 'b Core_kernel.Bin_prot.Type_class.t
              -> 'c Core_kernel.Bin_prot.Type_class.t
              -> 'd Core_kernel.Bin_prot.Type_class.t
              -> 'e Core_kernel.Bin_prot.Type_class.t
              -> 'f Core_kernel.Bin_prot.Type_class.t
              -> ('a, 'b, 'c, 'd, 'e, 'f) t Core_kernel.Bin_prot.Type_class.t

            val create :
              ('a, 'b, 'c, 'd, 'e, 'f) typ -> ('a, 'b, 'c, 'd, 'e, 'f) t
          end

          val bin_read_t :
               'a Core_kernel.Bin_prot.Read.reader
            -> 'b Core_kernel.Bin_prot.Read.reader
            -> 'c Core_kernel.Bin_prot.Read.reader
            -> 'd Core_kernel.Bin_prot.Read.reader
            -> 'e Core_kernel.Bin_prot.Read.reader
            -> 'f Core_kernel.Bin_prot.Read.reader
            -> Bin_prot.Common.buf
            -> pos_ref:Bin_prot.Common.pos_ref
            -> ('a, 'b, 'c, 'd, 'e, 'f) t

          val __bin_read_t__ :
               'a Core_kernel.Bin_prot.Read.reader
            -> 'b Core_kernel.Bin_prot.Read.reader
            -> 'c Core_kernel.Bin_prot.Read.reader
            -> 'd Core_kernel.Bin_prot.Read.reader
            -> 'e Core_kernel.Bin_prot.Read.reader
            -> 'f Core_kernel.Bin_prot.Read.reader
            -> Bin_prot.Common.buf
            -> pos_ref:Bin_prot.Common.pos_ref
            -> int
            -> ('a, 'b, 'c, 'd, 'e, 'f) t

          val bin_size_t :
               'a Core_kernel.Bin_prot.Size.sizer
            -> 'b Core_kernel.Bin_prot.Size.sizer
            -> 'c Core_kernel.Bin_prot.Size.sizer
            -> 'd Core_kernel.Bin_prot.Size.sizer
            -> 'e Core_kernel.Bin_prot.Size.sizer
            -> 'f Core_kernel.Bin_prot.Size.sizer
            -> ('a, 'b, 'c, 'd, 'e, 'f) t
            -> int

          val bin_write_t :
               'a Core_kernel.Bin_prot.Write.writer
            -> 'b Core_kernel.Bin_prot.Write.writer
            -> 'c Core_kernel.Bin_prot.Write.writer
            -> 'd Core_kernel.Bin_prot.Write.writer
            -> 'e Core_kernel.Bin_prot.Write.writer
            -> 'f Core_kernel.Bin_prot.Write.writer
            -> Bin_prot.Common.buf
            -> pos:Bin_prot.Common.pos
            -> ('a, 'b, 'c, 'd, 'e, 'f) t
            -> Bin_prot.Common.pos

          val bin_shape_t :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
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
            -> 'f Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c, 'd, 'e, 'f) t Core_kernel.Bin_prot.Type_class.reader

          val bin_writer_t :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> 'd Core_kernel.Bin_prot.Type_class.writer
            -> 'e Core_kernel.Bin_prot.Type_class.writer
            -> 'f Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c, 'd, 'e, 'f) t Core_kernel.Bin_prot.Type_class.writer

          val bin_t :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> 'd Core_kernel.Bin_prot.Type_class.t
            -> 'e Core_kernel.Bin_prot.Type_class.t
            -> 'f Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c, 'd, 'e, 'f) t Core_kernel.Bin_prot.Type_class.t

          val __ :
            (   'a Core_kernel.Bin_prot.Read.reader
             -> 'b Core_kernel.Bin_prot.Read.reader
             -> 'c Core_kernel.Bin_prot.Read.reader
             -> 'd Core_kernel.Bin_prot.Read.reader
             -> 'e Core_kernel.Bin_prot.Read.reader
             -> 'f Core_kernel.Bin_prot.Read.reader
             -> Bin_prot.Common.buf
             -> pos_ref:Bin_prot.Common.pos_ref
             -> ('a, 'b, 'c, 'd, 'e, 'f) t)
            * (   'g Core_kernel.Bin_prot.Read.reader
               -> 'h Core_kernel.Bin_prot.Read.reader
               -> 'i Core_kernel.Bin_prot.Read.reader
               -> 'j Core_kernel.Bin_prot.Read.reader
               -> 'k Core_kernel.Bin_prot.Read.reader
               -> 'l Core_kernel.Bin_prot.Read.reader
               -> Bin_prot.Common.buf
               -> pos_ref:Bin_prot.Common.pos_ref
               -> int
               -> ('g, 'h, 'i, 'j, 'k, 'l) t)
            * (   'm Core_kernel.Bin_prot.Size.sizer
               -> 'n Core_kernel.Bin_prot.Size.sizer
               -> 'o Core_kernel.Bin_prot.Size.sizer
               -> 'p Core_kernel.Bin_prot.Size.sizer
               -> 'q Core_kernel.Bin_prot.Size.sizer
               -> 'r Core_kernel.Bin_prot.Size.sizer
               -> ('m, 'n, 'o, 'p, 'q, 'r) t
               -> int)
            * (   's Core_kernel.Bin_prot.Write.writer
               -> 't Core_kernel.Bin_prot.Write.writer
               -> 'u Core_kernel.Bin_prot.Write.writer
               -> 'v Core_kernel.Bin_prot.Write.writer
               -> 'w Core_kernel.Bin_prot.Write.writer
               -> 'x Core_kernel.Bin_prot.Write.writer
               -> Bin_prot.Common.buf
               -> pos:Bin_prot.Common.pos
               -> ('s, 't, 'u, 'v, 'w, 'x) t
               -> Bin_prot.Common.pos)
            * (   Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t)
            * (   'y Core_kernel.Bin_prot.Type_class.reader
               -> 'z Core_kernel.Bin_prot.Type_class.reader
               -> 'a1 Core_kernel.Bin_prot.Type_class.reader
               -> 'b1 Core_kernel.Bin_prot.Type_class.reader
               -> 'c1 Core_kernel.Bin_prot.Type_class.reader
               -> 'd1 Core_kernel.Bin_prot.Type_class.reader
               -> ('y, 'z, 'a1, 'b1, 'c1, 'd1) t
                  Core_kernel.Bin_prot.Type_class.reader)
            * (   'e1 Core_kernel.Bin_prot.Type_class.writer
               -> 'f1 Core_kernel.Bin_prot.Type_class.writer
               -> 'g1 Core_kernel.Bin_prot.Type_class.writer
               -> 'h1 Core_kernel.Bin_prot.Type_class.writer
               -> 'i1 Core_kernel.Bin_prot.Type_class.writer
               -> 'j1 Core_kernel.Bin_prot.Type_class.writer
               -> ('e1, 'f1, 'g1, 'h1, 'i1, 'j1) t
                  Core_kernel.Bin_prot.Type_class.writer)
            * (   'k1 Core_kernel.Bin_prot.Type_class.t
               -> 'l1 Core_kernel.Bin_prot.Type_class.t
               -> 'm1 Core_kernel.Bin_prot.Type_class.t
               -> 'n1 Core_kernel.Bin_prot.Type_class.t
               -> 'o1 Core_kernel.Bin_prot.Type_class.t
               -> 'p1 Core_kernel.Bin_prot.Type_class.t
               -> ('k1, 'l1, 'm1, 'n1, 'o1, 'p1) t
                  Core_kernel.Bin_prot.Type_class.t)
        end

        module Latest = V1
      end

      type ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'bulletproof_challenges
           , 'index )
           t =
            ( 'plonk
            , 'scalar_challenge
            , 'fp
            , 'fq
            , 'bulletproof_challenges
            , 'index )
            Stable.V1.t =
        { plonk : 'plonk
        ; combined_inner_product : 'fp
        ; b : 'fp
        ; xi : 'scalar_challenge
        ; bulletproof_challenges : 'bulletproof_challenges
        ; which_branch : 'index
        }

      val to_yojson :
           ('plonk -> Yojson.Safe.t)
        -> ('scalar_challenge -> Yojson.Safe.t)
        -> ('fp -> Yojson.Safe.t)
        -> ('fq -> Yojson.Safe.t)
        -> ('bulletproof_challenges -> Yojson.Safe.t)
        -> ('index -> Yojson.Safe.t)
        -> ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'bulletproof_challenges
           , 'index )
           t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'plonk Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'fp Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'bulletproof_challenges Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'index Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'bulletproof_challenges
           , 'index )
           t
           Ppx_deriving_yojson_runtime.error_or

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'plonk)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fp)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'bulletproof_challenges)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'index)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'bulletproof_challenges
           , 'index )
           t

      val sexp_of_t :
           ('plonk -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fp -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('bulletproof_challenges -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('index -> Ppx_sexp_conv_lib.Sexp.t)
        -> ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'bulletproof_challenges
           , 'index )
           t
        -> Ppx_sexp_conv_lib.Sexp.t

      val compare :
           ('plonk -> 'plonk -> int)
        -> ('scalar_challenge -> 'scalar_challenge -> int)
        -> ('fp -> 'fp -> int)
        -> ('fq -> 'fq -> int)
        -> ('bulletproof_challenges -> 'bulletproof_challenges -> int)
        -> ('index -> 'index -> int)
        -> ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'bulletproof_challenges
           , 'index )
           t
        -> ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'bulletproof_challenges
           , 'index )
           t
        -> int

      val to_hlist :
           ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'bulletproof_challenges
           , 'index )
           t
        -> ( unit
           ,    'plonk
             -> 'fp
             -> 'fp
             -> 'scalar_challenge
             -> 'bulletproof_challenges
             -> 'index
             -> unit )
           H_list.t

      val of_hlist :
           ( unit
           ,    'plonk
             -> 'fp
             -> 'fp
             -> 'scalar_challenge
             -> 'bulletproof_challenges
             -> 'index
             -> unit )
           H_list.t
        -> ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'bulletproof_challenges
           , 'index )
           t

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'plonk -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'scalar_challenge
            -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'fp -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'fq -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'bulletproof_challenges
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'index
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'bulletproof_challenges
           , 'index )
           t
        -> Ppx_hash_lib.Std.Hash.state

      val equal :
           ('plonk -> 'plonk -> bool)
        -> ('scalar_challenge -> 'scalar_challenge -> bool)
        -> ('fp -> 'fp -> bool)
        -> ('fq -> 'fq -> bool)
        -> ('bulletproof_challenges -> 'bulletproof_challenges -> bool)
        -> ('index -> 'index -> bool)
        -> ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'bulletproof_challenges
           , 'index )
           t
        -> ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'bulletproof_challenges
           , 'index )
           t
        -> bool

      module Minimal : sig
        type ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t =
          ( ('challenge, 'scalar_challenge) Plonk.Minimal.t
          , 'scalar_challenge
          , 'fp
          , 'fq
          , 'bulletproof_challenges
          , 'index )
          Stable.V1.t

        val to_yojson :
             ('challenge -> Yojson.Safe.t)
          -> ('scalar_challenge -> Yojson.Safe.t)
          -> ('fp -> Yojson.Safe.t)
          -> ('fq -> Yojson.Safe.t)
          -> ('bulletproof_challenges -> Yojson.Safe.t)
          -> ('index -> Yojson.Safe.t)
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
          -> Yojson.Safe.t

        val of_yojson :
             (Yojson.Safe.t -> 'challenge Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'fp Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'bulletproof_challenges Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'index Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
             Ppx_deriving_yojson_runtime.error_or

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'fp)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'bulletproof_challenges)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'index)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t

        val sexp_of_t :
             ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('fp -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('bulletproof_challenges -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('index -> Ppx_sexp_conv_lib.Sexp.t)
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
          -> Ppx_sexp_conv_lib.Sexp.t

        val compare :
             ('challenge -> 'challenge -> int)
          -> ('scalar_challenge -> 'scalar_challenge -> int)
          -> ('fp -> 'fp -> int)
          -> ('fq -> 'fq -> int)
          -> ('bulletproof_challenges -> 'bulletproof_challenges -> int)
          -> ('index -> 'index -> int)
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
          -> int

        val hash_fold_t :
             (   Ppx_hash_lib.Std.Hash.state
              -> 'challenge
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'scalar_challenge
              -> Ppx_hash_lib.Std.Hash.state)
          -> (Ppx_hash_lib.Std.Hash.state -> 'fp -> Ppx_hash_lib.Std.Hash.state)
          -> (Ppx_hash_lib.Std.Hash.state -> 'fq -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'bulletproof_challenges
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'index
              -> Ppx_hash_lib.Std.Hash.state)
          -> Ppx_hash_lib.Std.Hash.state
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
          -> Ppx_hash_lib.Std.Hash.state

        val equal :
             ('challenge -> 'challenge -> bool)
          -> ('scalar_challenge -> 'scalar_challenge -> bool)
          -> ('fp -> 'fp -> bool)
          -> ('fq -> 'fq -> bool)
          -> ('bulletproof_challenges -> 'bulletproof_challenges -> bool)
          -> ('index -> 'index -> bool)
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
          -> bool
      end

      val map_challenges :
           ('a, 'b, 'fp, 'c, 'd, 'e) t
        -> f:'f
        -> scalar:('b -> 'g)
        -> ('a, 'g, 'fp, 'h, 'd, 'e) t

      module In_circuit : sig
        type ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t =
          ( ('challenge, 'scalar_challenge, 'fp) Plonk.In_circuit.t
          , 'scalar_challenge
          , 'fp
          , 'fq
          , 'bulletproof_challenges
          , 'index )
          Stable.V1.t

        val to_yojson :
             ('challenge -> Yojson.Safe.t)
          -> ('scalar_challenge -> Yojson.Safe.t)
          -> ('fp -> Yojson.Safe.t)
          -> ('fq -> Yojson.Safe.t)
          -> ('bulletproof_challenges -> Yojson.Safe.t)
          -> ('index -> Yojson.Safe.t)
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
          -> Yojson.Safe.t

        val of_yojson :
             (Yojson.Safe.t -> 'challenge Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'fp Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'bulletproof_challenges Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'index Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
             Ppx_deriving_yojson_runtime.error_or

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'fp)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'bulletproof_challenges)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'index)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t

        val sexp_of_t :
             ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('fp -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('bulletproof_challenges -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('index -> Ppx_sexp_conv_lib.Sexp.t)
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
          -> Ppx_sexp_conv_lib.Sexp.t

        val compare :
             ('challenge -> 'challenge -> int)
          -> ('scalar_challenge -> 'scalar_challenge -> int)
          -> ('fp -> 'fp -> int)
          -> ('fq -> 'fq -> int)
          -> ('bulletproof_challenges -> 'bulletproof_challenges -> int)
          -> ('index -> 'index -> int)
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
          -> int

        val hash_fold_t :
             (   Ppx_hash_lib.Std.Hash.state
              -> 'challenge
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'scalar_challenge
              -> Ppx_hash_lib.Std.Hash.state)
          -> (Ppx_hash_lib.Std.Hash.state -> 'fp -> Ppx_hash_lib.Std.Hash.state)
          -> (Ppx_hash_lib.Std.Hash.state -> 'fq -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'bulletproof_challenges
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'index
              -> Ppx_hash_lib.Std.Hash.state)
          -> Ppx_hash_lib.Std.Hash.state
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
          -> Ppx_hash_lib.Std.Hash.state

        val equal :
             ('challenge -> 'challenge -> bool)
          -> ('scalar_challenge -> 'scalar_challenge -> bool)
          -> ('fp -> 'fp -> bool)
          -> ('fq -> 'fq -> bool)
          -> ('bulletproof_challenges -> 'bulletproof_challenges -> bool)
          -> ('index -> 'index -> bool)
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
          -> ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'bulletproof_challenges
             , 'index )
             t
          -> bool

        val to_hlist :
             ('a, 'b, 'c, 'd, 'e, 'f) Stable.V1.t
          -> (unit, 'a -> 'c -> 'c -> 'b -> 'e -> 'f -> unit) H_list.t

        val of_hlist :
             (unit, 'a -> 'b -> 'b -> 'c -> 'd -> 'e -> unit) H_list.t
          -> ('a, 'c, 'b, 'f, 'd, 'e) Stable.V1.t

        val typ :
             challenge:
               ( 'a
               , 'b
               , 'f Snarky_backendless__.Checked.field
               , ( unit
                 , unit
                 , 'f Snarky_backendless__.Checked.field )
                 Snarky_backendless__.Checked.t )
               Snarky_backendless__.Types.Typ.t
          -> scalar_challenge:
               ( 'c
               , 'd
               , 'f Snarky_backendless__.Checked.field )
               Snarky_backendless.Typ.t
          -> ('fp, 'e, 'f) Snarky_backendless.Typ.t
          -> 'g
          -> ( 'h
             , 'i
             , 'f Snarky_backendless__.Checked.field
               Snarky_backendless__.Checked.field
             , ( unit
               , unit
               , 'f Snarky_backendless__.Checked.field
                 Snarky_backendless__.Checked.field )
               Snarky_backendless__.Checked.t )
             Snarky_backendless__.Types.Typ.t
          -> ( ( ( 'a
                 , 'c Pickles_types.Scalar_challenge.t
                 , 'fp )
                 Plonk.In_circuit.t
               , 'c Pickles_types.Scalar_challenge.t
               , 'fp
               , 'j
               , ( 'c Pickles_types.Scalar_challenge.t Bulletproof_challenge.t
                 , Pickles_types__Nat.z Backend.Tick.Rounds.plus_n )
                 Pickles_types.Vector.t
               , 'h )
               Stable.V1.t
             , ( ('b, 'd Pickles_types.Scalar_challenge.t, 'e) Plonk.In_circuit.t
               , 'd Pickles_types.Scalar_challenge.t
               , 'e
               , 'k
               , ( 'd Pickles_types.Scalar_challenge.t Bulletproof_challenge.t
                 , Pickles_types__Nat.z Backend.Tick.Rounds.plus_n )
                 Pickles_types.Vector.t
               , 'i )
               Stable.V1.t
             , 'f Snarky_backendless__.Checked.field
               Snarky_backendless__.Checked.field )
             Snarky_backendless.Typ.t
      end

      val to_minimal :
           ('a, 'b, 'c, 'd, 'e, 'f) In_circuit.t
        -> ('a, 'b, 'c, 'g, 'e, 'f) Minimal.t
    end

    module Me_only : sig
      module Stable : sig
        module V1 : sig
          type ('g1, 'bulletproof_challenges) t =
            { sg : 'g1; old_bulletproof_challenges : 'bulletproof_challenges }

          val to_yojson :
               ('g1 -> Yojson.Safe.t)
            -> ('bulletproof_challenges -> Yojson.Safe.t)
            -> ('g1, 'bulletproof_challenges) t
            -> Yojson.Safe.t

          val of_yojson :
               (Yojson.Safe.t -> 'g1 Ppx_deriving_yojson_runtime.error_or)
            -> (   Yojson.Safe.t
                -> 'bulletproof_challenges Ppx_deriving_yojson_runtime.error_or)
            -> Yojson.Safe.t
            -> ('g1, 'bulletproof_challenges) t
               Ppx_deriving_yojson_runtime.error_or

          val version : int

          val __versioned__ : unit

          val t_of_sexp :
               (Ppx_sexp_conv_lib.Sexp.t -> 'g1)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'bulletproof_challenges)
            -> Ppx_sexp_conv_lib.Sexp.t
            -> ('g1, 'bulletproof_challenges) t

          val sexp_of_t :
               ('g1 -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('bulletproof_challenges -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('g1, 'bulletproof_challenges) t
            -> Ppx_sexp_conv_lib.Sexp.t

          val compare :
               ('g1 -> 'g1 -> int)
            -> ('bulletproof_challenges -> 'bulletproof_challenges -> int)
            -> ('g1, 'bulletproof_challenges) t
            -> ('g1, 'bulletproof_challenges) t
            -> int

          val to_hlist :
               ('g1, 'bulletproof_challenges) t
            -> (unit, 'g1 -> 'bulletproof_challenges -> unit) H_list.t

          val of_hlist :
               (unit, 'g1 -> 'bulletproof_challenges -> unit) H_list.t
            -> ('g1, 'bulletproof_challenges) t

          val hash_fold_t :
               (   Ppx_hash_lib.Std.Hash.state
                -> 'g1
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'bulletproof_challenges
                -> Ppx_hash_lib.Std.Hash.state)
            -> Ppx_hash_lib.Std.Hash.state
            -> ('g1, 'bulletproof_challenges) t
            -> Ppx_hash_lib.Std.Hash.state

          val equal :
               ('g1 -> 'g1 -> bool)
            -> ('bulletproof_challenges -> 'bulletproof_challenges -> bool)
            -> ('g1, 'bulletproof_challenges) t
            -> ('g1, 'bulletproof_challenges) t
            -> bool

          module With_version : sig
            type ('g1, 'bulletproof_challenges) typ =
              ('g1, 'bulletproof_challenges) t

            val bin_shape_typ :
                 Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t

            val bin_size_typ :
                 'g1 Core_kernel.Bin_prot.Size.sizer
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Size.sizer
              -> ('g1, 'bulletproof_challenges) typ
                 Core_kernel.Bin_prot.Size.sizer

            val bin_write_typ :
                 'g1 Core_kernel.Bin_prot.Write.writer
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Write.writer
              -> ('g1, 'bulletproof_challenges) typ
                 Core_kernel.Bin_prot.Write.writer

            val bin_writer_typ :
                 'a Core_kernel.Bin_prot.Type_class.writer
              -> 'b Core_kernel.Bin_prot.Type_class.writer
              -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.writer

            val __bin_read_typ__ :
                 'g1 Core_kernel.Bin_prot.Read.reader
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Read.reader
              -> (int -> ('g1, 'bulletproof_challenges) typ)
                 Core_kernel.Bin_prot.Read.reader

            val bin_read_typ :
                 'g1 Core_kernel.Bin_prot.Read.reader
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Read.reader
              -> ('g1, 'bulletproof_challenges) typ
                 Core_kernel.Bin_prot.Read.reader

            val bin_reader_typ :
                 'a Core_kernel.Bin_prot.Type_class.reader
              -> 'b Core_kernel.Bin_prot.Type_class.reader
              -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.reader

            val bin_typ :
                 'a Core_kernel.Bin_prot.Type_class.t
              -> 'b Core_kernel.Bin_prot.Type_class.t
              -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.t

            type ('g1, 'bulletproof_challenges) t =
              { version : int; t : ('g1, 'bulletproof_challenges) typ }

            val bin_shape_t :
                 Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t

            val bin_size_t :
                 'g1 Core_kernel.Bin_prot.Size.sizer
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Size.sizer
              -> ('g1, 'bulletproof_challenges) t
                 Core_kernel.Bin_prot.Size.sizer

            val bin_write_t :
                 'g1 Core_kernel.Bin_prot.Write.writer
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Write.writer
              -> ('g1, 'bulletproof_challenges) t
                 Core_kernel.Bin_prot.Write.writer

            val bin_writer_t :
                 'a Core_kernel.Bin_prot.Type_class.writer
              -> 'b Core_kernel.Bin_prot.Type_class.writer
              -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

            val __bin_read_t__ :
                 'g1 Core_kernel.Bin_prot.Read.reader
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Read.reader
              -> (int -> ('g1, 'bulletproof_challenges) t)
                 Core_kernel.Bin_prot.Read.reader

            val bin_read_t :
                 'g1 Core_kernel.Bin_prot.Read.reader
              -> 'bulletproof_challenges Core_kernel.Bin_prot.Read.reader
              -> ('g1, 'bulletproof_challenges) t
                 Core_kernel.Bin_prot.Read.reader

            val bin_reader_t :
                 'a Core_kernel.Bin_prot.Type_class.reader
              -> 'b Core_kernel.Bin_prot.Type_class.reader
              -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.reader

            val bin_t :
                 'a Core_kernel.Bin_prot.Type_class.t
              -> 'b Core_kernel.Bin_prot.Type_class.t
              -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.t

            val create : ('a, 'b) typ -> ('a, 'b) t
          end

          val bin_read_t :
               'a Core_kernel.Bin_prot.Read.reader
            -> 'b Core_kernel.Bin_prot.Read.reader
            -> Bin_prot.Common.buf
            -> pos_ref:Bin_prot.Common.pos_ref
            -> ('a, 'b) t

          val __bin_read_t__ :
               'a Core_kernel.Bin_prot.Read.reader
            -> 'b Core_kernel.Bin_prot.Read.reader
            -> Bin_prot.Common.buf
            -> pos_ref:Bin_prot.Common.pos_ref
            -> int
            -> ('a, 'b) t

          val bin_size_t :
               'a Core_kernel.Bin_prot.Size.sizer
            -> 'b Core_kernel.Bin_prot.Size.sizer
            -> ('a, 'b) t
            -> int

          val bin_write_t :
               'a Core_kernel.Bin_prot.Write.writer
            -> 'b Core_kernel.Bin_prot.Write.writer
            -> Bin_prot.Common.buf
            -> pos:Bin_prot.Common.pos
            -> ('a, 'b) t
            -> Bin_prot.Common.pos

          val bin_shape_t :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_reader_t :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.reader

          val bin_writer_t :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

          val bin_t :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.t

          val __ :
            (   'a Core_kernel.Bin_prot.Read.reader
             -> 'b Core_kernel.Bin_prot.Read.reader
             -> Bin_prot.Common.buf
             -> pos_ref:Bin_prot.Common.pos_ref
             -> ('a, 'b) t)
            * (   'c Core_kernel.Bin_prot.Read.reader
               -> 'd Core_kernel.Bin_prot.Read.reader
               -> Bin_prot.Common.buf
               -> pos_ref:Bin_prot.Common.pos_ref
               -> int
               -> ('c, 'd) t)
            * (   'e Core_kernel.Bin_prot.Size.sizer
               -> 'f Core_kernel.Bin_prot.Size.sizer
               -> ('e, 'f) t
               -> int)
            * (   'g Core_kernel.Bin_prot.Write.writer
               -> 'h Core_kernel.Bin_prot.Write.writer
               -> Bin_prot.Common.buf
               -> pos:Bin_prot.Common.pos
               -> ('g, 'h) t
               -> Bin_prot.Common.pos)
            * (   Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t)
            * (   'i Core_kernel.Bin_prot.Type_class.reader
               -> 'j Core_kernel.Bin_prot.Type_class.reader
               -> ('i, 'j) t Core_kernel.Bin_prot.Type_class.reader)
            * (   'k Core_kernel.Bin_prot.Type_class.writer
               -> 'l Core_kernel.Bin_prot.Type_class.writer
               -> ('k, 'l) t Core_kernel.Bin_prot.Type_class.writer)
            * (   'm Core_kernel.Bin_prot.Type_class.t
               -> 'n Core_kernel.Bin_prot.Type_class.t
               -> ('m, 'n) t Core_kernel.Bin_prot.Type_class.t)
        end

        module Latest = V1
      end

      type ('g1, 'bulletproof_challenges) t =
            ('g1, 'bulletproof_challenges) Stable.V1.t =
        { sg : 'g1; old_bulletproof_challenges : 'bulletproof_challenges }

      val to_yojson :
           ('g1 -> Yojson.Safe.t)
        -> ('bulletproof_challenges -> Yojson.Safe.t)
        -> ('g1, 'bulletproof_challenges) t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'g1 Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'bulletproof_challenges Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('g1, 'bulletproof_challenges) t Ppx_deriving_yojson_runtime.error_or

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'g1)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'bulletproof_challenges)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('g1, 'bulletproof_challenges) t

      val sexp_of_t :
           ('g1 -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('bulletproof_challenges -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('g1, 'bulletproof_challenges) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val compare :
           ('g1 -> 'g1 -> int)
        -> ('bulletproof_challenges -> 'bulletproof_challenges -> int)
        -> ('g1, 'bulletproof_challenges) t
        -> ('g1, 'bulletproof_challenges) t
        -> int

      val to_hlist :
           ('g1, 'bulletproof_challenges) t
        -> (unit, 'g1 -> 'bulletproof_challenges -> unit) H_list.t

      val of_hlist :
           (unit, 'g1 -> 'bulletproof_challenges -> unit) H_list.t
        -> ('g1, 'bulletproof_challenges) t

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'g1 -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'bulletproof_challenges
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('g1, 'bulletproof_challenges) t
        -> Ppx_hash_lib.Std.Hash.state

      val equal :
           ('g1 -> 'g1 -> bool)
        -> ('bulletproof_challenges -> 'bulletproof_challenges -> bool)
        -> ('g1, 'bulletproof_challenges) t
        -> ('g1, 'bulletproof_challenges) t
        -> bool

      val to_field_elements :
           ('a, (('b, 'c) Pickles_types.Vector.t, 'd) Pickles_types.Vector.t) t
        -> g1:('a -> 'b list)
        -> 'b Core_kernel.Array.t

      val typ :
           ( 'a
           , 'b
           , 'c Snarky_backendless__.Checked.field
           , ( unit
             , unit
             , 'c Snarky_backendless__.Checked.field )
             Snarky_backendless__.Checked.t )
           Snarky_backendless__.Types.Typ.t
        -> ( 'd
           , 'e
           , 'c Snarky_backendless__.Checked.field )
           Snarky_backendless.Typ.t
        -> length:'f Pickles_types.Vector.nat
        -> ( ('a, ('d, 'f) Pickles_types.Vector.t) t
           , ('b, ('e, 'f) Pickles_types.Vector.t) t
           , 'c Snarky_backendless__.Checked.field )
           Snarky_backendless.Typ.t
    end

    module Stable : sig
      module V1 : sig
        type ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'bp_chals
             , 'index )
             t =
          { deferred_values :
              ( 'plonk
              , 'scalar_challenge
              , 'fp
              , 'fq
              , 'bp_chals
              , 'index )
              Deferred_values.t
          ; sponge_digest_before_evaluations : 'digest
          ; me_only : 'me_only
          }

        val to_yojson :
             ('plonk -> Yojson.Safe.t)
          -> ('scalar_challenge -> Yojson.Safe.t)
          -> ('fp -> Yojson.Safe.t)
          -> ('fq -> Yojson.Safe.t)
          -> ('me_only -> Yojson.Safe.t)
          -> ('digest -> Yojson.Safe.t)
          -> ('bp_chals -> Yojson.Safe.t)
          -> ('index -> Yojson.Safe.t)
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'bp_chals
             , 'index )
             t
          -> Yojson.Safe.t

        val of_yojson :
             (Yojson.Safe.t -> 'plonk Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'fp Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'me_only Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'digest Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'bp_chals Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'index Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'bp_chals
             , 'index )
             t
             Ppx_deriving_yojson_runtime.error_or

        val version : int

        val __versioned__ : unit

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'plonk)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'fp)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'me_only)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'digest)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'bp_chals)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'index)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'bp_chals
             , 'index )
             t

        val sexp_of_t :
             ('plonk -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('fp -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('me_only -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('digest -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('bp_chals -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('index -> Ppx_sexp_conv_lib.Sexp.t)
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'bp_chals
             , 'index )
             t
          -> Ppx_sexp_conv_lib.Sexp.t

        val compare :
             ('plonk -> 'plonk -> int)
          -> ('scalar_challenge -> 'scalar_challenge -> int)
          -> ('fp -> 'fp -> int)
          -> ('fq -> 'fq -> int)
          -> ('me_only -> 'me_only -> int)
          -> ('digest -> 'digest -> int)
          -> ('bp_chals -> 'bp_chals -> int)
          -> ('index -> 'index -> int)
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'bp_chals
             , 'index )
             t
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'bp_chals
             , 'index )
             t
          -> int

        val to_hlist :
             ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'bp_chals
             , 'index )
             t
          -> ( unit
             ,    ( 'plonk
                  , 'scalar_challenge
                  , 'fp
                  , 'fq
                  , 'bp_chals
                  , 'index )
                  Deferred_values.t
               -> 'digest
               -> 'me_only
               -> unit )
             H_list.t

        val of_hlist :
             ( unit
             ,    ( 'plonk
                  , 'scalar_challenge
                  , 'fp
                  , 'fq
                  , 'bp_chals
                  , 'index )
                  Deferred_values.t
               -> 'digest
               -> 'me_only
               -> unit )
             H_list.t
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'bp_chals
             , 'index )
             t

        val hash_fold_t :
             (   Ppx_hash_lib.Std.Hash.state
              -> 'plonk
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'scalar_challenge
              -> Ppx_hash_lib.Std.Hash.state)
          -> (Ppx_hash_lib.Std.Hash.state -> 'fp -> Ppx_hash_lib.Std.Hash.state)
          -> (Ppx_hash_lib.Std.Hash.state -> 'fq -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'me_only
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'digest
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'bp_chals
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'index
              -> Ppx_hash_lib.Std.Hash.state)
          -> Ppx_hash_lib.Std.Hash.state
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'bp_chals
             , 'index )
             t
          -> Ppx_hash_lib.Std.Hash.state

        val equal :
             ('plonk -> 'plonk -> bool)
          -> ('scalar_challenge -> 'scalar_challenge -> bool)
          -> ('fp -> 'fp -> bool)
          -> ('fq -> 'fq -> bool)
          -> ('me_only -> 'me_only -> bool)
          -> ('digest -> 'digest -> bool)
          -> ('bp_chals -> 'bp_chals -> bool)
          -> ('index -> 'index -> bool)
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'bp_chals
             , 'index )
             t
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'bp_chals
             , 'index )
             t
          -> bool

        module With_version : sig
          type ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'bp_chals
               , 'index )
               typ =
            ( 'plonk
            , 'scalar_challenge
            , 'fp
            , 'fq
            , 'me_only
            , 'digest
            , 'bp_chals
            , 'index )
            t

          val bin_shape_typ :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_typ :
               'plonk Core_kernel.Bin_prot.Size.sizer
            -> 'scalar_challenge Core_kernel.Bin_prot.Size.sizer
            -> 'fp Core_kernel.Bin_prot.Size.sizer
            -> 'fq Core_kernel.Bin_prot.Size.sizer
            -> 'me_only Core_kernel.Bin_prot.Size.sizer
            -> 'digest Core_kernel.Bin_prot.Size.sizer
            -> 'bp_chals Core_kernel.Bin_prot.Size.sizer
            -> 'index Core_kernel.Bin_prot.Size.sizer
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'bp_chals
               , 'index )
               typ
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_typ :
               'plonk Core_kernel.Bin_prot.Write.writer
            -> 'scalar_challenge Core_kernel.Bin_prot.Write.writer
            -> 'fp Core_kernel.Bin_prot.Write.writer
            -> 'fq Core_kernel.Bin_prot.Write.writer
            -> 'me_only Core_kernel.Bin_prot.Write.writer
            -> 'digest Core_kernel.Bin_prot.Write.writer
            -> 'bp_chals Core_kernel.Bin_prot.Write.writer
            -> 'index Core_kernel.Bin_prot.Write.writer
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'bp_chals
               , 'index )
               typ
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_typ :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> 'd Core_kernel.Bin_prot.Type_class.writer
            -> 'e Core_kernel.Bin_prot.Type_class.writer
            -> 'f Core_kernel.Bin_prot.Type_class.writer
            -> 'g Core_kernel.Bin_prot.Type_class.writer
            -> 'h Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) typ
               Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_typ__ :
               'plonk Core_kernel.Bin_prot.Read.reader
            -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
            -> 'fp Core_kernel.Bin_prot.Read.reader
            -> 'fq Core_kernel.Bin_prot.Read.reader
            -> 'me_only Core_kernel.Bin_prot.Read.reader
            -> 'digest Core_kernel.Bin_prot.Read.reader
            -> 'bp_chals Core_kernel.Bin_prot.Read.reader
            -> 'index Core_kernel.Bin_prot.Read.reader
            -> (   int
                -> ( 'plonk
                   , 'scalar_challenge
                   , 'fp
                   , 'fq
                   , 'me_only
                   , 'digest
                   , 'bp_chals
                   , 'index )
                   typ)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_typ :
               'plonk Core_kernel.Bin_prot.Read.reader
            -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
            -> 'fp Core_kernel.Bin_prot.Read.reader
            -> 'fq Core_kernel.Bin_prot.Read.reader
            -> 'me_only Core_kernel.Bin_prot.Read.reader
            -> 'digest Core_kernel.Bin_prot.Read.reader
            -> 'bp_chals Core_kernel.Bin_prot.Read.reader
            -> 'index Core_kernel.Bin_prot.Read.reader
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'bp_chals
               , 'index )
               typ
               Core_kernel.Bin_prot.Read.reader

          val bin_reader_typ :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> 'd Core_kernel.Bin_prot.Type_class.reader
            -> 'e Core_kernel.Bin_prot.Type_class.reader
            -> 'f Core_kernel.Bin_prot.Type_class.reader
            -> 'g Core_kernel.Bin_prot.Type_class.reader
            -> 'h Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) typ
               Core_kernel.Bin_prot.Type_class.reader

          val bin_typ :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> 'd Core_kernel.Bin_prot.Type_class.t
            -> 'e Core_kernel.Bin_prot.Type_class.t
            -> 'f Core_kernel.Bin_prot.Type_class.t
            -> 'g Core_kernel.Bin_prot.Type_class.t
            -> 'h Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) typ
               Core_kernel.Bin_prot.Type_class.t

          type ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'bp_chals
               , 'index )
               t =
            { version : int
            ; t :
                ( 'plonk
                , 'scalar_challenge
                , 'fp
                , 'fq
                , 'me_only
                , 'digest
                , 'bp_chals
                , 'index )
                typ
            }

          val bin_shape_t :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_t :
               'plonk Core_kernel.Bin_prot.Size.sizer
            -> 'scalar_challenge Core_kernel.Bin_prot.Size.sizer
            -> 'fp Core_kernel.Bin_prot.Size.sizer
            -> 'fq Core_kernel.Bin_prot.Size.sizer
            -> 'me_only Core_kernel.Bin_prot.Size.sizer
            -> 'digest Core_kernel.Bin_prot.Size.sizer
            -> 'bp_chals Core_kernel.Bin_prot.Size.sizer
            -> 'index Core_kernel.Bin_prot.Size.sizer
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'bp_chals
               , 'index )
               t
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_t :
               'plonk Core_kernel.Bin_prot.Write.writer
            -> 'scalar_challenge Core_kernel.Bin_prot.Write.writer
            -> 'fp Core_kernel.Bin_prot.Write.writer
            -> 'fq Core_kernel.Bin_prot.Write.writer
            -> 'me_only Core_kernel.Bin_prot.Write.writer
            -> 'digest Core_kernel.Bin_prot.Write.writer
            -> 'bp_chals Core_kernel.Bin_prot.Write.writer
            -> 'index Core_kernel.Bin_prot.Write.writer
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'bp_chals
               , 'index )
               t
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_t :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> 'd Core_kernel.Bin_prot.Type_class.writer
            -> 'e Core_kernel.Bin_prot.Type_class.writer
            -> 'f Core_kernel.Bin_prot.Type_class.writer
            -> 'g Core_kernel.Bin_prot.Type_class.writer
            -> 'h Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
               Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_t__ :
               'plonk Core_kernel.Bin_prot.Read.reader
            -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
            -> 'fp Core_kernel.Bin_prot.Read.reader
            -> 'fq Core_kernel.Bin_prot.Read.reader
            -> 'me_only Core_kernel.Bin_prot.Read.reader
            -> 'digest Core_kernel.Bin_prot.Read.reader
            -> 'bp_chals Core_kernel.Bin_prot.Read.reader
            -> 'index Core_kernel.Bin_prot.Read.reader
            -> (   int
                -> ( 'plonk
                   , 'scalar_challenge
                   , 'fp
                   , 'fq
                   , 'me_only
                   , 'digest
                   , 'bp_chals
                   , 'index )
                   t)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_t :
               'plonk Core_kernel.Bin_prot.Read.reader
            -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
            -> 'fp Core_kernel.Bin_prot.Read.reader
            -> 'fq Core_kernel.Bin_prot.Read.reader
            -> 'me_only Core_kernel.Bin_prot.Read.reader
            -> 'digest Core_kernel.Bin_prot.Read.reader
            -> 'bp_chals Core_kernel.Bin_prot.Read.reader
            -> 'index Core_kernel.Bin_prot.Read.reader
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'bp_chals
               , 'index )
               t
               Core_kernel.Bin_prot.Read.reader

          val bin_reader_t :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> 'd Core_kernel.Bin_prot.Type_class.reader
            -> 'e Core_kernel.Bin_prot.Type_class.reader
            -> 'f Core_kernel.Bin_prot.Type_class.reader
            -> 'g Core_kernel.Bin_prot.Type_class.reader
            -> 'h Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
               Core_kernel.Bin_prot.Type_class.reader

          val bin_t :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> 'd Core_kernel.Bin_prot.Type_class.t
            -> 'e Core_kernel.Bin_prot.Type_class.t
            -> 'f Core_kernel.Bin_prot.Type_class.t
            -> 'g Core_kernel.Bin_prot.Type_class.t
            -> 'h Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
               Core_kernel.Bin_prot.Type_class.t

          val create :
               ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) typ
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
        end

        val bin_read_t :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> 'd Core_kernel.Bin_prot.Read.reader
          -> 'e Core_kernel.Bin_prot.Read.reader
          -> 'f Core_kernel.Bin_prot.Read.reader
          -> 'g Core_kernel.Bin_prot.Read.reader
          -> 'h Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t

        val __bin_read_t__ :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> 'd Core_kernel.Bin_prot.Read.reader
          -> 'e Core_kernel.Bin_prot.Read.reader
          -> 'f Core_kernel.Bin_prot.Read.reader
          -> 'g Core_kernel.Bin_prot.Read.reader
          -> 'h Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> int
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t

        val bin_size_t :
             'a Core_kernel.Bin_prot.Size.sizer
          -> 'b Core_kernel.Bin_prot.Size.sizer
          -> 'c Core_kernel.Bin_prot.Size.sizer
          -> 'd Core_kernel.Bin_prot.Size.sizer
          -> 'e Core_kernel.Bin_prot.Size.sizer
          -> 'f Core_kernel.Bin_prot.Size.sizer
          -> 'g Core_kernel.Bin_prot.Size.sizer
          -> 'h Core_kernel.Bin_prot.Size.sizer
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
          -> int

        val bin_write_t :
             'a Core_kernel.Bin_prot.Write.writer
          -> 'b Core_kernel.Bin_prot.Write.writer
          -> 'c Core_kernel.Bin_prot.Write.writer
          -> 'd Core_kernel.Bin_prot.Write.writer
          -> 'e Core_kernel.Bin_prot.Write.writer
          -> 'f Core_kernel.Bin_prot.Write.writer
          -> 'g Core_kernel.Bin_prot.Write.writer
          -> 'h Core_kernel.Bin_prot.Write.writer
          -> Bin_prot.Common.buf
          -> pos:Bin_prot.Common.pos
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
          -> Bin_prot.Common.pos

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
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
          -> 'f Core_kernel.Bin_prot.Type_class.reader
          -> 'g Core_kernel.Bin_prot.Type_class.reader
          -> 'h Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
             Core_kernel.Bin_prot.Type_class.reader

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> 'd Core_kernel.Bin_prot.Type_class.writer
          -> 'e Core_kernel.Bin_prot.Type_class.writer
          -> 'f Core_kernel.Bin_prot.Type_class.writer
          -> 'g Core_kernel.Bin_prot.Type_class.writer
          -> 'h Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
             Core_kernel.Bin_prot.Type_class.writer

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> 'd Core_kernel.Bin_prot.Type_class.t
          -> 'e Core_kernel.Bin_prot.Type_class.t
          -> 'f Core_kernel.Bin_prot.Type_class.t
          -> 'g Core_kernel.Bin_prot.Type_class.t
          -> 'h Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
             Core_kernel.Bin_prot.Type_class.t

        val __ :
          (   'a Core_kernel.Bin_prot.Read.reader
           -> 'b Core_kernel.Bin_prot.Read.reader
           -> 'c Core_kernel.Bin_prot.Read.reader
           -> 'd Core_kernel.Bin_prot.Read.reader
           -> 'e Core_kernel.Bin_prot.Read.reader
           -> 'f Core_kernel.Bin_prot.Read.reader
           -> 'g Core_kernel.Bin_prot.Read.reader
           -> 'h Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t)
          * (   'i Core_kernel.Bin_prot.Read.reader
             -> 'j Core_kernel.Bin_prot.Read.reader
             -> 'k Core_kernel.Bin_prot.Read.reader
             -> 'l Core_kernel.Bin_prot.Read.reader
             -> 'm Core_kernel.Bin_prot.Read.reader
             -> 'n Core_kernel.Bin_prot.Read.reader
             -> 'o Core_kernel.Bin_prot.Read.reader
             -> 'p Core_kernel.Bin_prot.Read.reader
             -> Bin_prot.Common.buf
             -> pos_ref:Bin_prot.Common.pos_ref
             -> int
             -> ('i, 'j, 'k, 'l, 'm, 'n, 'o, 'p) t)
          * (   'q Core_kernel.Bin_prot.Size.sizer
             -> 'r Core_kernel.Bin_prot.Size.sizer
             -> 's Core_kernel.Bin_prot.Size.sizer
             -> 't Core_kernel.Bin_prot.Size.sizer
             -> 'u Core_kernel.Bin_prot.Size.sizer
             -> 'v Core_kernel.Bin_prot.Size.sizer
             -> 'w Core_kernel.Bin_prot.Size.sizer
             -> 'x Core_kernel.Bin_prot.Size.sizer
             -> ('q, 'r, 's, 't, 'u, 'v, 'w, 'x) t
             -> int)
          * (   'y Core_kernel.Bin_prot.Write.writer
             -> 'z Core_kernel.Bin_prot.Write.writer
             -> 'a1 Core_kernel.Bin_prot.Write.writer
             -> 'b1 Core_kernel.Bin_prot.Write.writer
             -> 'c1 Core_kernel.Bin_prot.Write.writer
             -> 'd1 Core_kernel.Bin_prot.Write.writer
             -> 'e1 Core_kernel.Bin_prot.Write.writer
             -> 'f1 Core_kernel.Bin_prot.Write.writer
             -> Bin_prot.Common.buf
             -> pos:Bin_prot.Common.pos
             -> ('y, 'z, 'a1, 'b1, 'c1, 'd1, 'e1, 'f1) t
             -> Bin_prot.Common.pos)
          * (   Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t)
          * (   'g1 Core_kernel.Bin_prot.Type_class.reader
             -> 'h1 Core_kernel.Bin_prot.Type_class.reader
             -> 'i1 Core_kernel.Bin_prot.Type_class.reader
             -> 'j1 Core_kernel.Bin_prot.Type_class.reader
             -> 'k1 Core_kernel.Bin_prot.Type_class.reader
             -> 'l1 Core_kernel.Bin_prot.Type_class.reader
             -> 'm1 Core_kernel.Bin_prot.Type_class.reader
             -> 'n1 Core_kernel.Bin_prot.Type_class.reader
             -> ('g1, 'h1, 'i1, 'j1, 'k1, 'l1, 'm1, 'n1) t
                Core_kernel.Bin_prot.Type_class.reader)
          * (   'o1 Core_kernel.Bin_prot.Type_class.writer
             -> 'p1 Core_kernel.Bin_prot.Type_class.writer
             -> 'q1 Core_kernel.Bin_prot.Type_class.writer
             -> 'r1 Core_kernel.Bin_prot.Type_class.writer
             -> 's1 Core_kernel.Bin_prot.Type_class.writer
             -> 't1 Core_kernel.Bin_prot.Type_class.writer
             -> 'u1 Core_kernel.Bin_prot.Type_class.writer
             -> 'v1 Core_kernel.Bin_prot.Type_class.writer
             -> ('o1, 'p1, 'q1, 'r1, 's1, 't1, 'u1, 'v1) t
                Core_kernel.Bin_prot.Type_class.writer)
          * (   'w1 Core_kernel.Bin_prot.Type_class.t
             -> 'x1 Core_kernel.Bin_prot.Type_class.t
             -> 'y1 Core_kernel.Bin_prot.Type_class.t
             -> 'z1 Core_kernel.Bin_prot.Type_class.t
             -> 'a2 Core_kernel.Bin_prot.Type_class.t
             -> 'b2 Core_kernel.Bin_prot.Type_class.t
             -> 'c2 Core_kernel.Bin_prot.Type_class.t
             -> 'd2 Core_kernel.Bin_prot.Type_class.t
             -> ('w1, 'x1, 'y1, 'z1, 'a2, 'b2, 'c2, 'd2) t
                Core_kernel.Bin_prot.Type_class.t)
      end

      module Latest = V1
    end

    type ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'bp_chals
         , 'index )
         t =
          ( 'plonk
          , 'scalar_challenge
          , 'fp
          , 'fq
          , 'me_only
          , 'digest
          , 'bp_chals
          , 'index )
          Stable.V1.t =
      { deferred_values :
          ( 'plonk
          , 'scalar_challenge
          , 'fp
          , 'fq
          , 'bp_chals
          , 'index )
          Deferred_values.t
      ; sponge_digest_before_evaluations : 'digest
      ; me_only : 'me_only
      }

    val to_yojson :
         ('plonk -> Yojson.Safe.t)
      -> ('scalar_challenge -> Yojson.Safe.t)
      -> ('fp -> Yojson.Safe.t)
      -> ('fq -> Yojson.Safe.t)
      -> ('me_only -> Yojson.Safe.t)
      -> ('digest -> Yojson.Safe.t)
      -> ('bp_chals -> Yojson.Safe.t)
      -> ('index -> Yojson.Safe.t)
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'bp_chals
         , 'index )
         t
      -> Yojson.Safe.t

    val of_yojson :
         (Yojson.Safe.t -> 'plonk Ppx_deriving_yojson_runtime.error_or)
      -> (   Yojson.Safe.t
          -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'fp Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'me_only Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'digest Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'bp_chals Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'index Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'bp_chals
         , 'index )
         t
         Ppx_deriving_yojson_runtime.error_or

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'plonk)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'fp)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'me_only)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'digest)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'bp_chals)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'index)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'bp_chals
         , 'index )
         t

    val sexp_of_t :
         ('plonk -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('fp -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('me_only -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('digest -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('bp_chals -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('index -> Ppx_sexp_conv_lib.Sexp.t)
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'bp_chals
         , 'index )
         t
      -> Ppx_sexp_conv_lib.Sexp.t

    val compare :
         ('plonk -> 'plonk -> int)
      -> ('scalar_challenge -> 'scalar_challenge -> int)
      -> ('fp -> 'fp -> int)
      -> ('fq -> 'fq -> int)
      -> ('me_only -> 'me_only -> int)
      -> ('digest -> 'digest -> int)
      -> ('bp_chals -> 'bp_chals -> int)
      -> ('index -> 'index -> int)
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'bp_chals
         , 'index )
         t
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'bp_chals
         , 'index )
         t
      -> int

    val to_hlist :
         ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'bp_chals
         , 'index )
         t
      -> ( unit
         ,    ( 'plonk
              , 'scalar_challenge
              , 'fp
              , 'fq
              , 'bp_chals
              , 'index )
              Deferred_values.t
           -> 'digest
           -> 'me_only
           -> unit )
         H_list.t

    val of_hlist :
         ( unit
         ,    ( 'plonk
              , 'scalar_challenge
              , 'fp
              , 'fq
              , 'bp_chals
              , 'index )
              Deferred_values.t
           -> 'digest
           -> 'me_only
           -> unit )
         H_list.t
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'bp_chals
         , 'index )
         t

    val hash_fold_t :
         (Ppx_hash_lib.Std.Hash.state -> 'plonk -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'scalar_challenge
          -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'fp -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'fq -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'me_only
          -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'digest -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'bp_chals
          -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'index -> Ppx_hash_lib.Std.Hash.state)
      -> Ppx_hash_lib.Std.Hash.state
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'bp_chals
         , 'index )
         t
      -> Ppx_hash_lib.Std.Hash.state

    val equal :
         ('plonk -> 'plonk -> bool)
      -> ('scalar_challenge -> 'scalar_challenge -> bool)
      -> ('fp -> 'fp -> bool)
      -> ('fq -> 'fq -> bool)
      -> ('me_only -> 'me_only -> bool)
      -> ('digest -> 'digest -> bool)
      -> ('bp_chals -> 'bp_chals -> bool)
      -> ('index -> 'index -> bool)
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'bp_chals
         , 'index )
         t
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'bp_chals
         , 'index )
         t
      -> bool

    module Minimal : sig
      type ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t =
        ( ('challenge, 'scalar_challenge) Deferred_values.Plonk.Minimal.t
        , 'scalar_challenge
        , 'fp
        , 'fq
        , 'me_only
        , 'digest
        , 'bp_chals
        , 'index )
        Stable.V1.t

      val to_yojson :
           ('challenge -> Yojson.Safe.t)
        -> ('scalar_challenge -> Yojson.Safe.t)
        -> ('fp -> Yojson.Safe.t)
        -> ('fq -> Yojson.Safe.t)
        -> ('me_only -> Yojson.Safe.t)
        -> ('digest -> Yojson.Safe.t)
        -> ('bp_chals -> Yojson.Safe.t)
        -> ('index -> Yojson.Safe.t)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'challenge Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'fp Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'me_only Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'digest Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'bp_chals Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'index Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
           Ppx_deriving_yojson_runtime.error_or

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fp)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'me_only)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'digest)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'bp_chals)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'index)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t

      val sexp_of_t :
           ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fp -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('me_only -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('digest -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('bp_chals -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('index -> Ppx_sexp_conv_lib.Sexp.t)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
        -> Ppx_sexp_conv_lib.Sexp.t

      val compare :
           ('challenge -> 'challenge -> int)
        -> ('scalar_challenge -> 'scalar_challenge -> int)
        -> ('fp -> 'fp -> int)
        -> ('fq -> 'fq -> int)
        -> ('me_only -> 'me_only -> int)
        -> ('digest -> 'digest -> int)
        -> ('bp_chals -> 'bp_chals -> int)
        -> ('index -> 'index -> int)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
        -> int

      val hash_fold_t :
           (   Ppx_hash_lib.Std.Hash.state
            -> 'challenge
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'scalar_challenge
            -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'fp -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'fq -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'me_only
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'digest
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'bp_chals
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'index
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
        -> Ppx_hash_lib.Std.Hash.state

      val equal :
           ('challenge -> 'challenge -> bool)
        -> ('scalar_challenge -> 'scalar_challenge -> bool)
        -> ('fp -> 'fp -> bool)
        -> ('fq -> 'fq -> bool)
        -> ('me_only -> 'me_only -> bool)
        -> ('digest -> 'digest -> bool)
        -> ('bp_chals -> 'bp_chals -> bool)
        -> ('index -> 'index -> bool)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
        -> bool
    end

    module In_circuit : sig
      type ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t =
        ( ('challenge, 'scalar_challenge, 'fp) Deferred_values.Plonk.In_circuit.t
        , 'scalar_challenge
        , 'fp
        , 'fq
        , 'me_only
        , 'digest
        , 'bp_chals
        , 'index )
        Stable.V1.t

      val to_yojson :
           ('challenge -> Yojson.Safe.t)
        -> ('scalar_challenge -> Yojson.Safe.t)
        -> ('fp -> Yojson.Safe.t)
        -> ('fq -> Yojson.Safe.t)
        -> ('me_only -> Yojson.Safe.t)
        -> ('digest -> Yojson.Safe.t)
        -> ('bp_chals -> Yojson.Safe.t)
        -> ('index -> Yojson.Safe.t)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'challenge Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'fp Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'me_only Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'digest Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'bp_chals Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'index Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
           Ppx_deriving_yojson_runtime.error_or

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fp)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'me_only)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'digest)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'bp_chals)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'index)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t

      val sexp_of_t :
           ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fp -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('me_only -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('digest -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('bp_chals -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('index -> Ppx_sexp_conv_lib.Sexp.t)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
        -> Ppx_sexp_conv_lib.Sexp.t

      val compare :
           ('challenge -> 'challenge -> int)
        -> ('scalar_challenge -> 'scalar_challenge -> int)
        -> ('fp -> 'fp -> int)
        -> ('fq -> 'fq -> int)
        -> ('me_only -> 'me_only -> int)
        -> ('digest -> 'digest -> int)
        -> ('bp_chals -> 'bp_chals -> int)
        -> ('index -> 'index -> int)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
        -> int

      val hash_fold_t :
           (   Ppx_hash_lib.Std.Hash.state
            -> 'challenge
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'scalar_challenge
            -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'fp -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'fq -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'me_only
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'digest
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'bp_chals
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'index
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
        -> Ppx_hash_lib.Std.Hash.state

      val equal :
           ('challenge -> 'challenge -> bool)
        -> ('scalar_challenge -> 'scalar_challenge -> bool)
        -> ('fp -> 'fp -> bool)
        -> ('fq -> 'fq -> bool)
        -> ('me_only -> 'me_only -> bool)
        -> ('digest -> 'digest -> bool)
        -> ('bp_chals -> 'bp_chals -> bool)
        -> ('index -> 'index -> bool)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'bp_chals
           , 'index )
           t
        -> bool

      val to_hlist :
           ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) Stable.V1.t
        -> ( unit
           , ('a, 'b, 'c, 'd, 'g, 'h) Deferred_values.t -> 'f -> 'e -> unit )
           H_list.t

      val of_hlist :
           ( unit
           , ('a, 'b, 'c, 'd, 'e, 'f) Deferred_values.t -> 'g -> 'h -> unit )
           H_list.t
        -> ('a, 'b, 'c, 'd, 'h, 'g, 'e, 'f) Stable.V1.t

      val typ :
           challenge:
             ( 'a
             , 'b
             , 'f Snarky_backendless__.Checked.field
             , ( unit
               , unit
               , 'f Snarky_backendless__.Checked.field )
               Snarky_backendless__.Checked.t )
             Snarky_backendless__.Types.Typ.t
        -> scalar_challenge:
             ( 'c
             , 'd
             , 'f Snarky_backendless__.Checked.field )
             Snarky_backendless.Typ.t
        -> ('fp, 'e, 'f) Snarky_backendless.Typ.t
        -> 'g
        -> ( 'h
           , 'i
           , 'f Snarky_backendless__.Checked.field
             Snarky_backendless__.Checked.field
             Snarky_backendless__.Checked.field
           , ( unit
             , unit
             , 'f Snarky_backendless__.Checked.field
               Snarky_backendless__.Checked.field
               Snarky_backendless__.Checked.field )
             Snarky_backendless__.Checked.t )
           Snarky_backendless__.Types.Typ.t
        -> ( 'j
           , 'k
           , 'f Snarky_backendless__.Checked.field
             Snarky_backendless__.Checked.field
             Snarky_backendless__.Checked.field
           , ( unit
             , unit
             , 'f Snarky_backendless__.Checked.field
               Snarky_backendless__.Checked.field
               Snarky_backendless__.Checked.field )
             Snarky_backendless__.Checked.t )
           Snarky_backendless__.Types.Typ.t
        -> ( 'l
           , 'm
           , 'f Snarky_backendless__.Checked.field
             Snarky_backendless__.Checked.field
           , ( unit
             , unit
             , 'f Snarky_backendless__.Checked.field
               Snarky_backendless__.Checked.field )
             Snarky_backendless__.Checked.t )
           Snarky_backendless__.Types.Typ.t
        -> ( ( ( 'a
               , 'c Pickles_types.Scalar_challenge.t
               , 'fp )
               Deferred_values.Plonk.In_circuit.t
             , 'c Pickles_types.Scalar_challenge.t
             , 'fp
             , 'n
             , 'h
             , 'j
             , ( 'c Pickles_types.Scalar_challenge.t Bulletproof_challenge.t
               , Pickles_types__Nat.z Backend.Tick.Rounds.plus_n )
               Pickles_types.Vector.t
             , 'l )
             Stable.V1.t
           , ( ( 'b
               , 'd Pickles_types.Scalar_challenge.t
               , 'e )
               Deferred_values.Plonk.In_circuit.t
             , 'd Pickles_types.Scalar_challenge.t
             , 'e
             , 'o
             , 'i
             , 'k
             , ( 'd Pickles_types.Scalar_challenge.t Bulletproof_challenge.t
               , Pickles_types__Nat.z Backend.Tick.Rounds.plus_n )
               Pickles_types.Vector.t
             , 'm )
             Stable.V1.t
           , 'f Snarky_backendless__.Checked.field
             Snarky_backendless__.Checked.field
             Snarky_backendless__.Checked.field )
           Snarky_backendless.Typ.t
    end

    val to_minimal :
         ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) In_circuit.t
      -> ('a, 'b, 'c, 'i, 'e, 'f, 'g, 'h) Minimal.t
  end

  module Pass_through : sig
    type ('g, 's, 'sg, 'bulletproof_challenges) t =
      { app_state : 's
      ; dlog_plonk_index :
          'g Pickles_types.Dlog_plonk_types.Poly_comm.Without_degree_bound.t
          Pickles_types.Plonk_verification_key_evals.t
      ; sg : 'sg
      ; old_bulletproof_challenges : 'bulletproof_challenges
      }

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'g)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 's)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'sg)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'bulletproof_challenges)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> ('g, 's, 'sg, 'bulletproof_challenges) t

    val sexp_of_t :
         ('g -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('s -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('sg -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('bulletproof_challenges -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('g, 's, 'sg, 'bulletproof_challenges) t
      -> Ppx_sexp_conv_lib.Sexp.t

    val to_field_elements :
         ( 'a
         , 'b
         , ('c, 'd) Pickles_types.Vector.t
         , (('e, 'f) Pickles_types.Vector.t, 'g) Pickles_types.Vector.t )
         t
      -> app_state:('b -> 'e Core_kernel.Array.t)
      -> comm:
           (   'a Pickles_types.Dlog_plonk_types.Poly_comm.Without_degree_bound.t
            -> 'e Core_kernel.Array.t)
      -> g:('c -> 'e list)
      -> 'e Core_kernel.Array.t

    val to_field_elements_without_index :
         ( 'a
         , 'b
         , ('c, 'd) Pickles_types.Vector.t
         , (('e, 'f) Pickles_types.Vector.t, 'g) Pickles_types.Vector.t )
         t
      -> app_state:('b -> 'e Core_kernel.Array.t)
      -> g:('c -> 'e list)
      -> 'e Core_kernel.Array.t

    val to_hlist :
         ('a, 'b, 'c, 'd) t
      -> ( 'e
         ,    'b
           -> 'a Pickles_types.Dlog_plonk_types.Poly_comm.Without_degree_bound.t
              Pickles_types.Plonk_verification_key_evals.t
           -> 'c
           -> 'd
           -> 'e )
         Snarky_backendless.H_list.t

    val of_hlist :
         ( unit
         ,    'a
           -> 'b Pickles_types.Dlog_plonk_types.Poly_comm.Without_degree_bound.t
              Pickles_types.Plonk_verification_key_evals.t
           -> 'c
           -> 'd
           -> unit )
         Snarky_backendless.H_list.t
      -> ('b, 'a, 'c, 'd) t

    val typ :
         ( 'a Pickles_types.Dlog_plonk_types.Poly_comm.Without_degree_bound.t
         , 'b Pickles_types.Dlog_plonk_types.Poly_comm.Without_degree_bound.t
         , 'c Snarky_backendless__.Checked.field
           Snarky_backendless__.Checked.field
         , ( unit
           , unit
           , 'c Snarky_backendless__.Checked.field
             Snarky_backendless__.Checked.field )
           Snarky_backendless__.Checked.t )
         Snarky_backendless__.Types.Typ.t
      -> ( 'd
         , 'e
         , 'c Snarky_backendless__.Checked.field )
         Snarky_backendless.Typ.t
      -> ( 'f
         , 'g
         , 'c Snarky_backendless__.Checked.field
         , ( unit
           , unit
           , 'c Snarky_backendless__.Checked.field )
           Snarky_backendless__.Checked.t )
         Snarky_backendless__.Types.Typ.t
      -> ( 'h
         , 'i
         , 'c Snarky_backendless__.Checked.field
         , ( unit
           , unit
           , 'c Snarky_backendless__.Checked.field )
           Snarky_backendless__.Checked.t )
         Snarky_backendless__.Types.Typ.t
      -> 'j Pickles_types.Vector.nat
      -> ( ('a, 'f, ('d, 'j) Pickles_types.Vector.t, 'h) t
         , ('b, 'g, ('e, 'j) Pickles_types.Vector.t, 'i) t
         , 'c Snarky_backendless__.Checked.field )
         Snarky_backendless.Typ.t
  end

  module Statement : sig
    module Stable : sig
      module V1 : sig
        type ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'pass_through
             , 'bp_chals
             , 'index )
             t =
          { proof_state :
              ( 'plonk
              , 'scalar_challenge
              , 'fp
              , 'fq
              , 'me_only
              , 'digest
              , 'bp_chals
              , 'index )
              Proof_state.t
          ; pass_through : 'pass_through
          }

        val to_yojson :
             ('plonk -> Yojson.Safe.t)
          -> ('scalar_challenge -> Yojson.Safe.t)
          -> ('fp -> Yojson.Safe.t)
          -> ('fq -> Yojson.Safe.t)
          -> ('me_only -> Yojson.Safe.t)
          -> ('digest -> Yojson.Safe.t)
          -> ('pass_through -> Yojson.Safe.t)
          -> ('bp_chals -> Yojson.Safe.t)
          -> ('index -> Yojson.Safe.t)
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'pass_through
             , 'bp_chals
             , 'index )
             t
          -> Yojson.Safe.t

        val of_yojson :
             (Yojson.Safe.t -> 'plonk Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'fp Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'me_only Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'digest Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'pass_through Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'bp_chals Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'index Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'pass_through
             , 'bp_chals
             , 'index )
             t
             Ppx_deriving_yojson_runtime.error_or

        val version : int

        val __versioned__ : unit

        val compare :
             ('plonk -> 'plonk -> int)
          -> ('scalar_challenge -> 'scalar_challenge -> int)
          -> ('fp -> 'fp -> int)
          -> ('fq -> 'fq -> int)
          -> ('me_only -> 'me_only -> int)
          -> ('digest -> 'digest -> int)
          -> ('pass_through -> 'pass_through -> int)
          -> ('bp_chals -> 'bp_chals -> int)
          -> ('index -> 'index -> int)
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'pass_through
             , 'bp_chals
             , 'index )
             t
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'pass_through
             , 'bp_chals
             , 'index )
             t
          -> int

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'plonk)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'fp)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'me_only)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'digest)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'pass_through)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'bp_chals)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'index)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'pass_through
             , 'bp_chals
             , 'index )
             t

        val sexp_of_t :
             ('plonk -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('fp -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('me_only -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('digest -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('pass_through -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('bp_chals -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('index -> Ppx_sexp_conv_lib.Sexp.t)
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'pass_through
             , 'bp_chals
             , 'index )
             t
          -> Ppx_sexp_conv_lib.Sexp.t

        val hash_fold_t :
             (   Ppx_hash_lib.Std.Hash.state
              -> 'plonk
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'scalar_challenge
              -> Ppx_hash_lib.Std.Hash.state)
          -> (Ppx_hash_lib.Std.Hash.state -> 'fp -> Ppx_hash_lib.Std.Hash.state)
          -> (Ppx_hash_lib.Std.Hash.state -> 'fq -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'me_only
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'digest
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'pass_through
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'bp_chals
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'index
              -> Ppx_hash_lib.Std.Hash.state)
          -> Ppx_hash_lib.Std.Hash.state
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'pass_through
             , 'bp_chals
             , 'index )
             t
          -> Ppx_hash_lib.Std.Hash.state

        val equal :
             ('plonk -> 'plonk -> bool)
          -> ('scalar_challenge -> 'scalar_challenge -> bool)
          -> ('fp -> 'fp -> bool)
          -> ('fq -> 'fq -> bool)
          -> ('me_only -> 'me_only -> bool)
          -> ('digest -> 'digest -> bool)
          -> ('pass_through -> 'pass_through -> bool)
          -> ('bp_chals -> 'bp_chals -> bool)
          -> ('index -> 'index -> bool)
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'pass_through
             , 'bp_chals
             , 'index )
             t
          -> ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'fq
             , 'me_only
             , 'digest
             , 'pass_through
             , 'bp_chals
             , 'index )
             t
          -> bool

        module With_version : sig
          type ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               typ =
            ( 'plonk
            , 'scalar_challenge
            , 'fp
            , 'fq
            , 'me_only
            , 'digest
            , 'pass_through
            , 'bp_chals
            , 'index )
            t

          val bin_shape_typ :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_typ :
               'plonk Core_kernel.Bin_prot.Size.sizer
            -> 'scalar_challenge Core_kernel.Bin_prot.Size.sizer
            -> 'fp Core_kernel.Bin_prot.Size.sizer
            -> 'fq Core_kernel.Bin_prot.Size.sizer
            -> 'me_only Core_kernel.Bin_prot.Size.sizer
            -> 'digest Core_kernel.Bin_prot.Size.sizer
            -> 'pass_through Core_kernel.Bin_prot.Size.sizer
            -> 'bp_chals Core_kernel.Bin_prot.Size.sizer
            -> 'index Core_kernel.Bin_prot.Size.sizer
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               typ
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_typ :
               'plonk Core_kernel.Bin_prot.Write.writer
            -> 'scalar_challenge Core_kernel.Bin_prot.Write.writer
            -> 'fp Core_kernel.Bin_prot.Write.writer
            -> 'fq Core_kernel.Bin_prot.Write.writer
            -> 'me_only Core_kernel.Bin_prot.Write.writer
            -> 'digest Core_kernel.Bin_prot.Write.writer
            -> 'pass_through Core_kernel.Bin_prot.Write.writer
            -> 'bp_chals Core_kernel.Bin_prot.Write.writer
            -> 'index Core_kernel.Bin_prot.Write.writer
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               typ
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_typ :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> 'd Core_kernel.Bin_prot.Type_class.writer
            -> 'e Core_kernel.Bin_prot.Type_class.writer
            -> 'f Core_kernel.Bin_prot.Type_class.writer
            -> 'g Core_kernel.Bin_prot.Type_class.writer
            -> 'h Core_kernel.Bin_prot.Type_class.writer
            -> 'i Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) typ
               Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_typ__ :
               'plonk Core_kernel.Bin_prot.Read.reader
            -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
            -> 'fp Core_kernel.Bin_prot.Read.reader
            -> 'fq Core_kernel.Bin_prot.Read.reader
            -> 'me_only Core_kernel.Bin_prot.Read.reader
            -> 'digest Core_kernel.Bin_prot.Read.reader
            -> 'pass_through Core_kernel.Bin_prot.Read.reader
            -> 'bp_chals Core_kernel.Bin_prot.Read.reader
            -> 'index Core_kernel.Bin_prot.Read.reader
            -> (   int
                -> ( 'plonk
                   , 'scalar_challenge
                   , 'fp
                   , 'fq
                   , 'me_only
                   , 'digest
                   , 'pass_through
                   , 'bp_chals
                   , 'index )
                   typ)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_typ :
               'plonk Core_kernel.Bin_prot.Read.reader
            -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
            -> 'fp Core_kernel.Bin_prot.Read.reader
            -> 'fq Core_kernel.Bin_prot.Read.reader
            -> 'me_only Core_kernel.Bin_prot.Read.reader
            -> 'digest Core_kernel.Bin_prot.Read.reader
            -> 'pass_through Core_kernel.Bin_prot.Read.reader
            -> 'bp_chals Core_kernel.Bin_prot.Read.reader
            -> 'index Core_kernel.Bin_prot.Read.reader
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               typ
               Core_kernel.Bin_prot.Read.reader

          val bin_reader_typ :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> 'd Core_kernel.Bin_prot.Type_class.reader
            -> 'e Core_kernel.Bin_prot.Type_class.reader
            -> 'f Core_kernel.Bin_prot.Type_class.reader
            -> 'g Core_kernel.Bin_prot.Type_class.reader
            -> 'h Core_kernel.Bin_prot.Type_class.reader
            -> 'i Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) typ
               Core_kernel.Bin_prot.Type_class.reader

          val bin_typ :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> 'd Core_kernel.Bin_prot.Type_class.t
            -> 'e Core_kernel.Bin_prot.Type_class.t
            -> 'f Core_kernel.Bin_prot.Type_class.t
            -> 'g Core_kernel.Bin_prot.Type_class.t
            -> 'h Core_kernel.Bin_prot.Type_class.t
            -> 'i Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) typ
               Core_kernel.Bin_prot.Type_class.t

          type ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               t =
            { version : int
            ; t :
                ( 'plonk
                , 'scalar_challenge
                , 'fp
                , 'fq
                , 'me_only
                , 'digest
                , 'pass_through
                , 'bp_chals
                , 'index )
                typ
            }

          val bin_shape_t :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_t :
               'plonk Core_kernel.Bin_prot.Size.sizer
            -> 'scalar_challenge Core_kernel.Bin_prot.Size.sizer
            -> 'fp Core_kernel.Bin_prot.Size.sizer
            -> 'fq Core_kernel.Bin_prot.Size.sizer
            -> 'me_only Core_kernel.Bin_prot.Size.sizer
            -> 'digest Core_kernel.Bin_prot.Size.sizer
            -> 'pass_through Core_kernel.Bin_prot.Size.sizer
            -> 'bp_chals Core_kernel.Bin_prot.Size.sizer
            -> 'index Core_kernel.Bin_prot.Size.sizer
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               t
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_t :
               'plonk Core_kernel.Bin_prot.Write.writer
            -> 'scalar_challenge Core_kernel.Bin_prot.Write.writer
            -> 'fp Core_kernel.Bin_prot.Write.writer
            -> 'fq Core_kernel.Bin_prot.Write.writer
            -> 'me_only Core_kernel.Bin_prot.Write.writer
            -> 'digest Core_kernel.Bin_prot.Write.writer
            -> 'pass_through Core_kernel.Bin_prot.Write.writer
            -> 'bp_chals Core_kernel.Bin_prot.Write.writer
            -> 'index Core_kernel.Bin_prot.Write.writer
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               t
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_t :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> 'd Core_kernel.Bin_prot.Type_class.writer
            -> 'e Core_kernel.Bin_prot.Type_class.writer
            -> 'f Core_kernel.Bin_prot.Type_class.writer
            -> 'g Core_kernel.Bin_prot.Type_class.writer
            -> 'h Core_kernel.Bin_prot.Type_class.writer
            -> 'i Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
               Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_t__ :
               'plonk Core_kernel.Bin_prot.Read.reader
            -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
            -> 'fp Core_kernel.Bin_prot.Read.reader
            -> 'fq Core_kernel.Bin_prot.Read.reader
            -> 'me_only Core_kernel.Bin_prot.Read.reader
            -> 'digest Core_kernel.Bin_prot.Read.reader
            -> 'pass_through Core_kernel.Bin_prot.Read.reader
            -> 'bp_chals Core_kernel.Bin_prot.Read.reader
            -> 'index Core_kernel.Bin_prot.Read.reader
            -> (   int
                -> ( 'plonk
                   , 'scalar_challenge
                   , 'fp
                   , 'fq
                   , 'me_only
                   , 'digest
                   , 'pass_through
                   , 'bp_chals
                   , 'index )
                   t)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_t :
               'plonk Core_kernel.Bin_prot.Read.reader
            -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
            -> 'fp Core_kernel.Bin_prot.Read.reader
            -> 'fq Core_kernel.Bin_prot.Read.reader
            -> 'me_only Core_kernel.Bin_prot.Read.reader
            -> 'digest Core_kernel.Bin_prot.Read.reader
            -> 'pass_through Core_kernel.Bin_prot.Read.reader
            -> 'bp_chals Core_kernel.Bin_prot.Read.reader
            -> 'index Core_kernel.Bin_prot.Read.reader
            -> ( 'plonk
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               t
               Core_kernel.Bin_prot.Read.reader

          val bin_reader_t :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> 'd Core_kernel.Bin_prot.Type_class.reader
            -> 'e Core_kernel.Bin_prot.Type_class.reader
            -> 'f Core_kernel.Bin_prot.Type_class.reader
            -> 'g Core_kernel.Bin_prot.Type_class.reader
            -> 'h Core_kernel.Bin_prot.Type_class.reader
            -> 'i Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
               Core_kernel.Bin_prot.Type_class.reader

          val bin_t :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> 'd Core_kernel.Bin_prot.Type_class.t
            -> 'e Core_kernel.Bin_prot.Type_class.t
            -> 'f Core_kernel.Bin_prot.Type_class.t
            -> 'g Core_kernel.Bin_prot.Type_class.t
            -> 'h Core_kernel.Bin_prot.Type_class.t
            -> 'i Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
               Core_kernel.Bin_prot.Type_class.t

          val create :
               ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) typ
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
        end

        val bin_read_t :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> 'd Core_kernel.Bin_prot.Read.reader
          -> 'e Core_kernel.Bin_prot.Read.reader
          -> 'f Core_kernel.Bin_prot.Read.reader
          -> 'g Core_kernel.Bin_prot.Read.reader
          -> 'h Core_kernel.Bin_prot.Read.reader
          -> 'i Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t

        val __bin_read_t__ :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> 'd Core_kernel.Bin_prot.Read.reader
          -> 'e Core_kernel.Bin_prot.Read.reader
          -> 'f Core_kernel.Bin_prot.Read.reader
          -> 'g Core_kernel.Bin_prot.Read.reader
          -> 'h Core_kernel.Bin_prot.Read.reader
          -> 'i Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> int
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t

        val bin_size_t :
             'a Core_kernel.Bin_prot.Size.sizer
          -> 'b Core_kernel.Bin_prot.Size.sizer
          -> 'c Core_kernel.Bin_prot.Size.sizer
          -> 'd Core_kernel.Bin_prot.Size.sizer
          -> 'e Core_kernel.Bin_prot.Size.sizer
          -> 'f Core_kernel.Bin_prot.Size.sizer
          -> 'g Core_kernel.Bin_prot.Size.sizer
          -> 'h Core_kernel.Bin_prot.Size.sizer
          -> 'i Core_kernel.Bin_prot.Size.sizer
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
          -> int

        val bin_write_t :
             'a Core_kernel.Bin_prot.Write.writer
          -> 'b Core_kernel.Bin_prot.Write.writer
          -> 'c Core_kernel.Bin_prot.Write.writer
          -> 'd Core_kernel.Bin_prot.Write.writer
          -> 'e Core_kernel.Bin_prot.Write.writer
          -> 'f Core_kernel.Bin_prot.Write.writer
          -> 'g Core_kernel.Bin_prot.Write.writer
          -> 'h Core_kernel.Bin_prot.Write.writer
          -> 'i Core_kernel.Bin_prot.Write.writer
          -> Bin_prot.Common.buf
          -> pos:Bin_prot.Common.pos
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
          -> Bin_prot.Common.pos

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
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
          -> 'f Core_kernel.Bin_prot.Type_class.reader
          -> 'g Core_kernel.Bin_prot.Type_class.reader
          -> 'h Core_kernel.Bin_prot.Type_class.reader
          -> 'i Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
             Core_kernel.Bin_prot.Type_class.reader

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> 'd Core_kernel.Bin_prot.Type_class.writer
          -> 'e Core_kernel.Bin_prot.Type_class.writer
          -> 'f Core_kernel.Bin_prot.Type_class.writer
          -> 'g Core_kernel.Bin_prot.Type_class.writer
          -> 'h Core_kernel.Bin_prot.Type_class.writer
          -> 'i Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
             Core_kernel.Bin_prot.Type_class.writer

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> 'd Core_kernel.Bin_prot.Type_class.t
          -> 'e Core_kernel.Bin_prot.Type_class.t
          -> 'f Core_kernel.Bin_prot.Type_class.t
          -> 'g Core_kernel.Bin_prot.Type_class.t
          -> 'h Core_kernel.Bin_prot.Type_class.t
          -> 'i Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
             Core_kernel.Bin_prot.Type_class.t

        val __ :
          (   'a Core_kernel.Bin_prot.Read.reader
           -> 'b Core_kernel.Bin_prot.Read.reader
           -> 'c Core_kernel.Bin_prot.Read.reader
           -> 'd Core_kernel.Bin_prot.Read.reader
           -> 'e Core_kernel.Bin_prot.Read.reader
           -> 'f Core_kernel.Bin_prot.Read.reader
           -> 'g Core_kernel.Bin_prot.Read.reader
           -> 'h Core_kernel.Bin_prot.Read.reader
           -> 'i Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t)
          * (   'j Core_kernel.Bin_prot.Read.reader
             -> 'k Core_kernel.Bin_prot.Read.reader
             -> 'l Core_kernel.Bin_prot.Read.reader
             -> 'm Core_kernel.Bin_prot.Read.reader
             -> 'n Core_kernel.Bin_prot.Read.reader
             -> 'o Core_kernel.Bin_prot.Read.reader
             -> 'p Core_kernel.Bin_prot.Read.reader
             -> 'q Core_kernel.Bin_prot.Read.reader
             -> 'r Core_kernel.Bin_prot.Read.reader
             -> Bin_prot.Common.buf
             -> pos_ref:Bin_prot.Common.pos_ref
             -> int
             -> ('j, 'k, 'l, 'm, 'n, 'o, 'p, 'q, 'r) t)
          * (   's Core_kernel.Bin_prot.Size.sizer
             -> 't Core_kernel.Bin_prot.Size.sizer
             -> 'u Core_kernel.Bin_prot.Size.sizer
             -> 'v Core_kernel.Bin_prot.Size.sizer
             -> 'w Core_kernel.Bin_prot.Size.sizer
             -> 'x Core_kernel.Bin_prot.Size.sizer
             -> 'y Core_kernel.Bin_prot.Size.sizer
             -> 'z Core_kernel.Bin_prot.Size.sizer
             -> 'a1 Core_kernel.Bin_prot.Size.sizer
             -> ('s, 't, 'u, 'v, 'w, 'x, 'y, 'z, 'a1) t
             -> int)
          * (   'b1 Core_kernel.Bin_prot.Write.writer
             -> 'c1 Core_kernel.Bin_prot.Write.writer
             -> 'd1 Core_kernel.Bin_prot.Write.writer
             -> 'e1 Core_kernel.Bin_prot.Write.writer
             -> 'f1 Core_kernel.Bin_prot.Write.writer
             -> 'g1 Core_kernel.Bin_prot.Write.writer
             -> 'h1 Core_kernel.Bin_prot.Write.writer
             -> 'i1 Core_kernel.Bin_prot.Write.writer
             -> 'j1 Core_kernel.Bin_prot.Write.writer
             -> Bin_prot.Common.buf
             -> pos:Bin_prot.Common.pos
             -> ('b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1, 'j1) t
             -> Bin_prot.Common.pos)
          * (   Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t)
          * (   'k1 Core_kernel.Bin_prot.Type_class.reader
             -> 'l1 Core_kernel.Bin_prot.Type_class.reader
             -> 'm1 Core_kernel.Bin_prot.Type_class.reader
             -> 'n1 Core_kernel.Bin_prot.Type_class.reader
             -> 'o1 Core_kernel.Bin_prot.Type_class.reader
             -> 'p1 Core_kernel.Bin_prot.Type_class.reader
             -> 'q1 Core_kernel.Bin_prot.Type_class.reader
             -> 'r1 Core_kernel.Bin_prot.Type_class.reader
             -> 's1 Core_kernel.Bin_prot.Type_class.reader
             -> ('k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1) t
                Core_kernel.Bin_prot.Type_class.reader)
          * (   't1 Core_kernel.Bin_prot.Type_class.writer
             -> 'u1 Core_kernel.Bin_prot.Type_class.writer
             -> 'v1 Core_kernel.Bin_prot.Type_class.writer
             -> 'w1 Core_kernel.Bin_prot.Type_class.writer
             -> 'x1 Core_kernel.Bin_prot.Type_class.writer
             -> 'y1 Core_kernel.Bin_prot.Type_class.writer
             -> 'z1 Core_kernel.Bin_prot.Type_class.writer
             -> 'a2 Core_kernel.Bin_prot.Type_class.writer
             -> 'b2 Core_kernel.Bin_prot.Type_class.writer
             -> ('t1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2) t
                Core_kernel.Bin_prot.Type_class.writer)
          * (   'c2 Core_kernel.Bin_prot.Type_class.t
             -> 'd2 Core_kernel.Bin_prot.Type_class.t
             -> 'e2 Core_kernel.Bin_prot.Type_class.t
             -> 'f2 Core_kernel.Bin_prot.Type_class.t
             -> 'g2 Core_kernel.Bin_prot.Type_class.t
             -> 'h2 Core_kernel.Bin_prot.Type_class.t
             -> 'i2 Core_kernel.Bin_prot.Type_class.t
             -> 'j2 Core_kernel.Bin_prot.Type_class.t
             -> 'k2 Core_kernel.Bin_prot.Type_class.t
             -> ('c2, 'd2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2) t
                Core_kernel.Bin_prot.Type_class.t)
      end

      module Latest = V1
    end

    type ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'pass_through
         , 'bp_chals
         , 'index )
         t =
          ( 'plonk
          , 'scalar_challenge
          , 'fp
          , 'fq
          , 'me_only
          , 'digest
          , 'pass_through
          , 'bp_chals
          , 'index )
          Stable.V1.t =
      { proof_state :
          ( 'plonk
          , 'scalar_challenge
          , 'fp
          , 'fq
          , 'me_only
          , 'digest
          , 'bp_chals
          , 'index )
          Proof_state.t
      ; pass_through : 'pass_through
      }

    val to_yojson :
         ('plonk -> Yojson.Safe.t)
      -> ('scalar_challenge -> Yojson.Safe.t)
      -> ('fp -> Yojson.Safe.t)
      -> ('fq -> Yojson.Safe.t)
      -> ('me_only -> Yojson.Safe.t)
      -> ('digest -> Yojson.Safe.t)
      -> ('pass_through -> Yojson.Safe.t)
      -> ('bp_chals -> Yojson.Safe.t)
      -> ('index -> Yojson.Safe.t)
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'pass_through
         , 'bp_chals
         , 'index )
         t
      -> Yojson.Safe.t

    val of_yojson :
         (Yojson.Safe.t -> 'plonk Ppx_deriving_yojson_runtime.error_or)
      -> (   Yojson.Safe.t
          -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'fp Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'me_only Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'digest Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'pass_through Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'bp_chals Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'index Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'pass_through
         , 'bp_chals
         , 'index )
         t
         Ppx_deriving_yojson_runtime.error_or

    val compare :
         ('plonk -> 'plonk -> int)
      -> ('scalar_challenge -> 'scalar_challenge -> int)
      -> ('fp -> 'fp -> int)
      -> ('fq -> 'fq -> int)
      -> ('me_only -> 'me_only -> int)
      -> ('digest -> 'digest -> int)
      -> ('pass_through -> 'pass_through -> int)
      -> ('bp_chals -> 'bp_chals -> int)
      -> ('index -> 'index -> int)
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'pass_through
         , 'bp_chals
         , 'index )
         t
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'pass_through
         , 'bp_chals
         , 'index )
         t
      -> int

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'plonk)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'fp)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'me_only)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'digest)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'pass_through)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'bp_chals)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'index)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'pass_through
         , 'bp_chals
         , 'index )
         t

    val sexp_of_t :
         ('plonk -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('fp -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('me_only -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('digest -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('pass_through -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('bp_chals -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('index -> Ppx_sexp_conv_lib.Sexp.t)
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'pass_through
         , 'bp_chals
         , 'index )
         t
      -> Ppx_sexp_conv_lib.Sexp.t

    val hash_fold_t :
         (Ppx_hash_lib.Std.Hash.state -> 'plonk -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'scalar_challenge
          -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'fp -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'fq -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'me_only
          -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'digest -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'pass_through
          -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'bp_chals
          -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'index -> Ppx_hash_lib.Std.Hash.state)
      -> Ppx_hash_lib.Std.Hash.state
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'pass_through
         , 'bp_chals
         , 'index )
         t
      -> Ppx_hash_lib.Std.Hash.state

    val equal :
         ('plonk -> 'plonk -> bool)
      -> ('scalar_challenge -> 'scalar_challenge -> bool)
      -> ('fp -> 'fp -> bool)
      -> ('fq -> 'fq -> bool)
      -> ('me_only -> 'me_only -> bool)
      -> ('digest -> 'digest -> bool)
      -> ('pass_through -> 'pass_through -> bool)
      -> ('bp_chals -> 'bp_chals -> bool)
      -> ('index -> 'index -> bool)
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'pass_through
         , 'bp_chals
         , 'index )
         t
      -> ( 'plonk
         , 'scalar_challenge
         , 'fp
         , 'fq
         , 'me_only
         , 'digest
         , 'pass_through
         , 'bp_chals
         , 'index )
         t
      -> bool

    module Minimal : sig
      module Stable : sig
        module V1 : sig
          type ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               t =
            ( ( 'challenge
              , 'scalar_challenge )
              Proof_state.Deferred_values.Plonk.Minimal.t
            , 'scalar_challenge
            , 'fp
            , 'fq
            , 'me_only
            , 'digest
            , 'pass_through
            , 'bp_chals
            , 'index )
            Stable.V1.t

          val to_yojson :
               ('challenge -> Yojson.Safe.t)
            -> ('scalar_challenge -> Yojson.Safe.t)
            -> ('fp -> Yojson.Safe.t)
            -> ('fq -> Yojson.Safe.t)
            -> ('me_only -> Yojson.Safe.t)
            -> ('digest -> Yojson.Safe.t)
            -> ('pass_through -> Yojson.Safe.t)
            -> ('bp_chals -> Yojson.Safe.t)
            -> ('index -> Yojson.Safe.t)
            -> ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               t
            -> Yojson.Safe.t

          val of_yojson :
               (Yojson.Safe.t -> 'challenge Ppx_deriving_yojson_runtime.error_or)
            -> (   Yojson.Safe.t
                -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
            -> (Yojson.Safe.t -> 'fp Ppx_deriving_yojson_runtime.error_or)
            -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
            -> (Yojson.Safe.t -> 'me_only Ppx_deriving_yojson_runtime.error_or)
            -> (Yojson.Safe.t -> 'digest Ppx_deriving_yojson_runtime.error_or)
            -> (   Yojson.Safe.t
                -> 'pass_through Ppx_deriving_yojson_runtime.error_or)
            -> (Yojson.Safe.t -> 'bp_chals Ppx_deriving_yojson_runtime.error_or)
            -> (Yojson.Safe.t -> 'index Ppx_deriving_yojson_runtime.error_or)
            -> Yojson.Safe.t
            -> ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               t
               Ppx_deriving_yojson_runtime.error_or

          val version : int

          val __versioned__ : unit

          val compare :
               ('challenge -> 'challenge -> int)
            -> ('scalar_challenge -> 'scalar_challenge -> int)
            -> ('fp -> 'fp -> int)
            -> ('fq -> 'fq -> int)
            -> ('me_only -> 'me_only -> int)
            -> ('digest -> 'digest -> int)
            -> ('pass_through -> 'pass_through -> int)
            -> ('bp_chals -> 'bp_chals -> int)
            -> ('index -> 'index -> int)
            -> ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               t
            -> ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               t
            -> int

          val t_of_sexp :
               (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'fp)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'me_only)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'digest)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'pass_through)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'bp_chals)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'index)
            -> Ppx_sexp_conv_lib.Sexp.t
            -> ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               t

          val sexp_of_t :
               ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('fp -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('me_only -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('digest -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('pass_through -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('bp_chals -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('index -> Ppx_sexp_conv_lib.Sexp.t)
            -> ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               t
            -> Ppx_sexp_conv_lib.Sexp.t

          val hash_fold_t :
               (   Ppx_hash_lib.Std.Hash.state
                -> 'challenge
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'scalar_challenge
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'fp
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'fq
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'me_only
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'digest
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'pass_through
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'bp_chals
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'index
                -> Ppx_hash_lib.Std.Hash.state)
            -> Ppx_hash_lib.Std.Hash.state
            -> ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               t
            -> Ppx_hash_lib.Std.Hash.state

          val equal :
               ('challenge -> 'challenge -> bool)
            -> ('scalar_challenge -> 'scalar_challenge -> bool)
            -> ('fp -> 'fp -> bool)
            -> ('fq -> 'fq -> bool)
            -> ('me_only -> 'me_only -> bool)
            -> ('digest -> 'digest -> bool)
            -> ('pass_through -> 'pass_through -> bool)
            -> ('bp_chals -> 'bp_chals -> bool)
            -> ('index -> 'index -> bool)
            -> ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               t
            -> ( 'challenge
               , 'scalar_challenge
               , 'fp
               , 'fq
               , 'me_only
               , 'digest
               , 'pass_through
               , 'bp_chals
               , 'index )
               t
            -> bool

          module With_version : sig
            type ( 'challenge
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'me_only
                 , 'digest
                 , 'pass_through
                 , 'bp_chals
                 , 'index )
                 typ =
              ( 'challenge
              , 'scalar_challenge
              , 'fp
              , 'fq
              , 'me_only
              , 'digest
              , 'pass_through
              , 'bp_chals
              , 'index )
              t

            val bin_shape_typ :
                 Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t

            val bin_size_typ :
                 'challenge Core_kernel.Bin_prot.Size.sizer
              -> 'scalar_challenge Core_kernel.Bin_prot.Size.sizer
              -> 'fp Core_kernel.Bin_prot.Size.sizer
              -> 'fq Core_kernel.Bin_prot.Size.sizer
              -> 'me_only Core_kernel.Bin_prot.Size.sizer
              -> 'digest Core_kernel.Bin_prot.Size.sizer
              -> 'pass_through Core_kernel.Bin_prot.Size.sizer
              -> 'bp_chals Core_kernel.Bin_prot.Size.sizer
              -> 'index Core_kernel.Bin_prot.Size.sizer
              -> ( 'challenge
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'me_only
                 , 'digest
                 , 'pass_through
                 , 'bp_chals
                 , 'index )
                 typ
                 Core_kernel.Bin_prot.Size.sizer

            val bin_write_typ :
                 'challenge Core_kernel.Bin_prot.Write.writer
              -> 'scalar_challenge Core_kernel.Bin_prot.Write.writer
              -> 'fp Core_kernel.Bin_prot.Write.writer
              -> 'fq Core_kernel.Bin_prot.Write.writer
              -> 'me_only Core_kernel.Bin_prot.Write.writer
              -> 'digest Core_kernel.Bin_prot.Write.writer
              -> 'pass_through Core_kernel.Bin_prot.Write.writer
              -> 'bp_chals Core_kernel.Bin_prot.Write.writer
              -> 'index Core_kernel.Bin_prot.Write.writer
              -> ( 'challenge
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'me_only
                 , 'digest
                 , 'pass_through
                 , 'bp_chals
                 , 'index )
                 typ
                 Core_kernel.Bin_prot.Write.writer

            val bin_writer_typ :
                 'a Core_kernel.Bin_prot.Type_class.writer
              -> 'b Core_kernel.Bin_prot.Type_class.writer
              -> 'c Core_kernel.Bin_prot.Type_class.writer
              -> 'd Core_kernel.Bin_prot.Type_class.writer
              -> 'e Core_kernel.Bin_prot.Type_class.writer
              -> 'f Core_kernel.Bin_prot.Type_class.writer
              -> 'g Core_kernel.Bin_prot.Type_class.writer
              -> 'h Core_kernel.Bin_prot.Type_class.writer
              -> 'i Core_kernel.Bin_prot.Type_class.writer
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) typ
                 Core_kernel.Bin_prot.Type_class.writer

            val __bin_read_typ__ :
                 'challenge Core_kernel.Bin_prot.Read.reader
              -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
              -> 'fp Core_kernel.Bin_prot.Read.reader
              -> 'fq Core_kernel.Bin_prot.Read.reader
              -> 'me_only Core_kernel.Bin_prot.Read.reader
              -> 'digest Core_kernel.Bin_prot.Read.reader
              -> 'pass_through Core_kernel.Bin_prot.Read.reader
              -> 'bp_chals Core_kernel.Bin_prot.Read.reader
              -> 'index Core_kernel.Bin_prot.Read.reader
              -> (   int
                  -> ( 'challenge
                     , 'scalar_challenge
                     , 'fp
                     , 'fq
                     , 'me_only
                     , 'digest
                     , 'pass_through
                     , 'bp_chals
                     , 'index )
                     typ)
                 Core_kernel.Bin_prot.Read.reader

            val bin_read_typ :
                 'challenge Core_kernel.Bin_prot.Read.reader
              -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
              -> 'fp Core_kernel.Bin_prot.Read.reader
              -> 'fq Core_kernel.Bin_prot.Read.reader
              -> 'me_only Core_kernel.Bin_prot.Read.reader
              -> 'digest Core_kernel.Bin_prot.Read.reader
              -> 'pass_through Core_kernel.Bin_prot.Read.reader
              -> 'bp_chals Core_kernel.Bin_prot.Read.reader
              -> 'index Core_kernel.Bin_prot.Read.reader
              -> ( 'challenge
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'me_only
                 , 'digest
                 , 'pass_through
                 , 'bp_chals
                 , 'index )
                 typ
                 Core_kernel.Bin_prot.Read.reader

            val bin_reader_typ :
                 'a Core_kernel.Bin_prot.Type_class.reader
              -> 'b Core_kernel.Bin_prot.Type_class.reader
              -> 'c Core_kernel.Bin_prot.Type_class.reader
              -> 'd Core_kernel.Bin_prot.Type_class.reader
              -> 'e Core_kernel.Bin_prot.Type_class.reader
              -> 'f Core_kernel.Bin_prot.Type_class.reader
              -> 'g Core_kernel.Bin_prot.Type_class.reader
              -> 'h Core_kernel.Bin_prot.Type_class.reader
              -> 'i Core_kernel.Bin_prot.Type_class.reader
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) typ
                 Core_kernel.Bin_prot.Type_class.reader

            val bin_typ :
                 'a Core_kernel.Bin_prot.Type_class.t
              -> 'b Core_kernel.Bin_prot.Type_class.t
              -> 'c Core_kernel.Bin_prot.Type_class.t
              -> 'd Core_kernel.Bin_prot.Type_class.t
              -> 'e Core_kernel.Bin_prot.Type_class.t
              -> 'f Core_kernel.Bin_prot.Type_class.t
              -> 'g Core_kernel.Bin_prot.Type_class.t
              -> 'h Core_kernel.Bin_prot.Type_class.t
              -> 'i Core_kernel.Bin_prot.Type_class.t
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) typ
                 Core_kernel.Bin_prot.Type_class.t

            type ( 'challenge
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'me_only
                 , 'digest
                 , 'pass_through
                 , 'bp_chals
                 , 'index )
                 t =
              { version : int
              ; t :
                  ( 'challenge
                  , 'scalar_challenge
                  , 'fp
                  , 'fq
                  , 'me_only
                  , 'digest
                  , 'pass_through
                  , 'bp_chals
                  , 'index )
                  typ
              }

            val bin_shape_t :
                 Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t

            val bin_size_t :
                 'challenge Core_kernel.Bin_prot.Size.sizer
              -> 'scalar_challenge Core_kernel.Bin_prot.Size.sizer
              -> 'fp Core_kernel.Bin_prot.Size.sizer
              -> 'fq Core_kernel.Bin_prot.Size.sizer
              -> 'me_only Core_kernel.Bin_prot.Size.sizer
              -> 'digest Core_kernel.Bin_prot.Size.sizer
              -> 'pass_through Core_kernel.Bin_prot.Size.sizer
              -> 'bp_chals Core_kernel.Bin_prot.Size.sizer
              -> 'index Core_kernel.Bin_prot.Size.sizer
              -> ( 'challenge
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'me_only
                 , 'digest
                 , 'pass_through
                 , 'bp_chals
                 , 'index )
                 t
                 Core_kernel.Bin_prot.Size.sizer

            val bin_write_t :
                 'challenge Core_kernel.Bin_prot.Write.writer
              -> 'scalar_challenge Core_kernel.Bin_prot.Write.writer
              -> 'fp Core_kernel.Bin_prot.Write.writer
              -> 'fq Core_kernel.Bin_prot.Write.writer
              -> 'me_only Core_kernel.Bin_prot.Write.writer
              -> 'digest Core_kernel.Bin_prot.Write.writer
              -> 'pass_through Core_kernel.Bin_prot.Write.writer
              -> 'bp_chals Core_kernel.Bin_prot.Write.writer
              -> 'index Core_kernel.Bin_prot.Write.writer
              -> ( 'challenge
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'me_only
                 , 'digest
                 , 'pass_through
                 , 'bp_chals
                 , 'index )
                 t
                 Core_kernel.Bin_prot.Write.writer

            val bin_writer_t :
                 'a Core_kernel.Bin_prot.Type_class.writer
              -> 'b Core_kernel.Bin_prot.Type_class.writer
              -> 'c Core_kernel.Bin_prot.Type_class.writer
              -> 'd Core_kernel.Bin_prot.Type_class.writer
              -> 'e Core_kernel.Bin_prot.Type_class.writer
              -> 'f Core_kernel.Bin_prot.Type_class.writer
              -> 'g Core_kernel.Bin_prot.Type_class.writer
              -> 'h Core_kernel.Bin_prot.Type_class.writer
              -> 'i Core_kernel.Bin_prot.Type_class.writer
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
                 Core_kernel.Bin_prot.Type_class.writer

            val __bin_read_t__ :
                 'challenge Core_kernel.Bin_prot.Read.reader
              -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
              -> 'fp Core_kernel.Bin_prot.Read.reader
              -> 'fq Core_kernel.Bin_prot.Read.reader
              -> 'me_only Core_kernel.Bin_prot.Read.reader
              -> 'digest Core_kernel.Bin_prot.Read.reader
              -> 'pass_through Core_kernel.Bin_prot.Read.reader
              -> 'bp_chals Core_kernel.Bin_prot.Read.reader
              -> 'index Core_kernel.Bin_prot.Read.reader
              -> (   int
                  -> ( 'challenge
                     , 'scalar_challenge
                     , 'fp
                     , 'fq
                     , 'me_only
                     , 'digest
                     , 'pass_through
                     , 'bp_chals
                     , 'index )
                     t)
                 Core_kernel.Bin_prot.Read.reader

            val bin_read_t :
                 'challenge Core_kernel.Bin_prot.Read.reader
              -> 'scalar_challenge Core_kernel.Bin_prot.Read.reader
              -> 'fp Core_kernel.Bin_prot.Read.reader
              -> 'fq Core_kernel.Bin_prot.Read.reader
              -> 'me_only Core_kernel.Bin_prot.Read.reader
              -> 'digest Core_kernel.Bin_prot.Read.reader
              -> 'pass_through Core_kernel.Bin_prot.Read.reader
              -> 'bp_chals Core_kernel.Bin_prot.Read.reader
              -> 'index Core_kernel.Bin_prot.Read.reader
              -> ( 'challenge
                 , 'scalar_challenge
                 , 'fp
                 , 'fq
                 , 'me_only
                 , 'digest
                 , 'pass_through
                 , 'bp_chals
                 , 'index )
                 t
                 Core_kernel.Bin_prot.Read.reader

            val bin_reader_t :
                 'a Core_kernel.Bin_prot.Type_class.reader
              -> 'b Core_kernel.Bin_prot.Type_class.reader
              -> 'c Core_kernel.Bin_prot.Type_class.reader
              -> 'd Core_kernel.Bin_prot.Type_class.reader
              -> 'e Core_kernel.Bin_prot.Type_class.reader
              -> 'f Core_kernel.Bin_prot.Type_class.reader
              -> 'g Core_kernel.Bin_prot.Type_class.reader
              -> 'h Core_kernel.Bin_prot.Type_class.reader
              -> 'i Core_kernel.Bin_prot.Type_class.reader
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
                 Core_kernel.Bin_prot.Type_class.reader

            val bin_t :
                 'a Core_kernel.Bin_prot.Type_class.t
              -> 'b Core_kernel.Bin_prot.Type_class.t
              -> 'c Core_kernel.Bin_prot.Type_class.t
              -> 'd Core_kernel.Bin_prot.Type_class.t
              -> 'e Core_kernel.Bin_prot.Type_class.t
              -> 'f Core_kernel.Bin_prot.Type_class.t
              -> 'g Core_kernel.Bin_prot.Type_class.t
              -> 'h Core_kernel.Bin_prot.Type_class.t
              -> 'i Core_kernel.Bin_prot.Type_class.t
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
                 Core_kernel.Bin_prot.Type_class.t

            val create :
                 ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) typ
              -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
          end

          val bin_read_t :
               'a Core_kernel.Bin_prot.Read.reader
            -> 'b Core_kernel.Bin_prot.Read.reader
            -> 'c Core_kernel.Bin_prot.Read.reader
            -> 'd Core_kernel.Bin_prot.Read.reader
            -> 'e Core_kernel.Bin_prot.Read.reader
            -> 'f Core_kernel.Bin_prot.Read.reader
            -> 'g Core_kernel.Bin_prot.Read.reader
            -> 'h Core_kernel.Bin_prot.Read.reader
            -> 'i Core_kernel.Bin_prot.Read.reader
            -> Bin_prot.Common.buf
            -> pos_ref:Bin_prot.Common.pos_ref
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t

          val __bin_read_t__ :
               'a Core_kernel.Bin_prot.Read.reader
            -> 'b Core_kernel.Bin_prot.Read.reader
            -> 'c Core_kernel.Bin_prot.Read.reader
            -> 'd Core_kernel.Bin_prot.Read.reader
            -> 'e Core_kernel.Bin_prot.Read.reader
            -> 'f Core_kernel.Bin_prot.Read.reader
            -> 'g Core_kernel.Bin_prot.Read.reader
            -> 'h Core_kernel.Bin_prot.Read.reader
            -> 'i Core_kernel.Bin_prot.Read.reader
            -> Bin_prot.Common.buf
            -> pos_ref:Bin_prot.Common.pos_ref
            -> int
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t

          val bin_size_t :
               'a Core_kernel.Bin_prot.Size.sizer
            -> 'b Core_kernel.Bin_prot.Size.sizer
            -> 'c Core_kernel.Bin_prot.Size.sizer
            -> 'd Core_kernel.Bin_prot.Size.sizer
            -> 'e Core_kernel.Bin_prot.Size.sizer
            -> 'f Core_kernel.Bin_prot.Size.sizer
            -> 'g Core_kernel.Bin_prot.Size.sizer
            -> 'h Core_kernel.Bin_prot.Size.sizer
            -> 'i Core_kernel.Bin_prot.Size.sizer
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
            -> int

          val bin_write_t :
               'a Core_kernel.Bin_prot.Write.writer
            -> 'b Core_kernel.Bin_prot.Write.writer
            -> 'c Core_kernel.Bin_prot.Write.writer
            -> 'd Core_kernel.Bin_prot.Write.writer
            -> 'e Core_kernel.Bin_prot.Write.writer
            -> 'f Core_kernel.Bin_prot.Write.writer
            -> 'g Core_kernel.Bin_prot.Write.writer
            -> 'h Core_kernel.Bin_prot.Write.writer
            -> 'i Core_kernel.Bin_prot.Write.writer
            -> Bin_prot.Common.buf
            -> pos:Bin_prot.Common.pos
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
            -> Bin_prot.Common.pos

          val bin_shape_t :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
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
            -> 'f Core_kernel.Bin_prot.Type_class.reader
            -> 'g Core_kernel.Bin_prot.Type_class.reader
            -> 'h Core_kernel.Bin_prot.Type_class.reader
            -> 'i Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
               Core_kernel.Bin_prot.Type_class.reader

          val bin_writer_t :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> 'd Core_kernel.Bin_prot.Type_class.writer
            -> 'e Core_kernel.Bin_prot.Type_class.writer
            -> 'f Core_kernel.Bin_prot.Type_class.writer
            -> 'g Core_kernel.Bin_prot.Type_class.writer
            -> 'h Core_kernel.Bin_prot.Type_class.writer
            -> 'i Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
               Core_kernel.Bin_prot.Type_class.writer

          val bin_t :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> 'd Core_kernel.Bin_prot.Type_class.t
            -> 'e Core_kernel.Bin_prot.Type_class.t
            -> 'f Core_kernel.Bin_prot.Type_class.t
            -> 'g Core_kernel.Bin_prot.Type_class.t
            -> 'h Core_kernel.Bin_prot.Type_class.t
            -> 'i Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t
               Core_kernel.Bin_prot.Type_class.t

          val __ :
            (   'a Core_kernel.Bin_prot.Read.reader
             -> 'b Core_kernel.Bin_prot.Read.reader
             -> 'c Core_kernel.Bin_prot.Read.reader
             -> 'd Core_kernel.Bin_prot.Read.reader
             -> 'e Core_kernel.Bin_prot.Read.reader
             -> 'f Core_kernel.Bin_prot.Read.reader
             -> 'g Core_kernel.Bin_prot.Read.reader
             -> 'h Core_kernel.Bin_prot.Read.reader
             -> 'i Core_kernel.Bin_prot.Read.reader
             -> Bin_prot.Common.buf
             -> pos_ref:Bin_prot.Common.pos_ref
             -> ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) t)
            * (   'j Core_kernel.Bin_prot.Read.reader
               -> 'k Core_kernel.Bin_prot.Read.reader
               -> 'l Core_kernel.Bin_prot.Read.reader
               -> 'm Core_kernel.Bin_prot.Read.reader
               -> 'n Core_kernel.Bin_prot.Read.reader
               -> 'o Core_kernel.Bin_prot.Read.reader
               -> 'p Core_kernel.Bin_prot.Read.reader
               -> 'q Core_kernel.Bin_prot.Read.reader
               -> 'r Core_kernel.Bin_prot.Read.reader
               -> Bin_prot.Common.buf
               -> pos_ref:Bin_prot.Common.pos_ref
               -> int
               -> ('j, 'k, 'l, 'm, 'n, 'o, 'p, 'q, 'r) t)
            * (   's Core_kernel.Bin_prot.Size.sizer
               -> 't Core_kernel.Bin_prot.Size.sizer
               -> 'u Core_kernel.Bin_prot.Size.sizer
               -> 'v Core_kernel.Bin_prot.Size.sizer
               -> 'w Core_kernel.Bin_prot.Size.sizer
               -> 'x Core_kernel.Bin_prot.Size.sizer
               -> 'y Core_kernel.Bin_prot.Size.sizer
               -> 'z Core_kernel.Bin_prot.Size.sizer
               -> 'a1 Core_kernel.Bin_prot.Size.sizer
               -> ('s, 't, 'u, 'v, 'w, 'x, 'y, 'z, 'a1) t
               -> int)
            * (   'b1 Core_kernel.Bin_prot.Write.writer
               -> 'c1 Core_kernel.Bin_prot.Write.writer
               -> 'd1 Core_kernel.Bin_prot.Write.writer
               -> 'e1 Core_kernel.Bin_prot.Write.writer
               -> 'f1 Core_kernel.Bin_prot.Write.writer
               -> 'g1 Core_kernel.Bin_prot.Write.writer
               -> 'h1 Core_kernel.Bin_prot.Write.writer
               -> 'i1 Core_kernel.Bin_prot.Write.writer
               -> 'j1 Core_kernel.Bin_prot.Write.writer
               -> Bin_prot.Common.buf
               -> pos:Bin_prot.Common.pos
               -> ('b1, 'c1, 'd1, 'e1, 'f1, 'g1, 'h1, 'i1, 'j1) t
               -> Bin_prot.Common.pos)
            * (   Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t)
            * (   'k1 Core_kernel.Bin_prot.Type_class.reader
               -> 'l1 Core_kernel.Bin_prot.Type_class.reader
               -> 'm1 Core_kernel.Bin_prot.Type_class.reader
               -> 'n1 Core_kernel.Bin_prot.Type_class.reader
               -> 'o1 Core_kernel.Bin_prot.Type_class.reader
               -> 'p1 Core_kernel.Bin_prot.Type_class.reader
               -> 'q1 Core_kernel.Bin_prot.Type_class.reader
               -> 'r1 Core_kernel.Bin_prot.Type_class.reader
               -> 's1 Core_kernel.Bin_prot.Type_class.reader
               -> ('k1, 'l1, 'm1, 'n1, 'o1, 'p1, 'q1, 'r1, 's1) t
                  Core_kernel.Bin_prot.Type_class.reader)
            * (   't1 Core_kernel.Bin_prot.Type_class.writer
               -> 'u1 Core_kernel.Bin_prot.Type_class.writer
               -> 'v1 Core_kernel.Bin_prot.Type_class.writer
               -> 'w1 Core_kernel.Bin_prot.Type_class.writer
               -> 'x1 Core_kernel.Bin_prot.Type_class.writer
               -> 'y1 Core_kernel.Bin_prot.Type_class.writer
               -> 'z1 Core_kernel.Bin_prot.Type_class.writer
               -> 'a2 Core_kernel.Bin_prot.Type_class.writer
               -> 'b2 Core_kernel.Bin_prot.Type_class.writer
               -> ('t1, 'u1, 'v1, 'w1, 'x1, 'y1, 'z1, 'a2, 'b2) t
                  Core_kernel.Bin_prot.Type_class.writer)
            * (   'c2 Core_kernel.Bin_prot.Type_class.t
               -> 'd2 Core_kernel.Bin_prot.Type_class.t
               -> 'e2 Core_kernel.Bin_prot.Type_class.t
               -> 'f2 Core_kernel.Bin_prot.Type_class.t
               -> 'g2 Core_kernel.Bin_prot.Type_class.t
               -> 'h2 Core_kernel.Bin_prot.Type_class.t
               -> 'i2 Core_kernel.Bin_prot.Type_class.t
               -> 'j2 Core_kernel.Bin_prot.Type_class.t
               -> 'k2 Core_kernel.Bin_prot.Type_class.t
               -> ('c2, 'd2, 'e2, 'f2, 'g2, 'h2, 'i2, 'j2, 'k2) t
                  Core_kernel.Bin_prot.Type_class.t)
        end

        module Latest = V1
      end

      type ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t =
        ( 'challenge
        , 'scalar_challenge
        , 'fp
        , 'fq
        , 'me_only
        , 'digest
        , 'pass_through
        , 'bp_chals
        , 'index )
        Stable.Latest.t

      val to_yojson :
           ('challenge -> Yojson.Safe.t)
        -> ('scalar_challenge -> Yojson.Safe.t)
        -> ('fp -> Yojson.Safe.t)
        -> ('fq -> Yojson.Safe.t)
        -> ('me_only -> Yojson.Safe.t)
        -> ('digest -> Yojson.Safe.t)
        -> ('pass_through -> Yojson.Safe.t)
        -> ('bp_chals -> Yojson.Safe.t)
        -> ('index -> Yojson.Safe.t)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'challenge Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'fp Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'me_only Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'digest Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'pass_through Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'bp_chals Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'index Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
           Ppx_deriving_yojson_runtime.error_or

      val compare :
           ('challenge -> 'challenge -> int)
        -> ('scalar_challenge -> 'scalar_challenge -> int)
        -> ('fp -> 'fp -> int)
        -> ('fq -> 'fq -> int)
        -> ('me_only -> 'me_only -> int)
        -> ('digest -> 'digest -> int)
        -> ('pass_through -> 'pass_through -> int)
        -> ('bp_chals -> 'bp_chals -> int)
        -> ('index -> 'index -> int)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
        -> int

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fp)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'me_only)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'digest)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'pass_through)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'bp_chals)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'index)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t

      val sexp_of_t :
           ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fp -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('me_only -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('digest -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('pass_through -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('bp_chals -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('index -> Ppx_sexp_conv_lib.Sexp.t)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
        -> Ppx_sexp_conv_lib.Sexp.t

      val hash_fold_t :
           (   Ppx_hash_lib.Std.Hash.state
            -> 'challenge
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'scalar_challenge
            -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'fp -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'fq -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'me_only
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'digest
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'pass_through
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'bp_chals
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'index
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
        -> Ppx_hash_lib.Std.Hash.state

      val equal :
           ('challenge -> 'challenge -> bool)
        -> ('scalar_challenge -> 'scalar_challenge -> bool)
        -> ('fp -> 'fp -> bool)
        -> ('fq -> 'fq -> bool)
        -> ('me_only -> 'me_only -> bool)
        -> ('digest -> 'digest -> bool)
        -> ('pass_through -> 'pass_through -> bool)
        -> ('bp_chals -> 'bp_chals -> bool)
        -> ('index -> 'index -> bool)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
        -> bool
    end

    module In_circuit : sig
      type ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t =
        ( ( 'challenge
          , 'scalar_challenge
          , 'fp )
          Proof_state.Deferred_values.Plonk.In_circuit.t
        , 'scalar_challenge
        , 'fp
        , 'fq
        , 'me_only
        , 'digest
        , 'pass_through
        , 'bp_chals
        , 'index )
        Stable.V1.t

      val to_yojson :
           ('challenge -> Yojson.Safe.t)
        -> ('scalar_challenge -> Yojson.Safe.t)
        -> ('fp -> Yojson.Safe.t)
        -> ('fq -> Yojson.Safe.t)
        -> ('me_only -> Yojson.Safe.t)
        -> ('digest -> Yojson.Safe.t)
        -> ('pass_through -> Yojson.Safe.t)
        -> ('bp_chals -> Yojson.Safe.t)
        -> ('index -> Yojson.Safe.t)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'challenge Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'fp Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'me_only Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'digest Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'pass_through Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'bp_chals Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'index Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
           Ppx_deriving_yojson_runtime.error_or

      val compare :
           ('challenge -> 'challenge -> int)
        -> ('scalar_challenge -> 'scalar_challenge -> int)
        -> ('fp -> 'fp -> int)
        -> ('fq -> 'fq -> int)
        -> ('me_only -> 'me_only -> int)
        -> ('digest -> 'digest -> int)
        -> ('pass_through -> 'pass_through -> int)
        -> ('bp_chals -> 'bp_chals -> int)
        -> ('index -> 'index -> int)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
        -> int

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fp)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'me_only)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'digest)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'pass_through)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'bp_chals)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'index)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t

      val sexp_of_t :
           ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fp -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('me_only -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('digest -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('pass_through -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('bp_chals -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('index -> Ppx_sexp_conv_lib.Sexp.t)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
        -> Ppx_sexp_conv_lib.Sexp.t

      val hash_fold_t :
           (   Ppx_hash_lib.Std.Hash.state
            -> 'challenge
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'scalar_challenge
            -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'fp -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'fq -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'me_only
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'digest
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'pass_through
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'bp_chals
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'index
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
        -> Ppx_hash_lib.Std.Hash.state

      val equal :
           ('challenge -> 'challenge -> bool)
        -> ('scalar_challenge -> 'scalar_challenge -> bool)
        -> ('fp -> 'fp -> bool)
        -> ('fq -> 'fq -> bool)
        -> ('me_only -> 'me_only -> bool)
        -> ('digest -> 'digest -> bool)
        -> ('pass_through -> 'pass_through -> bool)
        -> ('bp_chals -> 'bp_chals -> bool)
        -> ('index -> 'index -> bool)
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
        -> ( 'challenge
           , 'scalar_challenge
           , 'fp
           , 'fq
           , 'me_only
           , 'digest
           , 'pass_through
           , 'bp_chals
           , 'index )
           t
        -> bool

      val spec :
        ( ( ( 'a
            , Pickles_types__Nat.z Pickles_types__Nat.N13.plus_n
              Pickles_types__Nat.s )
            Pickles_types.Vector.t
          * ( ( 'b
              , Pickles_types__Nat.z Pickles_types__Nat.N1.plus_n
                Pickles_types__Nat.s )
              Pickles_types.Vector.t
            * ( ( 'b Pickles_types.Scalar_challenge.t
                , Pickles_types__Nat.z Pickles_types__Nat.N2.plus_n
                  Pickles_types__Nat.s )
                Pickles_types.Vector.t
              * ( ( 'c
                  , Pickles_types__Nat.z Pickles_types__Nat.N2.plus_n
                    Pickles_types__Nat.s )
                  Pickles_types.Vector.t
                * ( ( 'd
                    , Pickles_types__Nat.z Backend.Tick.Rounds.plus_n )
                    Pickles_types.Vector.t
                  * ( ( 'e
                      , Pickles_types__Nat.z Pickles_types__Nat.N0.plus_n
                        Pickles_types__Nat.s )
                      Pickles_types.Vector.t
                    * unit ) ) ) ) ) )
          Pickles_types.Hlist.HlistId.t
        , ( ( 'f
            , Pickles_types__Nat.z Pickles_types__Nat.N13.plus_n
              Pickles_types__Nat.s )
            Pickles_types.Vector.t
          * ( ( 'g
              , Pickles_types__Nat.z Pickles_types__Nat.N1.plus_n
                Pickles_types__Nat.s )
              Pickles_types.Vector.t
            * ( ( 'g Pickles_types.Scalar_challenge.t
                , Pickles_types__Nat.z Pickles_types__Nat.N2.plus_n
                  Pickles_types__Nat.s )
                Pickles_types.Vector.t
              * ( ( 'h
                  , Pickles_types__Nat.z Pickles_types__Nat.N2.plus_n
                    Pickles_types__Nat.s )
                  Pickles_types.Vector.t
                * ( ( 'i
                    , Pickles_types__Nat.z Backend.Tick.Rounds.plus_n )
                    Pickles_types.Vector.t
                  * ( ( 'j
                      , Pickles_types__Nat.z Pickles_types__Nat.N0.plus_n
                        Pickles_types__Nat.s )
                      Pickles_types.Vector.t
                    * unit ) ) ) ) ) )
          Pickles_types.Hlist.HlistId.t
        , < bulletproof_challenge1 : 'd
          ; bulletproof_challenge2 : 'i
          ; challenge1 : 'b
          ; challenge2 : 'g
          ; digest1 : 'c
          ; digest2 : 'h
          ; field1 : 'a
          ; field2 : 'f
          ; index1 : 'e
          ; index2 : 'j
          ; .. > )
        Spec.t

      val to_data :
           ('a, 'b, 'c, 'd, 'e, 'e, 'e, 'f Pickles_types__Hlist0.Id.t, 'g) t
        -> ( ( 'c
             , Pickles_types.Vector.z Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s )
             Pickles_types.Vector.t
           * ( ( 'a
               , Pickles_types.Vector.z Pickles_types.Vector.s
                 Pickles_types.Vector.s )
               Pickles_types.Vector.t
             * ( ( 'b
                 , Pickles_types.Vector.z Pickles_types.Vector.s
                   Pickles_types.Vector.s
                   Pickles_types.Vector.s )
                 Pickles_types.Vector.t
               * ( ( 'e
                   , Pickles_types.Vector.z Pickles_types.Vector.s
                     Pickles_types.Vector.s
                     Pickles_types.Vector.s )
                   Pickles_types.Vector.t
                 * ( 'f
                   * ( ( 'g
                       , Pickles_types.Vector.z Pickles_types.Vector.s )
                       Pickles_types.Vector.t
                     * unit ) ) ) ) ) )
           Pickles_types.Hlist.HlistId.t

      val of_data :
           ( ( 'a
             , Pickles_types.Vector.z Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s
               Pickles_types.Vector.s )
             Pickles_types.Vector.t
           * ( ( 'b
               , Pickles_types.Vector.z Pickles_types.Vector.s
                 Pickles_types.Vector.s )
               Pickles_types.Vector.t
             * ( ( 'c
                 , Pickles_types.Vector.z Pickles_types.Vector.s
                   Pickles_types.Vector.s
                   Pickles_types.Vector.s )
                 Pickles_types.Vector.t
               * ( ( 'd
                   , Pickles_types.Vector.z Pickles_types.Vector.s
                     Pickles_types.Vector.s
                     Pickles_types.Vector.s )
                   Pickles_types.Vector.t
                 * ( 'e
                   * ( ( 'f
                       , Pickles_types.Vector.z Pickles_types.Vector.s )
                       Pickles_types.Vector.t
                     * unit ) ) ) ) ) )
           Pickles_types.Hlist.HlistId.t
        -> ('b, 'c, 'a, 'g, 'd, 'd, 'd, 'e Pickles_types__Hlist0.Id.t, 'f) t
    end

    val to_minimal :
         ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) In_circuit.t
      -> ('a, 'b, 'c, 'j, 'e, 'f, 'g, 'h, 'i) Minimal.t
  end
end

module Pairing_based : sig
  module Plonk_polys = Pickles_types.Vector.Nat.N10

  module Openings : sig
    module Evaluations : sig
      module By_point : sig
        type 'fq t =
          { beta_1 : 'fq; beta_2 : 'fq; beta_3 : 'fq; g_challenge : 'fq }
      end

      type 'fq t =
        ( 'fq By_point.t
        , Pickles_types.Vector.Nat.N10.n Pickles_types.Vector.s )
        Pickles_types.Vector.t
    end

    module Bulletproof : sig
      module Stable =
        Pickles_types__Dlog_plonk_types.Openings.Bulletproof.Stable

      type ('g, 'fq) t =
            ( 'g
            , 'fq )
            Pickles_types__Dlog_plonk_types.Openings.Bulletproof.Stable.Latest.t =
        { lr : ('g * 'g) Pickles_types__Dlog_plonk_types.Pc_array.t
        ; z_1 : 'fq
        ; z_2 : 'fq
        ; delta : 'g
        ; sg : 'g
        }

      val to_yojson :
           ('g -> Yojson.Safe.t)
        -> ('fq -> Yojson.Safe.t)
        -> ('g, 'fq) t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'g Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('g, 'fq) t Ppx_deriving_yojson_runtime.error_or

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'g)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('g, 'fq) t

      val sexp_of_t :
           ('g -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('g, 'fq) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val compare :
           ('g -> 'g -> Core_kernel__.Import.int)
        -> ('fq -> 'fq -> Core_kernel__.Import.int)
        -> ('g, 'fq) t
        -> ('g, 'fq) t
        -> Core_kernel__.Import.int

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'g -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'fq -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('g, 'fq) t
        -> Ppx_hash_lib.Std.Hash.state

      val equal :
           ('g -> 'g -> bool)
        -> ('fq -> 'fq -> bool)
        -> ('g, 'fq) t
        -> ('g, 'fq) t
        -> bool

      val to_hlist :
           ('g, 'fq) t
        -> ( unit
           ,    ('g * 'g) Pickles_types__Dlog_plonk_types.Pc_array.t
             -> 'fq
             -> 'fq
             -> 'g
             -> 'g
             -> unit )
           H_list.t

      val of_hlist :
           ( unit
           ,    ('g * 'g) Pickles_types__Dlog_plonk_types.Pc_array.t
             -> 'fq
             -> 'fq
             -> 'g
             -> 'g
             -> unit )
           H_list.t
        -> ('g, 'fq) t

      val typ :
           ( 'a
           , 'b
           , 'c Snarky_backendless__.Checked.field
           , ( unit
             , unit
             , 'c Snarky_backendless__.Checked.field )
             Snarky_backendless__.Checked.t )
           Snarky_backendless__.Types.Typ.t
        -> ( 'd
           , 'e
           , 'c Snarky_backendless__.Checked.field )
           Snarky_backendless.Typ.t
        -> length:Core_kernel__.Import.int
        -> ( ('d, 'a) t
           , ('e, 'b) t
           , 'c Snarky_backendless__.Checked.field )
           Snarky_backendless.Typ.t

      module Advice : sig
        type ('fq, 'g) t = { b : 'fq }

        val to_hlist : ('fq, 'g) t -> (unit, 'fq -> unit) H_list.t

        val of_hlist : (unit, 'fq -> unit) H_list.t -> ('fq, 'g) t

        val typ :
             ( 'a
             , 'b
             , 'c Snarky_backendless__.Checked.field
             , ( unit
               , unit
               , 'c Snarky_backendless__.Checked.field )
               Snarky_backendless__.Checked.t )
             Snarky_backendless__.Types.Typ.t
          -> 'd
          -> ( ('a, 'e) t
             , ('b, 'f) t
             , 'c Snarky_backendless__.Checked.field )
             Snarky_backendless.Typ.t
      end
    end

    type ('fq, 'g) t =
      { evaluations : 'fq Evaluations.t; proof : ('fq, 'g) Bulletproof.t }
  end

  module Proof_state : sig
    module Deferred_values : sig
      module Plonk = Dlog_based.Proof_state.Deferred_values.Plonk

      type ('plonk, 'scalar_challenge, 'fq, 'bulletproof_challenges) t_ =
        { plonk : 'plonk
        ; combined_inner_product : 'fq
        ; xi : 'scalar_challenge
        ; bulletproof_challenges : 'bulletproof_challenges
        ; b : 'fq
        }

      val t__to_yojson :
           ('plonk -> Yojson.Safe.t)
        -> ('scalar_challenge -> Yojson.Safe.t)
        -> ('fq -> Yojson.Safe.t)
        -> ('bulletproof_challenges -> Yojson.Safe.t)
        -> ('plonk, 'scalar_challenge, 'fq, 'bulletproof_challenges) t_
        -> Yojson.Safe.t

      val t__of_yojson :
           (Yojson.Safe.t -> 'plonk Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'bulletproof_challenges Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('plonk, 'scalar_challenge, 'fq, 'bulletproof_challenges) t_
           Ppx_deriving_yojson_runtime.error_or

      val t__of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'plonk)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'bulletproof_challenges)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('plonk, 'scalar_challenge, 'fq, 'bulletproof_challenges) t_

      val sexp_of_t_ :
           ('plonk -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('bulletproof_challenges -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('plonk, 'scalar_challenge, 'fq, 'bulletproof_challenges) t_
        -> Ppx_sexp_conv_lib.Sexp.t

      val compare_t_ :
           ('plonk -> 'plonk -> int)
        -> ('scalar_challenge -> 'scalar_challenge -> int)
        -> ('fq -> 'fq -> int)
        -> ('bulletproof_challenges -> 'bulletproof_challenges -> int)
        -> ('plonk, 'scalar_challenge, 'fq, 'bulletproof_challenges) t_
        -> ('plonk, 'scalar_challenge, 'fq, 'bulletproof_challenges) t_
        -> int

      module Minimal : sig
        type ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t =
          ( ('challenge, 'scalar_challenge) Plonk.Minimal.t
          , 'scalar_challenge
          , 'fq
          , 'bulletproof_challenges )
          t_

        val to_yojson :
             ('challenge -> Yojson.Safe.t)
          -> ('scalar_challenge -> Yojson.Safe.t)
          -> ('fq -> Yojson.Safe.t)
          -> ('bulletproof_challenges -> Yojson.Safe.t)
          -> ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t
          -> Yojson.Safe.t

        val of_yojson :
             (Yojson.Safe.t -> 'challenge Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'bulletproof_challenges Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t
             Ppx_deriving_yojson_runtime.error_or

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'bulletproof_challenges)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t

        val sexp_of_t :
             ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('bulletproof_challenges -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t
          -> Ppx_sexp_conv_lib.Sexp.t

        val compare :
             ('challenge -> 'challenge -> int)
          -> ('scalar_challenge -> 'scalar_challenge -> int)
          -> ('fq -> 'fq -> int)
          -> ('bulletproof_challenges -> 'bulletproof_challenges -> int)
          -> ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t
          -> ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t
          -> int
      end

      module In_circuit : sig
        type ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t =
          ( ('challenge, 'scalar_challenge, 'fq) Plonk.In_circuit.t
          , 'scalar_challenge
          , 'fq
          , 'bulletproof_challenges )
          t_

        val to_yojson :
             ('challenge -> Yojson.Safe.t)
          -> ('scalar_challenge -> Yojson.Safe.t)
          -> ('fq -> Yojson.Safe.t)
          -> ('bulletproof_challenges -> Yojson.Safe.t)
          -> ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t
          -> Yojson.Safe.t

        val of_yojson :
             (Yojson.Safe.t -> 'challenge Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'bulletproof_challenges Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t
             Ppx_deriving_yojson_runtime.error_or

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'bulletproof_challenges)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t

        val sexp_of_t :
             ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('bulletproof_challenges -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t
          -> Ppx_sexp_conv_lib.Sexp.t

        val compare :
             ('challenge -> 'challenge -> int)
          -> ('scalar_challenge -> 'scalar_challenge -> int)
          -> ('fq -> 'fq -> int)
          -> ('bulletproof_challenges -> 'bulletproof_challenges -> int)
          -> ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t
          -> ('challenge, 'scalar_challenge, 'fq, 'bulletproof_challenges) t
          -> int
      end
    end

    module Pass_through = Dlog_based.Proof_state.Me_only
    module Me_only = Dlog_based.Pass_through

    module Per_proof : sig
      type ( 'plonk
           , 'scalar_challenge
           , 'fq
           , 'bulletproof_challenges
           , 'digest
           , 'bool )
           t_ =
        { deferred_values :
            ( 'plonk
            , 'scalar_challenge
            , 'fq
            , 'bulletproof_challenges )
            Deferred_values.t_
        ; should_finalize : 'bool
        ; sponge_digest_before_evaluations : 'digest
        }

      val t__to_yojson :
           ('plonk -> Yojson.Safe.t)
        -> ('scalar_challenge -> Yojson.Safe.t)
        -> ('fq -> Yojson.Safe.t)
        -> ('bulletproof_challenges -> Yojson.Safe.t)
        -> ('digest -> Yojson.Safe.t)
        -> ('bool -> Yojson.Safe.t)
        -> ( 'plonk
           , 'scalar_challenge
           , 'fq
           , 'bulletproof_challenges
           , 'digest
           , 'bool )
           t_
        -> Yojson.Safe.t

      val t__of_yojson :
           (Yojson.Safe.t -> 'plonk Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'bulletproof_challenges Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'digest Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'bool Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ( 'plonk
           , 'scalar_challenge
           , 'fq
           , 'bulletproof_challenges
           , 'digest
           , 'bool )
           t_
           Ppx_deriving_yojson_runtime.error_or

      val t__of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'plonk)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'bulletproof_challenges)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'digest)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'bool)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ( 'plonk
           , 'scalar_challenge
           , 'fq
           , 'bulletproof_challenges
           , 'digest
           , 'bool )
           t_

      val sexp_of_t_ :
           ('plonk -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('bulletproof_challenges -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('digest -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('bool -> Ppx_sexp_conv_lib.Sexp.t)
        -> ( 'plonk
           , 'scalar_challenge
           , 'fq
           , 'bulletproof_challenges
           , 'digest
           , 'bool )
           t_
        -> Ppx_sexp_conv_lib.Sexp.t

      val compare_t_ :
           ('plonk -> 'plonk -> int)
        -> ('scalar_challenge -> 'scalar_challenge -> int)
        -> ('fq -> 'fq -> int)
        -> ('bulletproof_challenges -> 'bulletproof_challenges -> int)
        -> ('digest -> 'digest -> int)
        -> ('bool -> 'bool -> int)
        -> ( 'plonk
           , 'scalar_challenge
           , 'fq
           , 'bulletproof_challenges
           , 'digest
           , 'bool )
           t_
        -> ( 'plonk
           , 'scalar_challenge
           , 'fq
           , 'bulletproof_challenges
           , 'digest
           , 'bool )
           t_
        -> int

      module Minimal : sig
        type ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t =
          ( ('challenge, 'scalar_challenge) Deferred_values.Plonk.Minimal.t
          , 'scalar_challenge
          , 'fq
          , 'bulletproof_challenges
          , 'digest
          , 'bool )
          t_

        val to_yojson :
             ('challenge -> Yojson.Safe.t)
          -> ('scalar_challenge -> Yojson.Safe.t)
          -> ('fq -> Yojson.Safe.t)
          -> ('bulletproof_challenges -> Yojson.Safe.t)
          -> ('digest -> Yojson.Safe.t)
          -> ('bool -> Yojson.Safe.t)
          -> ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t
          -> Yojson.Safe.t

        val of_yojson :
             (Yojson.Safe.t -> 'challenge Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'bulletproof_challenges Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'digest Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'bool Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t
             Ppx_deriving_yojson_runtime.error_or

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'bulletproof_challenges)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'digest)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'bool)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t

        val sexp_of_t :
             ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('bulletproof_challenges -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('digest -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('bool -> Ppx_sexp_conv_lib.Sexp.t)
          -> ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t
          -> Ppx_sexp_conv_lib.Sexp.t

        val compare :
             ('challenge -> 'challenge -> int)
          -> ('scalar_challenge -> 'scalar_challenge -> int)
          -> ('fq -> 'fq -> int)
          -> ('bulletproof_challenges -> 'bulletproof_challenges -> int)
          -> ('digest -> 'digest -> int)
          -> ('bool -> 'bool -> int)
          -> ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t
          -> ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t
          -> int
      end

      module In_circuit : sig
        type ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t =
          ( ( 'challenge
            , 'scalar_challenge
            , 'fq )
            Deferred_values.Plonk.In_circuit.t
          , 'scalar_challenge
          , 'fq
          , 'bulletproof_challenges
          , 'digest
          , 'bool )
          t_

        val to_yojson :
             ('challenge -> Yojson.Safe.t)
          -> ('scalar_challenge -> Yojson.Safe.t)
          -> ('fq -> Yojson.Safe.t)
          -> ('bulletproof_challenges -> Yojson.Safe.t)
          -> ('digest -> Yojson.Safe.t)
          -> ('bool -> Yojson.Safe.t)
          -> ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t
          -> Yojson.Safe.t

        val of_yojson :
             (Yojson.Safe.t -> 'challenge Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'scalar_challenge Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'fq Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'bulletproof_challenges Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'digest Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'bool Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t
             Ppx_deriving_yojson_runtime.error_or

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'challenge)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'scalar_challenge)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'fq)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'bulletproof_challenges)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'digest)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'bool)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t

        val sexp_of_t :
             ('challenge -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('scalar_challenge -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('fq -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('bulletproof_challenges -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('digest -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('bool -> Ppx_sexp_conv_lib.Sexp.t)
          -> ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t
          -> Ppx_sexp_conv_lib.Sexp.t

        val compare :
             ('challenge -> 'challenge -> int)
          -> ('scalar_challenge -> 'scalar_challenge -> int)
          -> ('fq -> 'fq -> int)
          -> ('bulletproof_challenges -> 'bulletproof_challenges -> int)
          -> ('digest -> 'digest -> int)
          -> ('bool -> 'bool -> int)
          -> ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t
          -> ( 'challenge
             , 'scalar_challenge
             , 'fq
             , 'bulletproof_challenges
             , 'digest
             , 'bool )
             t
          -> int

        val spec :
             'a Pickles_types.Nat.t
          -> ( ( ( 'b
                 , Pickles_types__Nat.z Pickles_types__Nat.N13.plus_n
                   Pickles_types__Nat.s )
                 Pickles_types.Vector.t
               * ( ( 'c
                   , Pickles_types__Nat.z Pickles_types__Nat.N0.plus_n
                     Pickles_types__Nat.s )
                   Pickles_types.Vector.t
                 * ( ( 'd
                     , Pickles_types__Nat.z Pickles_types__Nat.N1.plus_n
                       Pickles_types__Nat.s )
                     Pickles_types.Vector.t
                   * ( ( 'd Pickles_types.Scalar_challenge.t
                       , Pickles_types__Nat.z Pickles_types__Nat.N2.plus_n
                         Pickles_types__Nat.s )
                       Pickles_types.Vector.t
                     * ( ('e, 'a) Pickles_types.Vector.t
                       * ( ( 'f
                           , Pickles_types__Nat.z Pickles_types__Nat.N0.plus_n
                             Pickles_types__Nat.s )
                           Pickles_types.Vector.t
                         * unit ) ) ) ) ) )
               Pickles_types.Hlist.HlistId.t
             , ( ( 'g
                 , Pickles_types__Nat.z Pickles_types__Nat.N13.plus_n
                   Pickles_types__Nat.s )
                 Pickles_types.Vector.t
               * ( ( 'h
                   , Pickles_types__Nat.z Pickles_types__Nat.N0.plus_n
                     Pickles_types__Nat.s )
                   Pickles_types.Vector.t
                 * ( ( 'i
                     , Pickles_types__Nat.z Pickles_types__Nat.N1.plus_n
                       Pickles_types__Nat.s )
                     Pickles_types.Vector.t
                   * ( ( 'i Pickles_types.Scalar_challenge.t
                       , Pickles_types__Nat.z Pickles_types__Nat.N2.plus_n
                         Pickles_types__Nat.s )
                       Pickles_types.Vector.t
                     * ( ('j, 'a) Pickles_types.Vector.t
                       * ( ( 'k
                           , Pickles_types__Nat.z Pickles_types__Nat.N0.plus_n
                             Pickles_types__Nat.s )
                           Pickles_types.Vector.t
                         * unit ) ) ) ) ) )
               Pickles_types.Hlist.HlistId.t
             , < bool1 : 'f
               ; bool2 : 'k
               ; bulletproof_challenge1 : 'e
               ; bulletproof_challenge2 : 'j
               ; challenge1 : 'd
               ; challenge2 : 'i
               ; digest1 : 'c
               ; digest2 : 'h
               ; field1 : 'b
               ; field2 : 'g
               ; .. > )
             Spec.t

        val to_data :
             ('a, 'b, 'c, 'd Pickles_types__Hlist0.Id.t, 'e, 'f) t
          -> ( ( 'c
               , Pickles_types.Vector.z Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s )
               Pickles_types.Vector.t
             * ( ( 'e
                 , Pickles_types.Vector.z Pickles_types.Vector.s )
                 Pickles_types.Vector.t
               * ( ( 'a
                   , Pickles_types.Vector.z Pickles_types.Vector.s
                     Pickles_types.Vector.s )
                   Pickles_types.Vector.t
                 * ( ( 'b
                     , Pickles_types.Vector.z Pickles_types.Vector.s
                       Pickles_types.Vector.s
                       Pickles_types.Vector.s )
                     Pickles_types.Vector.t
                   * ( 'd
                     * ( ( 'f
                         , Pickles_types.Vector.z Pickles_types.Vector.s )
                         Pickles_types.Vector.t
                       * unit ) ) ) ) ) )
             Pickles_types.Hlist.HlistId.t

        val of_data :
             ( ( 'a
               , Pickles_types.Vector.z Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s )
               Pickles_types.Vector.t
             * ( ( 'b
                 , Pickles_types.Vector.z Pickles_types.Vector.s )
                 Pickles_types.Vector.t
               * ( ( 'c
                   , Pickles_types.Vector.z Pickles_types.Vector.s
                     Pickles_types.Vector.s )
                   Pickles_types.Vector.t
                 * ( ( 'd
                     , Pickles_types.Vector.z Pickles_types.Vector.s
                       Pickles_types.Vector.s
                       Pickles_types.Vector.s )
                     Pickles_types.Vector.t
                   * ( 'e
                     * ( ( 'f
                         , Pickles_types.Vector.z Pickles_types.Vector.s )
                         Pickles_types.Vector.t
                       * unit ) ) ) ) ) )
             Pickles_types.Hlist.HlistId.t
          -> ('c, 'd, 'a, 'e Pickles_types__Hlist0.Id.t, 'b, 'f) t
      end
    end

    type ('unfinalized_proofs, 'me_only) t =
      { unfinalized_proofs : 'unfinalized_proofs; me_only : 'me_only }

    val to_yojson :
         ('unfinalized_proofs -> Yojson.Safe.t)
      -> ('me_only -> Yojson.Safe.t)
      -> ('unfinalized_proofs, 'me_only) t
      -> Yojson.Safe.t

    val of_yojson :
         (   Yojson.Safe.t
          -> 'unfinalized_proofs Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'me_only Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> ('unfinalized_proofs, 'me_only) t Ppx_deriving_yojson_runtime.error_or

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'unfinalized_proofs)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'me_only)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> ('unfinalized_proofs, 'me_only) t

    val sexp_of_t :
         ('unfinalized_proofs -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('me_only -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('unfinalized_proofs, 'me_only) t
      -> Ppx_sexp_conv_lib.Sexp.t

    val compare :
         ('unfinalized_proofs -> 'unfinalized_proofs -> int)
      -> ('me_only -> 'me_only -> int)
      -> ('unfinalized_proofs, 'me_only) t
      -> ('unfinalized_proofs, 'me_only) t
      -> int

    val spec :
         ('a, 'b, 'c) Spec.T.t
      -> ('d, 'e, 'c) Spec.T.t
      -> ( ('a * ('d * unit)) Pickles_types.Hlist.HlistId.t
         , ('b * ('e * unit)) Pickles_types.Hlist.HlistId.t
         , 'c )
         Spec.t

    val to_data :
         ( ( ( 'a
             , 'b
             , 'c
             , 'd Pickles_types__Hlist0.Id.t
             , 'e
             , 'f )
             Per_proof.In_circuit.t
           , 'g )
           Pickles_types.Vector.t
         , 'h Pickles_types__Hlist0.Id.t )
         t
      -> ( ( ( ( 'c
               , Pickles_types.Vector.z Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s )
               Pickles_types.Vector.t
             * ( ( 'e
                 , Pickles_types.Vector.z Pickles_types.Vector.s )
                 Pickles_types.Vector.t
               * ( ( 'a
                   , Pickles_types.Vector.z Pickles_types.Vector.s
                     Pickles_types.Vector.s )
                   Pickles_types.Vector.t
                 * ( ( 'b
                     , Pickles_types.Vector.z Pickles_types.Vector.s
                       Pickles_types.Vector.s
                       Pickles_types.Vector.s )
                     Pickles_types.Vector.t
                   * ( 'd
                     * ( ( 'f
                         , Pickles_types.Vector.z Pickles_types.Vector.s )
                         Pickles_types.Vector.t
                       * unit ) ) ) ) ) )
             Pickles_types.Hlist.HlistId.t
           , 'g )
           Pickles_types.Vector.t
         * ('h * unit) )
         Pickles_types.Hlist.HlistId.t

    val of_data :
         ( ( ( ( 'a
               , Pickles_types.Vector.z Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s )
               Pickles_types.Vector.t
             * ( ( 'b
                 , Pickles_types.Vector.z Pickles_types.Vector.s )
                 Pickles_types.Vector.t
               * ( ( 'c
                   , Pickles_types.Vector.z Pickles_types.Vector.s
                     Pickles_types.Vector.s )
                   Pickles_types.Vector.t
                 * ( ( 'd
                     , Pickles_types.Vector.z Pickles_types.Vector.s
                       Pickles_types.Vector.s
                       Pickles_types.Vector.s )
                     Pickles_types.Vector.t
                   * ( 'e
                     * ( ( 'f
                         , Pickles_types.Vector.z Pickles_types.Vector.s )
                         Pickles_types.Vector.t
                       * unit ) ) ) ) ) )
             Pickles_types.Hlist.HlistId.t
           , 'g )
           Pickles_types.Vector.t
         * ('h * unit) )
         Pickles_types.Hlist.HlistId.t
      -> ( ( ( 'c
             , 'd
             , 'a
             , 'e Pickles_types__Hlist0.Id.t
             , 'b
             , 'f )
             Per_proof.In_circuit.t
           , 'g )
           Pickles_types.Vector.t
         , 'h Pickles_types__Hlist0.Id.t )
         t

    val typ :
         (module Snarky_backendless.Snark_intf.Run with type field = 'a)
      -> 'b Pickles_types.Nat.t
      -> ( 'c
         , 'd
         , 'a
         , (unit, unit, 'a) Snarky_backendless__.Checked.t )
         Snarky_backendless__.Types.Typ.t
      -> ( ( ( ( 'a Limb_vector__Challenge.t
               , 'a Limb_vector__Challenge.t Pickles_types.Scalar_challenge.t
               , 'c
               , ( 'a Limb_vector__Challenge.t Pickles_types.Scalar_challenge.t
                   Bulletproof_challenge.t
                 , Pickles_types__Nat.z Backend.Tock.Rounds.plus_n )
                 Pickles_types.Vector.t
                 Pickles_types__Hlist0.Id.t
               , 'a Snarky_backendless__.Cvar.t
               , 'a Snarky_backendless__.Cvar.t
                 Snarky_backendless.Snark_intf.Boolean0.t )
               Per_proof.In_circuit.t
             , 'b )
             Pickles_types.Vector.t
           , 'a Snarky_backendless__.Cvar.t Pickles_types__Hlist0.Id.t )
           t
         , ( ( ( Limb_vector__Challenge.Constant.t
               , Limb_vector__Challenge.Constant.t
                 Pickles_types.Scalar_challenge.t
               , 'd
               , ( Limb_vector__Challenge.Constant.t
                   Pickles_types.Scalar_challenge.t
                   Bulletproof_challenge.t
                 , Pickles_types__Nat.z Backend.Tock.Rounds.plus_n )
                 Pickles_types.Vector.t
                 Pickles_types__Hlist0.Id.t
               , ( Limb_vector__Constant.Hex64.t
                 , Composition_types__Digest.Limbs.n )
                 Pickles_types__Vector.vec
               , bool )
               Per_proof.In_circuit.t
             , 'b )
             Pickles_types.Vector.t
           , ( Limb_vector__Constant.Hex64.t
             , Composition_types__Digest.Limbs.n )
             Pickles_types__Vector.vec
             Pickles_types__Hlist0.Id.t )
           t
         , 'a )
         Snarky_backendless.Typ.t
  end

  module Statement : sig
    type ('unfinalized_proofs, 'me_only, 'pass_through) t =
      { proof_state : ('unfinalized_proofs, 'me_only) Proof_state.t
      ; pass_through : 'pass_through
      }

    val to_yojson :
         ('unfinalized_proofs -> Yojson.Safe.t)
      -> ('me_only -> Yojson.Safe.t)
      -> ('pass_through -> Yojson.Safe.t)
      -> ('unfinalized_proofs, 'me_only, 'pass_through) t
      -> Yojson.Safe.t

    val of_yojson :
         (   Yojson.Safe.t
          -> 'unfinalized_proofs Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'me_only Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'pass_through Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> ('unfinalized_proofs, 'me_only, 'pass_through) t
         Ppx_deriving_yojson_runtime.error_or

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'unfinalized_proofs)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'me_only)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'pass_through)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> ('unfinalized_proofs, 'me_only, 'pass_through) t

    val sexp_of_t :
         ('unfinalized_proofs -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('me_only -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('pass_through -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('unfinalized_proofs, 'me_only, 'pass_through) t
      -> Ppx_sexp_conv_lib.Sexp.t

    val compare :
         ('unfinalized_proofs -> 'unfinalized_proofs -> int)
      -> ('me_only -> 'me_only -> int)
      -> ('pass_through -> 'pass_through -> int)
      -> ('unfinalized_proofs, 'me_only, 'pass_through) t
      -> ('unfinalized_proofs, 'me_only, 'pass_through) t
      -> int

    val to_data :
         ( ( ( 'a
             , 'b
             , 'c
             , 'd Pickles_types__Hlist0.Id.t
             , 'e
             , 'f )
             Proof_state.Per_proof.In_circuit.t
           , 'g )
           Pickles_types.Vector.t
         , 'h Pickles_types__Hlist0.Id.t
         , 'i Pickles_types__Hlist0.Id.t )
         t
      -> ( ( ( ( 'c
               , Pickles_types.Vector.z Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s )
               Pickles_types.Vector.t
             * ( ( 'e
                 , Pickles_types.Vector.z Pickles_types.Vector.s )
                 Pickles_types.Vector.t
               * ( ( 'a
                   , Pickles_types.Vector.z Pickles_types.Vector.s
                     Pickles_types.Vector.s )
                   Pickles_types.Vector.t
                 * ( ( 'b
                     , Pickles_types.Vector.z Pickles_types.Vector.s
                       Pickles_types.Vector.s
                       Pickles_types.Vector.s )
                     Pickles_types.Vector.t
                   * ( 'd
                     * ( ( 'f
                         , Pickles_types.Vector.z Pickles_types.Vector.s )
                         Pickles_types.Vector.t
                       * unit ) ) ) ) ) )
             Pickles_types.Hlist.HlistId.t
           , 'g )
           Pickles_types.Vector.t
         * ('h * ('i * unit)) )
         Pickles_types.Hlist.HlistId.t

    val of_data :
         ( ( ( ( 'a
               , Pickles_types.Vector.z Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s
                 Pickles_types.Vector.s )
               Pickles_types.Vector.t
             * ( ( 'b
                 , Pickles_types.Vector.z Pickles_types.Vector.s )
                 Pickles_types.Vector.t
               * ( ( 'c
                   , Pickles_types.Vector.z Pickles_types.Vector.s
                     Pickles_types.Vector.s )
                   Pickles_types.Vector.t
                 * ( ( 'd
                     , Pickles_types.Vector.z Pickles_types.Vector.s
                       Pickles_types.Vector.s
                       Pickles_types.Vector.s )
                     Pickles_types.Vector.t
                   * ( 'e
                     * ( ( 'f
                         , Pickles_types.Vector.z Pickles_types.Vector.s )
                         Pickles_types.Vector.t
                       * unit ) ) ) ) ) )
             Pickles_types.Hlist.HlistId.t
           , 'g )
           Pickles_types.Vector.t
         * ('h * ('i * unit)) )
         Pickles_types.Hlist.HlistId.t
      -> ( ( ( 'c
             , 'd
             , 'a
             , 'e Pickles_types__Hlist0.Id.t
             , 'b
             , 'f )
             Proof_state.Per_proof.In_circuit.t
           , 'g )
           Pickles_types.Vector.t
         , 'h Pickles_types__Hlist0.Id.t
         , 'i Pickles_types__Hlist0.Id.t )
         t

    val spec :
         'a Pickles_types.Nat.t
      -> 'b Pickles_types.Nat.t
      -> ( ( ( ( ( 'c
                 , Pickles_types__Nat.z Pickles_types__Nat.N13.plus_n
                   Pickles_types__Nat.s )
                 Pickles_types.Vector.t
               * ( ( 'd
                   , Pickles_types__Nat.z Pickles_types__Nat.N0.plus_n
                     Pickles_types__Nat.s )
                   Pickles_types.Vector.t
                 * ( ( 'e
                     , Pickles_types__Nat.z Pickles_types__Nat.N1.plus_n
                       Pickles_types__Nat.s )
                     Pickles_types.Vector.t
                   * ( ( 'e Pickles_types.Scalar_challenge.t
                       , Pickles_types__Nat.z Pickles_types__Nat.N2.plus_n
                         Pickles_types__Nat.s )
                       Pickles_types.Vector.t
                     * ( ('f, 'b) Pickles_types.Vector.t
                       * ( ( 'g
                           , Pickles_types__Nat.z Pickles_types__Nat.N0.plus_n
                             Pickles_types__Nat.s )
                           Pickles_types.Vector.t
                         * unit ) ) ) ) ) )
               Pickles_types.Hlist.HlistId.t
             , 'a )
             Pickles_types.Vector.t
           * ('d * (('d, 'a) Pickles_types.Vector.t * unit)) )
           Pickles_types.Hlist.HlistId.t
         , ( ( ( ( 'h
                 , Pickles_types__Nat.z Pickles_types__Nat.N13.plus_n
                   Pickles_types__Nat.s )
                 Pickles_types.Vector.t
               * ( ( 'i
                   , Pickles_types__Nat.z Pickles_types__Nat.N0.plus_n
                     Pickles_types__Nat.s )
                   Pickles_types.Vector.t
                 * ( ( 'j
                     , Pickles_types__Nat.z Pickles_types__Nat.N1.plus_n
                       Pickles_types__Nat.s )
                     Pickles_types.Vector.t
                   * ( ( 'j Pickles_types.Scalar_challenge.t
                       , Pickles_types__Nat.z Pickles_types__Nat.N2.plus_n
                         Pickles_types__Nat.s )
                       Pickles_types.Vector.t
                     * ( ('k, 'b) Pickles_types.Vector.t
                       * ( ( 'l
                           , Pickles_types__Nat.z Pickles_types__Nat.N0.plus_n
                             Pickles_types__Nat.s )
                           Pickles_types.Vector.t
                         * unit ) ) ) ) ) )
               Pickles_types.Hlist.HlistId.t
             , 'a )
             Pickles_types.Vector.t
           * ('i * (('i, 'a) Pickles_types.Vector.t * unit)) )
           Pickles_types.Hlist.HlistId.t
         , < bool1 : 'g
           ; bool2 : 'l
           ; bulletproof_challenge1 : 'f
           ; bulletproof_challenge2 : 'k
           ; challenge1 : 'e
           ; challenge2 : 'j
           ; digest1 : 'd
           ; digest2 : 'i
           ; field1 : 'c
           ; field2 : 'h
           ; .. > )
         Spec.t
  end
end

module Nvector = Pickles_types.Vector.With_length
module Wrap_bp_vec = Backend.Tock.Rounds_vector
module Step_bp_vec = Backend.Tick.Rounds_vector

module Challenges_vector : sig
  type 'n t =
    ( Backend.Tock.Field.t Snarky_backendless.Cvar.t Backend.Tock.Rounds_vector.t
    , 'n )
    Pickles_types.Vector.t

  module Constant : sig
    type 'n t =
      ( Backend.Tock.Field.t Backend.Tock.Rounds_vector.t
      , 'n )
      Pickles_types.Vector.t
  end
end
