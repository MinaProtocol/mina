module Git_sha : sig
  module Stable : sig
    module V1 : sig
      type t = string

      val to_yojson : t -> Yojson.Safe.t

      val version : int

      val __versioned__ : unit

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val equal : t -> t -> bool

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
      (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t))
      array

    val bin_read_to_latest_opt :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> V1.t option

    val __ :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> V1.t option
  end

  type t = Stable.V1.t

  val to_yojson : t -> Yojson.Safe.t

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val equal : t -> t -> bool

  val of_string : 'a -> 'a
end

module Status : sig
  val digest_entries :
    title:Git_sha.t -> (Git_sha.t * Git_sha.t) list -> Git_sha.t

  val summarize_report : Perf_histograms.Report.t -> Git_sha.t

  module Rpc_timings : sig
    module Rpc_pair : sig
      type 'a t = { dispatch : 'a; impl : 'a }

      val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

      val bin_shape_t :
        Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

      val __bin_read_t__ :
           'a Core_kernel.Bin_prot.Read.reader
        -> (int -> 'a t) Core_kernel.Bin_prot.Read.reader

      val bin_read_t :
           'a Core_kernel.Bin_prot.Read.reader
        -> 'a t Core_kernel.Bin_prot.Read.reader

      val bin_reader_t :
           'a Core_kernel.Bin_prot.Type_class.reader
        -> 'a t Core_kernel.Bin_prot.Type_class.reader

      val bin_size_t :
           'a Core_kernel.Bin_prot.Size.sizer
        -> 'a t Core_kernel.Bin_prot.Size.sizer

      val bin_write_t :
           'a Core_kernel.Bin_prot.Write.writer
        -> 'a t Core_kernel.Bin_prot.Write.writer

      val bin_writer_t :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'a t Core_kernel.Bin_prot.Type_class.writer

      val bin_t :
           'a Core_kernel.Bin_prot.Type_class.t
        -> 'a t Core_kernel.Bin_prot.Type_class.t

      val impl : 'a t -> 'a

      val dispatch : 'a t -> 'a

      module Fields : sig
        val names : Git_sha.t list

        val impl :
          ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm

        val dispatch :
          ([< `Read | `Set_and_create ], 'a t, 'a) Fieldslib.Field.t_with_perm

        val make_creator :
             dispatch:
               (   ( [< `Read | `Set_and_create ]
                   , 'a t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> 'b
                -> ('c -> 'd) * 'e)
          -> impl:
               (   ( [< `Read | `Set_and_create ]
                   , 'f t
                   , 'f )
                   Fieldslib.Field.t_with_perm
                -> 'e
                -> ('c -> 'd) * 'g)
          -> 'b
          -> ('c -> 'd t) * 'g

        val create : dispatch:'a -> impl:'a -> 'a t

        val map :
             dispatch:
               (   ( [< `Read | `Set_and_create ]
                   , 'a t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> 'b)
          -> impl:
               (   ( [< `Read | `Set_and_create ]
                   , 'c t
                   , 'c )
                   Fieldslib.Field.t_with_perm
                -> 'b)
          -> 'b t

        val iter :
             dispatch:
               (   ( [< `Read | `Set_and_create ]
                   , 'a t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> impl:
               (   ( [< `Read | `Set_and_create ]
                   , 'b t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> unit

        val fold :
             init:'a
          -> dispatch:
               (   'a
                -> ( [< `Read | `Set_and_create ]
                   , 'b t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> 'c)
          -> impl:
               (   'c
                -> ( [< `Read | `Set_and_create ]
                   , 'd t
                   , 'd )
                   Fieldslib.Field.t_with_perm
                -> 'e)
          -> 'e

        val map_poly :
             ([< `Read | `Set_and_create ], 'a t, 'b) Fieldslib.Field.user
          -> 'b list

        val for_all :
             dispatch:
               (   ( [< `Read | `Set_and_create ]
                   , 'a t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> impl:
               (   ( [< `Read | `Set_and_create ]
                   , 'b t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bool

        val exists :
             dispatch:
               (   ( [< `Read | `Set_and_create ]
                   , 'a t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> impl:
               (   ( [< `Read | `Set_and_create ]
                   , 'b t
                   , 'b )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bool

        val to_list :
             dispatch:
               (   ( [< `Read | `Set_and_create ]
                   , 'a t
                   , 'a )
                   Fieldslib.Field.t_with_perm
                -> 'b)
          -> impl:
               (   ( [< `Read | `Set_and_create ]
                   , 'c t
                   , 'c )
                   Fieldslib.Field.t_with_perm
                -> 'b)
          -> 'b list

        module Direct : sig
          val iter :
               'a t
            -> dispatch:
                 (   ( [< `Read | `Set_and_create ]
                     , 'b t
                     , 'b )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> unit)
            -> impl:
                 (   ( [< `Read | `Set_and_create ]
                     , 'c t
                     , 'c )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> 'd)
            -> 'd

          val fold :
               'a t
            -> init:'b
            -> dispatch:
                 (   'b
                  -> ( [< `Read | `Set_and_create ]
                     , 'c t
                     , 'c )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> 'd)
            -> impl:
                 (   'd
                  -> ( [< `Read | `Set_and_create ]
                     , 'e t
                     , 'e )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> 'f)
            -> 'f

          val for_all :
               'a t
            -> dispatch:
                 (   ( [< `Read | `Set_and_create ]
                     , 'b t
                     , 'b )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> bool)
            -> impl:
                 (   ( [< `Read | `Set_and_create ]
                     , 'c t
                     , 'c )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> bool)
            -> bool

          val exists :
               'a t
            -> dispatch:
                 (   ( [< `Read | `Set_and_create ]
                     , 'b t
                     , 'b )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> bool)
            -> impl:
                 (   ( [< `Read | `Set_and_create ]
                     , 'c t
                     , 'c )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> bool)
            -> bool

          val to_list :
               'a t
            -> dispatch:
                 (   ( [< `Read | `Set_and_create ]
                     , 'b t
                     , 'b )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> 'c)
            -> impl:
                 (   ( [< `Read | `Set_and_create ]
                     , 'd t
                     , 'd )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> 'c)
            -> 'c list

          val map :
               'a t
            -> dispatch:
                 (   ( [< `Read | `Set_and_create ]
                     , 'b t
                     , 'b )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> 'c)
            -> impl:
                 (   ( [< `Read | `Set_and_create ]
                     , 'd t
                     , 'd )
                     Fieldslib.Field.t_with_perm
                  -> 'a t
                  -> 'a
                  -> 'c)
            -> 'c t

          val set_all_mutable_fields : 'a -> unit
        end
      end
    end

    type t =
      { get_staged_ledger_aux : Perf_histograms.Report.t option Rpc_pair.t
      ; answer_sync_ledger_query : Perf_histograms.Report.t option Rpc_pair.t
      ; get_ancestry : Perf_histograms.Report.t option Rpc_pair.t
      ; get_transition_chain_proof : Perf_histograms.Report.t option Rpc_pair.t
      ; get_transition_chain : Perf_histograms.Report.t option Rpc_pair.t
      }

    val to_yojson : t -> Yojson.Safe.t

    val bin_shape_t : Core_kernel.Bin_prot.Shape.t

    val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

    val bin_read_t : t Core_kernel.Bin_prot.Read.reader

    val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

    val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

    val bin_write_t : t Core_kernel.Bin_prot.Write.writer

    val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

    val bin_t : t Core_kernel.Bin_prot.Type_class.t

    val get_transition_chain : t -> Perf_histograms.Report.t option Rpc_pair.t

    val get_transition_chain_proof :
      t -> Perf_histograms.Report.t option Rpc_pair.t

    val get_ancestry : t -> Perf_histograms.Report.t option Rpc_pair.t

    val answer_sync_ledger_query :
      t -> Perf_histograms.Report.t option Rpc_pair.t

    val get_staged_ledger_aux : t -> Perf_histograms.Report.t option Rpc_pair.t

    module Fields : sig
      val names : Git_sha.t list

      val get_transition_chain :
        ( [< `Read | `Set_and_create ]
        , t
        , Perf_histograms.Report.t option Rpc_pair.t )
        Fieldslib.Field.t_with_perm

      val get_transition_chain_proof :
        ( [< `Read | `Set_and_create ]
        , t
        , Perf_histograms.Report.t option Rpc_pair.t )
        Fieldslib.Field.t_with_perm

      val get_ancestry :
        ( [< `Read | `Set_and_create ]
        , t
        , Perf_histograms.Report.t option Rpc_pair.t )
        Fieldslib.Field.t_with_perm

      val answer_sync_ledger_query :
        ( [< `Read | `Set_and_create ]
        , t
        , Perf_histograms.Report.t option Rpc_pair.t )
        Fieldslib.Field.t_with_perm

      val get_staged_ledger_aux :
        ( [< `Read | `Set_and_create ]
        , t
        , Perf_histograms.Report.t option Rpc_pair.t )
        Fieldslib.Field.t_with_perm

      val make_creator :
           get_staged_ledger_aux:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> 'a
              -> ('b -> Perf_histograms.Report.t option Rpc_pair.t) * 'c)
        -> answer_sync_ledger_query:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> 'c
              -> ('b -> Perf_histograms.Report.t option Rpc_pair.t) * 'd)
        -> get_ancestry:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> 'd
              -> ('b -> Perf_histograms.Report.t option Rpc_pair.t) * 'e)
        -> get_transition_chain_proof:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> 'e
              -> ('b -> Perf_histograms.Report.t option Rpc_pair.t) * 'f)
        -> get_transition_chain:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> 'f
              -> ('b -> Perf_histograms.Report.t option Rpc_pair.t) * 'g)
        -> 'a
        -> ('b -> t) * 'g

      val create :
           get_staged_ledger_aux:Perf_histograms.Report.t option Rpc_pair.t
        -> answer_sync_ledger_query:Perf_histograms.Report.t option Rpc_pair.t
        -> get_ancestry:Perf_histograms.Report.t option Rpc_pair.t
        -> get_transition_chain_proof:Perf_histograms.Report.t option Rpc_pair.t
        -> get_transition_chain:Perf_histograms.Report.t option Rpc_pair.t
        -> t

      val map :
           get_staged_ledger_aux:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> Perf_histograms.Report.t option Rpc_pair.t)
        -> answer_sync_ledger_query:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> Perf_histograms.Report.t option Rpc_pair.t)
        -> get_ancestry:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> Perf_histograms.Report.t option Rpc_pair.t)
        -> get_transition_chain_proof:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> Perf_histograms.Report.t option Rpc_pair.t)
        -> get_transition_chain:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> Perf_histograms.Report.t option Rpc_pair.t)
        -> t

      val iter :
           get_staged_ledger_aux:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> answer_sync_ledger_query:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> get_ancestry:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> get_transition_chain_proof:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> get_transition_chain:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> unit

      val fold :
           init:'a
        -> get_staged_ledger_aux:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> 'b)
        -> answer_sync_ledger_query:
             (   'b
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> 'c)
        -> get_ancestry:
             (   'c
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> 'd)
        -> get_transition_chain_proof:
             (   'd
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> 'e)
        -> get_transition_chain:
             (   'e
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> 'f)
        -> 'f

      val map_poly :
        ([< `Read | `Set_and_create ], t, 'a) Fieldslib.Field.user -> 'a list

      val for_all :
           get_staged_ledger_aux:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> answer_sync_ledger_query:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> get_ancestry:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> get_transition_chain_proof:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> get_transition_chain:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val exists :
           get_staged_ledger_aux:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> answer_sync_ledger_query:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> get_ancestry:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> get_transition_chain_proof:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> get_transition_chain:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val to_list :
           get_staged_ledger_aux:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> answer_sync_ledger_query:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> get_ancestry:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> get_transition_chain_proof:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> get_transition_chain:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option Rpc_pair.t )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> 'a list

      module Direct : sig
        val iter :
             t
          -> get_staged_ledger_aux:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> unit)
          -> answer_sync_ledger_query:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> unit)
          -> get_ancestry:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> unit)
          -> get_transition_chain_proof:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> unit)
          -> get_transition_chain:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> 'a)
          -> 'a

        val fold :
             t
          -> init:'a
          -> get_staged_ledger_aux:
               (   'a
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> 'b)
          -> answer_sync_ledger_query:
               (   'b
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> 'c)
          -> get_ancestry:
               (   'c
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> 'd)
          -> get_transition_chain_proof:
               (   'd
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> 'e)
          -> get_transition_chain:
               (   'e
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> 'f)
          -> 'f

        val for_all :
             t
          -> get_staged_ledger_aux:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> bool)
          -> answer_sync_ledger_query:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> bool)
          -> get_ancestry:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> bool)
          -> get_transition_chain_proof:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> bool)
          -> get_transition_chain:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> bool)
          -> bool

        val exists :
             t
          -> get_staged_ledger_aux:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> bool)
          -> answer_sync_ledger_query:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> bool)
          -> get_ancestry:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> bool)
          -> get_transition_chain_proof:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> bool)
          -> get_transition_chain:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> bool)
          -> bool

        val to_list :
             t
          -> get_staged_ledger_aux:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> 'a)
          -> answer_sync_ledger_query:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> 'a)
          -> get_ancestry:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> 'a)
          -> get_transition_chain_proof:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> 'a)
          -> get_transition_chain:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> 'a)
          -> 'a list

        val map :
             t
          -> get_staged_ledger_aux:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> Perf_histograms.Report.t option Rpc_pair.t)
          -> answer_sync_ledger_query:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> Perf_histograms.Report.t option Rpc_pair.t)
          -> get_ancestry:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> Perf_histograms.Report.t option Rpc_pair.t)
          -> get_transition_chain_proof:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> Perf_histograms.Report.t option Rpc_pair.t)
          -> get_transition_chain:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option Rpc_pair.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option Rpc_pair.t
                -> Perf_histograms.Report.t option Rpc_pair.t)
          -> t

        val set_all_mutable_fields : 'a -> unit
      end
    end

    val to_text : t -> Git_sha.t
  end

  module Histograms : sig
    type t =
      { rpc_timings : Rpc_timings.t
      ; external_transition_latency : Perf_histograms.Report.t option
      ; accepted_transition_local_latency : Perf_histograms.Report.t option
      ; accepted_transition_remote_latency : Perf_histograms.Report.t option
      ; snark_worker_transition_time : Perf_histograms.Report.t option
      ; snark_worker_merge_time : Perf_histograms.Report.t option
      }

    val to_yojson : t -> Yojson.Safe.t

    val bin_shape_t : Core_kernel.Bin_prot.Shape.t

    val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

    val bin_read_t : t Core_kernel.Bin_prot.Read.reader

    val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

    val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

    val bin_write_t : t Core_kernel.Bin_prot.Write.writer

    val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

    val bin_t : t Core_kernel.Bin_prot.Type_class.t

    val snark_worker_merge_time : t -> Perf_histograms.Report.t option

    val snark_worker_transition_time : t -> Perf_histograms.Report.t option

    val accepted_transition_remote_latency :
      t -> Perf_histograms.Report.t option

    val accepted_transition_local_latency : t -> Perf_histograms.Report.t option

    val external_transition_latency : t -> Perf_histograms.Report.t option

    val rpc_timings : t -> Rpc_timings.t

    module Fields : sig
      val names : Git_sha.t list

      val snark_worker_merge_time :
        ( [< `Read | `Set_and_create ]
        , t
        , Perf_histograms.Report.t option )
        Fieldslib.Field.t_with_perm

      val snark_worker_transition_time :
        ( [< `Read | `Set_and_create ]
        , t
        , Perf_histograms.Report.t option )
        Fieldslib.Field.t_with_perm

      val accepted_transition_remote_latency :
        ( [< `Read | `Set_and_create ]
        , t
        , Perf_histograms.Report.t option )
        Fieldslib.Field.t_with_perm

      val accepted_transition_local_latency :
        ( [< `Read | `Set_and_create ]
        , t
        , Perf_histograms.Report.t option )
        Fieldslib.Field.t_with_perm

      val external_transition_latency :
        ( [< `Read | `Set_and_create ]
        , t
        , Perf_histograms.Report.t option )
        Fieldslib.Field.t_with_perm

      val rpc_timings :
        ( [< `Read | `Set_and_create ]
        , t
        , Rpc_timings.t )
        Fieldslib.Field.t_with_perm

      val make_creator :
           rpc_timings:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Rpc_timings.t )
                 Fieldslib.Field.t_with_perm
              -> 'a
              -> ('b -> Rpc_timings.t) * 'c)
        -> external_transition_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> 'c
              -> ('b -> Perf_histograms.Report.t option) * 'd)
        -> accepted_transition_local_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> 'd
              -> ('b -> Perf_histograms.Report.t option) * 'e)
        -> accepted_transition_remote_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> 'e
              -> ('b -> Perf_histograms.Report.t option) * 'f)
        -> snark_worker_transition_time:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> 'f
              -> ('b -> Perf_histograms.Report.t option) * 'g)
        -> snark_worker_merge_time:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> 'g
              -> ('b -> Perf_histograms.Report.t option) * 'h)
        -> 'a
        -> ('b -> t) * 'h

      val create :
           rpc_timings:Rpc_timings.t
        -> external_transition_latency:Perf_histograms.Report.t option
        -> accepted_transition_local_latency:Perf_histograms.Report.t option
        -> accepted_transition_remote_latency:Perf_histograms.Report.t option
        -> snark_worker_transition_time:Perf_histograms.Report.t option
        -> snark_worker_merge_time:Perf_histograms.Report.t option
        -> t

      val map :
           rpc_timings:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Rpc_timings.t )
                 Fieldslib.Field.t_with_perm
              -> Rpc_timings.t)
        -> external_transition_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> Perf_histograms.Report.t option)
        -> accepted_transition_local_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> Perf_histograms.Report.t option)
        -> accepted_transition_remote_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> Perf_histograms.Report.t option)
        -> snark_worker_transition_time:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> Perf_histograms.Report.t option)
        -> snark_worker_merge_time:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> Perf_histograms.Report.t option)
        -> t

      val iter :
           rpc_timings:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Rpc_timings.t )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> external_transition_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> accepted_transition_local_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> accepted_transition_remote_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> snark_worker_transition_time:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> snark_worker_merge_time:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> unit

      val fold :
           init:'a
        -> rpc_timings:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Rpc_timings.t )
                 Fieldslib.Field.t_with_perm
              -> 'b)
        -> external_transition_latency:
             (   'b
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> 'c)
        -> accepted_transition_local_latency:
             (   'c
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> 'd)
        -> accepted_transition_remote_latency:
             (   'd
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> 'e)
        -> snark_worker_transition_time:
             (   'e
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> 'f)
        -> snark_worker_merge_time:
             (   'f
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> 'g)
        -> 'g

      val map_poly :
        ([< `Read | `Set_and_create ], t, 'a) Fieldslib.Field.user -> 'a list

      val for_all :
           rpc_timings:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Rpc_timings.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> external_transition_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> accepted_transition_local_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> accepted_transition_remote_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> snark_worker_transition_time:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> snark_worker_merge_time:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val exists :
           rpc_timings:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Rpc_timings.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> external_transition_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> accepted_transition_local_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> accepted_transition_remote_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> snark_worker_transition_time:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> snark_worker_merge_time:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val to_list :
           rpc_timings:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Rpc_timings.t )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> external_transition_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> accepted_transition_local_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> accepted_transition_remote_latency:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> snark_worker_transition_time:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> snark_worker_merge_time:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Perf_histograms.Report.t option )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> 'a list

      module Direct : sig
        val iter :
             t
          -> rpc_timings:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Rpc_timings.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Rpc_timings.t
                -> unit)
          -> external_transition_latency:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> unit)
          -> accepted_transition_local_latency:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> unit)
          -> accepted_transition_remote_latency:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> unit)
          -> snark_worker_transition_time:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> unit)
          -> snark_worker_merge_time:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> 'a)
          -> 'a

        val fold :
             t
          -> init:'a
          -> rpc_timings:
               (   'a
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , Rpc_timings.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Rpc_timings.t
                -> 'b)
          -> external_transition_latency:
               (   'b
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> 'c)
          -> accepted_transition_local_latency:
               (   'c
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> 'd)
          -> accepted_transition_remote_latency:
               (   'd
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> 'e)
          -> snark_worker_transition_time:
               (   'e
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> 'f)
          -> snark_worker_merge_time:
               (   'f
                -> ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> 'g)
          -> 'g

        val for_all :
             t
          -> rpc_timings:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Rpc_timings.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Rpc_timings.t
                -> bool)
          -> external_transition_latency:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> bool)
          -> accepted_transition_local_latency:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> bool)
          -> accepted_transition_remote_latency:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> bool)
          -> snark_worker_transition_time:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> bool)
          -> snark_worker_merge_time:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> bool)
          -> bool

        val exists :
             t
          -> rpc_timings:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Rpc_timings.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Rpc_timings.t
                -> bool)
          -> external_transition_latency:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> bool)
          -> accepted_transition_local_latency:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> bool)
          -> accepted_transition_remote_latency:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> bool)
          -> snark_worker_transition_time:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> bool)
          -> snark_worker_merge_time:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> bool)
          -> bool

        val to_list :
             t
          -> rpc_timings:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Rpc_timings.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Rpc_timings.t
                -> 'a)
          -> external_transition_latency:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> 'a)
          -> accepted_transition_local_latency:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> 'a)
          -> accepted_transition_remote_latency:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> 'a)
          -> snark_worker_transition_time:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> 'a)
          -> snark_worker_merge_time:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> 'a)
          -> 'a list

        val map :
             t
          -> rpc_timings:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Rpc_timings.t )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Rpc_timings.t
                -> Rpc_timings.t)
          -> external_transition_latency:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> Perf_histograms.Report.t option)
          -> accepted_transition_local_latency:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> Perf_histograms.Report.t option)
          -> accepted_transition_remote_latency:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> Perf_histograms.Report.t option)
          -> snark_worker_transition_time:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> Perf_histograms.Report.t option)
          -> snark_worker_merge_time:
               (   ( [< `Read | `Set_and_create ]
                   , t
                   , Perf_histograms.Report.t option )
                   Fieldslib.Field.t_with_perm
                -> t
                -> Perf_histograms.Report.t option
                -> Perf_histograms.Report.t option)
          -> t

        val set_all_mutable_fields : 'a -> unit
      end
    end

    val to_text : t -> Git_sha.t
  end

  module Next_producer_timing : sig
    type slot =
      { slot : Mina_numbers.Global_slot.Stable.Latest.t
      ; global_slot_since_genesis : Mina_numbers.Global_slot.Stable.Latest.t
      }

    val slot_to_yojson : slot -> Yojson.Safe.t

    val global_slot_since_genesis :
      slot -> Mina_numbers.Global_slot.Stable.Latest.t

    val slot : slot -> Mina_numbers.Global_slot.Stable.Latest.t

    module Fields_of_slot : sig
      val names : Git_sha.t list

      val global_slot_since_genesis :
        ( [< `Read | `Set_and_create ]
        , slot
        , Mina_numbers.Global_slot.Stable.Latest.t )
        Fieldslib.Field.t_with_perm

      val slot :
        ( [< `Read | `Set_and_create ]
        , slot
        , Mina_numbers.Global_slot.Stable.Latest.t )
        Fieldslib.Field.t_with_perm

      val make_creator :
           slot:
             (   ( [< `Read | `Set_and_create ]
                 , slot
                 , Mina_numbers.Global_slot.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> 'a
              -> ('b -> Mina_numbers.Global_slot.Stable.Latest.t) * 'c)
        -> global_slot_since_genesis:
             (   ( [< `Read | `Set_and_create ]
                 , slot
                 , Mina_numbers.Global_slot.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> 'c
              -> ('b -> Mina_numbers.Global_slot.Stable.Latest.t) * 'd)
        -> 'a
        -> ('b -> slot) * 'd

      val create :
           slot:Mina_numbers.Global_slot.Stable.Latest.t
        -> global_slot_since_genesis:Mina_numbers.Global_slot.Stable.Latest.t
        -> slot

      val map :
           slot:
             (   ( [< `Read | `Set_and_create ]
                 , slot
                 , Mina_numbers.Global_slot.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> Mina_numbers.Global_slot.Stable.Latest.t)
        -> global_slot_since_genesis:
             (   ( [< `Read | `Set_and_create ]
                 , slot
                 , Mina_numbers.Global_slot.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> Mina_numbers.Global_slot.Stable.Latest.t)
        -> slot

      val iter :
           slot:
             (   ( [< `Read | `Set_and_create ]
                 , slot
                 , Mina_numbers.Global_slot.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> global_slot_since_genesis:
             (   ( [< `Read | `Set_and_create ]
                 , slot
                 , Mina_numbers.Global_slot.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> unit

      val fold :
           init:'a
        -> slot:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , slot
                 , Mina_numbers.Global_slot.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> 'b)
        -> global_slot_since_genesis:
             (   'b
              -> ( [< `Read | `Set_and_create ]
                 , slot
                 , Mina_numbers.Global_slot.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> 'c)
        -> 'c

      val map_poly :
        ([< `Read | `Set_and_create ], slot, 'a) Fieldslib.Field.user -> 'a list

      val for_all :
           slot:
             (   ( [< `Read | `Set_and_create ]
                 , slot
                 , Mina_numbers.Global_slot.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> global_slot_since_genesis:
             (   ( [< `Read | `Set_and_create ]
                 , slot
                 , Mina_numbers.Global_slot.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val exists :
           slot:
             (   ( [< `Read | `Set_and_create ]
                 , slot
                 , Mina_numbers.Global_slot.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> global_slot_since_genesis:
             (   ( [< `Read | `Set_and_create ]
                 , slot
                 , Mina_numbers.Global_slot.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val to_list :
           slot:
             (   ( [< `Read | `Set_and_create ]
                 , slot
                 , Mina_numbers.Global_slot.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> global_slot_since_genesis:
             (   ( [< `Read | `Set_and_create ]
                 , slot
                 , Mina_numbers.Global_slot.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> 'a list

      module Direct : sig
        val iter :
             slot
          -> slot:
               (   ( [< `Read | `Set_and_create ]
                   , slot
                   , Mina_numbers.Global_slot.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> slot
                -> Mina_numbers.Global_slot.Stable.Latest.t
                -> unit)
          -> global_slot_since_genesis:
               (   ( [< `Read | `Set_and_create ]
                   , slot
                   , Mina_numbers.Global_slot.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> slot
                -> Mina_numbers.Global_slot.Stable.Latest.t
                -> 'a)
          -> 'a

        val fold :
             slot
          -> init:'a
          -> slot:
               (   'a
                -> ( [< `Read | `Set_and_create ]
                   , slot
                   , Mina_numbers.Global_slot.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> slot
                -> Mina_numbers.Global_slot.Stable.Latest.t
                -> 'b)
          -> global_slot_since_genesis:
               (   'b
                -> ( [< `Read | `Set_and_create ]
                   , slot
                   , Mina_numbers.Global_slot.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> slot
                -> Mina_numbers.Global_slot.Stable.Latest.t
                -> 'c)
          -> 'c

        val for_all :
             slot
          -> slot:
               (   ( [< `Read | `Set_and_create ]
                   , slot
                   , Mina_numbers.Global_slot.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> slot
                -> Mina_numbers.Global_slot.Stable.Latest.t
                -> bool)
          -> global_slot_since_genesis:
               (   ( [< `Read | `Set_and_create ]
                   , slot
                   , Mina_numbers.Global_slot.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> slot
                -> Mina_numbers.Global_slot.Stable.Latest.t
                -> bool)
          -> bool

        val exists :
             slot
          -> slot:
               (   ( [< `Read | `Set_and_create ]
                   , slot
                   , Mina_numbers.Global_slot.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> slot
                -> Mina_numbers.Global_slot.Stable.Latest.t
                -> bool)
          -> global_slot_since_genesis:
               (   ( [< `Read | `Set_and_create ]
                   , slot
                   , Mina_numbers.Global_slot.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> slot
                -> Mina_numbers.Global_slot.Stable.Latest.t
                -> bool)
          -> bool

        val to_list :
             slot
          -> slot:
               (   ( [< `Read | `Set_and_create ]
                   , slot
                   , Mina_numbers.Global_slot.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> slot
                -> Mina_numbers.Global_slot.Stable.Latest.t
                -> 'a)
          -> global_slot_since_genesis:
               (   ( [< `Read | `Set_and_create ]
                   , slot
                   , Mina_numbers.Global_slot.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> slot
                -> Mina_numbers.Global_slot.Stable.Latest.t
                -> 'a)
          -> 'a list

        val map :
             slot
          -> slot:
               (   ( [< `Read | `Set_and_create ]
                   , slot
                   , Mina_numbers.Global_slot.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> slot
                -> Mina_numbers.Global_slot.Stable.Latest.t
                -> Mina_numbers.Global_slot.Stable.Latest.t)
          -> global_slot_since_genesis:
               (   ( [< `Read | `Set_and_create ]
                   , slot
                   , Mina_numbers.Global_slot.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> slot
                -> Mina_numbers.Global_slot.Stable.Latest.t
                -> Mina_numbers.Global_slot.Stable.Latest.t)
          -> slot

        val set_all_mutable_fields : 'a -> unit
      end
    end

    val bin_shape_slot : Core_kernel.Bin_prot.Shape.t

    val __bin_read_slot__ : (int -> slot) Core_kernel.Bin_prot.Read.reader

    val bin_read_slot : slot Core_kernel.Bin_prot.Read.reader

    val bin_reader_slot : slot Core_kernel.Bin_prot.Type_class.reader

    val bin_size_slot : slot Core_kernel.Bin_prot.Size.sizer

    val bin_write_slot : slot Core_kernel.Bin_prot.Write.writer

    val bin_writer_slot : slot Core_kernel.Bin_prot.Type_class.writer

    val bin_slot : slot Core_kernel.Bin_prot.Type_class.t

    type producing_time = { time : Block_time.Stable.Latest.t; for_slot : slot }

    val producing_time_to_yojson : producing_time -> Yojson.Safe.t

    val bin_shape_producing_time : Core_kernel.Bin_prot.Shape.t

    val __bin_read_producing_time__ :
      (int -> producing_time) Core_kernel.Bin_prot.Read.reader

    val bin_read_producing_time :
      producing_time Core_kernel.Bin_prot.Read.reader

    val bin_reader_producing_time :
      producing_time Core_kernel.Bin_prot.Type_class.reader

    val bin_size_producing_time : producing_time Core_kernel.Bin_prot.Size.sizer

    val bin_write_producing_time :
      producing_time Core_kernel.Bin_prot.Write.writer

    val bin_writer_producing_time :
      producing_time Core_kernel.Bin_prot.Type_class.writer

    val bin_producing_time : producing_time Core_kernel.Bin_prot.Type_class.t

    val for_slot : producing_time -> slot

    val time : producing_time -> Block_time.Stable.Latest.t

    module Fields_of_producing_time : sig
      val names : Git_sha.t list

      val for_slot :
        ( [< `Read | `Set_and_create ]
        , producing_time
        , slot )
        Fieldslib.Field.t_with_perm

      val time :
        ( [< `Read | `Set_and_create ]
        , producing_time
        , Block_time.Stable.Latest.t )
        Fieldslib.Field.t_with_perm

      val make_creator :
           time:
             (   ( [< `Read | `Set_and_create ]
                 , producing_time
                 , Block_time.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> 'a
              -> ('b -> Block_time.Stable.Latest.t) * 'c)
        -> for_slot:
             (   ( [< `Read | `Set_and_create ]
                 , producing_time
                 , slot )
                 Fieldslib.Field.t_with_perm
              -> 'c
              -> ('b -> slot) * 'd)
        -> 'a
        -> ('b -> producing_time) * 'd

      val create :
        time:Block_time.Stable.Latest.t -> for_slot:slot -> producing_time

      val map :
           time:
             (   ( [< `Read | `Set_and_create ]
                 , producing_time
                 , Block_time.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> Block_time.Stable.Latest.t)
        -> for_slot:
             (   ( [< `Read | `Set_and_create ]
                 , producing_time
                 , slot )
                 Fieldslib.Field.t_with_perm
              -> slot)
        -> producing_time

      val iter :
           time:
             (   ( [< `Read | `Set_and_create ]
                 , producing_time
                 , Block_time.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> for_slot:
             (   ( [< `Read | `Set_and_create ]
                 , producing_time
                 , slot )
                 Fieldslib.Field.t_with_perm
              -> unit)
        -> unit

      val fold :
           init:'a
        -> time:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , producing_time
                 , Block_time.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> 'b)
        -> for_slot:
             (   'b
              -> ( [< `Read | `Set_and_create ]
                 , producing_time
                 , slot )
                 Fieldslib.Field.t_with_perm
              -> 'c)
        -> 'c

      val map_poly :
           ( [< `Read | `Set_and_create ]
           , producing_time
           , 'a )
           Fieldslib.Field.user
        -> 'a list

      val for_all :
           time:
             (   ( [< `Read | `Set_and_create ]
                 , producing_time
                 , Block_time.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> for_slot:
             (   ( [< `Read | `Set_and_create ]
                 , producing_time
                 , slot )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val exists :
           time:
             (   ( [< `Read | `Set_and_create ]
                 , producing_time
                 , Block_time.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> for_slot:
             (   ( [< `Read | `Set_and_create ]
                 , producing_time
                 , slot )
                 Fieldslib.Field.t_with_perm
              -> bool)
        -> bool

      val to_list :
           time:
             (   ( [< `Read | `Set_and_create ]
                 , producing_time
                 , Block_time.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> for_slot:
             (   ( [< `Read | `Set_and_create ]
                 , producing_time
                 , slot )
                 Fieldslib.Field.t_with_perm
              -> 'a)
        -> 'a list

      module Direct : sig
        val iter :
             producing_time
          -> time:
               (   ( [< `Read | `Set_and_create ]
                   , producing_time
                   , Block_time.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> producing_time
                -> Block_time.Stable.Latest.t
                -> unit)
          -> for_slot:
               (   ( [< `Read | `Set_and_create ]
                   , producing_time
                   , slot )
                   Fieldslib.Field.t_with_perm
                -> producing_time
                -> slot
                -> 'a)
          -> 'a

        val fold :
             producing_time
          -> init:'a
          -> time:
               (   'a
                -> ( [< `Read | `Set_and_create ]
                   , producing_time
                   , Block_time.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> producing_time
                -> Block_time.Stable.Latest.t
                -> 'b)
          -> for_slot:
               (   'b
                -> ( [< `Read | `Set_and_create ]
                   , producing_time
                   , slot )
                   Fieldslib.Field.t_with_perm
                -> producing_time
                -> slot
                -> 'c)
          -> 'c

        val for_all :
             producing_time
          -> time:
               (   ( [< `Read | `Set_and_create ]
                   , producing_time
                   , Block_time.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> producing_time
                -> Block_time.Stable.Latest.t
                -> bool)
          -> for_slot:
               (   ( [< `Read | `Set_and_create ]
                   , producing_time
                   , slot )
                   Fieldslib.Field.t_with_perm
                -> producing_time
                -> slot
                -> bool)
          -> bool

        val exists :
             producing_time
          -> time:
               (   ( [< `Read | `Set_and_create ]
                   , producing_time
                   , Block_time.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> producing_time
                -> Block_time.Stable.Latest.t
                -> bool)
          -> for_slot:
               (   ( [< `Read | `Set_and_create ]
                   , producing_time
                   , slot )
                   Fieldslib.Field.t_with_perm
                -> producing_time
                -> slot
                -> bool)
          -> bool

        val to_list :
             producing_time
          -> time:
               (   ( [< `Read | `Set_and_create ]
                   , producing_time
                   , Block_time.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> producing_time
                -> Block_time.Stable.Latest.t
                -> 'a)
          -> for_slot:
               (   ( [< `Read | `Set_and_create ]
                   , producing_time
                   , slot )
                   Fieldslib.Field.t_with_perm
                -> producing_time
                -> slot
                -> 'a)
          -> 'a list

        val map :
             producing_time
          -> time:
               (   ( [< `Read | `Set_and_create ]
                   , producing_time
                   , Block_time.Stable.Latest.t )
                   Fieldslib.Field.t_with_perm
                -> producing_time
                -> Block_time.Stable.Latest.t
                -> Block_time.Stable.Latest.t)
          -> for_slot:
               (   ( [< `Read | `Set_and_create ]
                   , producing_time
                   , slot )
                   Fieldslib.Field.t_with_perm
                -> producing_time
                -> slot
                -> slot)
          -> producing_time

        val set_all_mutable_fields : 'a -> unit
      end
    end

    type timing =
      | Check_again of Block_time.Stable.Latest.t
      | Produce of producing_time
      | Produce_now of producing_time
      | Evaluating_vrf of Mina_numbers.Global_slot.Stable.Latest.t

    val timing_to_yojson : timing -> Yojson.Safe.t

    val bin_shape_timing : Core_kernel.Bin_prot.Shape.t

    val __bin_read_timing__ : (int -> timing) Core_kernel.Bin_prot.Read.reader

    val bin_read_timing : timing Core_kernel.Bin_prot.Read.reader

    val bin_reader_timing : timing Core_kernel.Bin_prot.Type_class.reader

    val bin_size_timing : timing Core_kernel.Bin_prot.Size.sizer

    val bin_write_timing : timing Core_kernel.Bin_prot.Write.writer

    val bin_writer_timing : timing Core_kernel.Bin_prot.Type_class.writer

    val bin_timing : timing Core_kernel.Bin_prot.Type_class.t

    type t = { generated_from_consensus_at : slot; timing : timing }

    val to_yojson : t -> Yojson.Safe.t

    val bin_shape_t : Core_kernel.Bin_prot.Shape.t

    val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

    val bin_read_t : t Core_kernel.Bin_prot.Read.reader

    val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

    val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

    val bin_write_t : t Core_kernel.Bin_prot.Write.writer

    val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

    val bin_t : t Core_kernel.Bin_prot.Type_class.t
  end

  module Make_entries : functor
    (FieldT : sig
       type 'a t

       val get : 'a t -> 'a
     end)
    -> sig
    val map_entry :
      Git_sha.t -> f:('a -> 'b) -> 'a FieldT.t -> (Git_sha.t * 'b) option

    val string_entry :
      Git_sha.t -> Git_sha.t FieldT.t -> (Git_sha.t * Git_sha.t) option

    val int_entry :
      Git_sha.t -> Core_kernel.Int.t FieldT.t -> (Git_sha.t * Git_sha.t) option

    val bool_entry :
      Git_sha.t -> Core_kernel.Bool.t FieldT.t -> (Git_sha.t * Git_sha.t) option

    val option_entry :
         f:('a -> Git_sha.t)
      -> Git_sha.t
      -> 'a option FieldT.t
      -> (Git_sha.t * Git_sha.t) option

    val string_option_entry :
      Git_sha.t -> Git_sha.t option FieldT.t -> (Git_sha.t * Git_sha.t) option

    val int_option_entry :
         Git_sha.t
      -> Core_kernel.Int.t option FieldT.t
      -> (Git_sha.t * Git_sha.t) option

    val list_string_entry :
         Git_sha.t
      -> to_string:('a -> Core_kernel__.Import.string)
      -> 'a Core_kernel.List.t FieldT.t
      -> (Git_sha.t * Git_sha.t) option

    val num_accounts :
      Core_kernel.Int.t option FieldT.t -> (Git_sha.t * Git_sha.t) option

    val blockchain_length :
      Core_kernel.Int.t option FieldT.t -> (Git_sha.t * Git_sha.t) option

    val highest_block_length_received :
      Core_kernel.Int.t FieldT.t -> (Git_sha.t * Git_sha.t) option

    val highest_unvalidated_block_length_received :
      Core_kernel.Int.t FieldT.t -> (Git_sha.t * Git_sha.t) option

    val uptime_secs :
         Core_kernel__.Import.int FieldT.t
      -> (Git_sha.t * Core_kernel__.Import.string) option

    val ledger_merkle_root :
      Git_sha.t option FieldT.t -> (Git_sha.t * Git_sha.t) option

    val staged_ledger_hash :
      Git_sha.t option FieldT.t -> (Git_sha.t * Git_sha.t) option

    val state_hash : Git_sha.t option FieldT.t -> (Git_sha.t * Git_sha.t) option

    val chain_id : Git_sha.t FieldT.t -> (Git_sha.t * Git_sha.t) option

    val commit_id : Git_sha.t FieldT.t -> (Git_sha.t * Git_sha.t) option

    val conf_dir : Git_sha.t FieldT.t -> (Git_sha.t * Git_sha.t) option

    val peers : 'a list FieldT.t -> (Git_sha.t * Git_sha.t) option

    val user_commands_sent :
      Core_kernel.Int.t FieldT.t -> (Git_sha.t * Git_sha.t) option

    val snark_worker :
      Git_sha.t option FieldT.t -> (Git_sha.t * Git_sha.t) option

    val snark_work_fee :
      Core_kernel.Int.t FieldT.t -> (Git_sha.t * Git_sha.t) option

    val sync_status :
      Sync_status.Stable.Latest.t FieldT.t -> (Git_sha.t * Git_sha.t) option

    val block_production_keys :
         Core_kernel__.Import.string Core_kernel.List.t FieldT.t
      -> (Git_sha.t * Git_sha.t) option

    val coinbase_receiver :
      Git_sha.t option FieldT.t -> (Git_sha.t * Git_sha.t) option

    val histograms :
      Histograms.t option FieldT.t -> (Git_sha.t * Git_sha.t) option

    val next_block_production :
      Next_producer_timing.t option FieldT.t -> (Git_sha.t * Git_sha.t) option

    val consensus_time_best_tip :
         Consensus.Data.Consensus_time.t option FieldT.t
      -> (Git_sha.t * Git_sha.t) option

    val global_slot_since_genesis_best_tip :
      Core_kernel.Int.t option FieldT.t -> (Git_sha.t * Git_sha.t) option

    val consensus_time_now :
      Consensus.Data.Consensus_time.t FieldT.t -> (Git_sha.t * Git_sha.t) option

    val consensus_mechanism :
      Git_sha.t FieldT.t -> (Git_sha.t * Git_sha.t) option

    val consensus_configuration :
      Consensus.Configuration.t FieldT.t -> (Git_sha.t * Git_sha.t) option

    val addrs_and_ports :
         Node_addrs_and_ports.Display.Stable.V1.t FieldT.t
      -> (Git_sha.t * Git_sha.t) option

    val catchup_status :
         ( Transition_frontier.Full_catchup_tree.Node.State.Enum.t
         * Core_kernel.Int.t )
         list
         option
         FieldT.t
      -> (Git_sha.t * Git_sha.t) option
  end

  type t =
    { num_accounts : int option
    ; blockchain_length : int option
    ; highest_block_length_received : int
    ; highest_unvalidated_block_length_received : int
    ; uptime_secs : int
    ; ledger_merkle_root : Git_sha.t option
    ; state_hash : Git_sha.t option
    ; chain_id : Git_sha.t
    ; commit_id : Git_sha.t
    ; conf_dir : Git_sha.t
    ; peers : Network_peer.Peer.Display.Stable.Latest.t list
    ; user_commands_sent : int
    ; snark_worker : Git_sha.t option
    ; snark_work_fee : int
    ; sync_status : Sync_status.Stable.Latest.t
    ; catchup_status :
        (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int) list
        option
    ; block_production_keys : Git_sha.t list
    ; coinbase_receiver : Git_sha.t option
    ; histograms : Histograms.t option
    ; consensus_time_best_tip :
        Consensus.Data.Consensus_time.Stable.Latest.t option
    ; global_slot_since_genesis_best_tip : int option
    ; next_block_production : Next_producer_timing.t option
    ; consensus_time_now : Consensus.Data.Consensus_time.Stable.Latest.t
    ; consensus_mechanism : Git_sha.t
    ; consensus_configuration : Consensus.Configuration.Stable.Latest.t
    ; addrs_and_ports : Node_addrs_and_ports.Display.Stable.Latest.t
    }

  val to_yojson : t -> Yojson.Safe.t

  val bin_shape_t : Core_kernel.Bin_prot.Shape.t

  val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

  val bin_read_t : t Core_kernel.Bin_prot.Read.reader

  val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

  val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

  val bin_write_t : t Core_kernel.Bin_prot.Write.writer

  val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

  val bin_t : t Core_kernel.Bin_prot.Type_class.t

  val addrs_and_ports : t -> Node_addrs_and_ports.Display.Stable.Latest.t

  val consensus_configuration : t -> Consensus.Configuration.Stable.Latest.t

  val consensus_mechanism : t -> Git_sha.t

  val consensus_time_now : t -> Consensus.Data.Consensus_time.Stable.Latest.t

  val next_block_production : t -> Next_producer_timing.t option

  val global_slot_since_genesis_best_tip : t -> int option

  val consensus_time_best_tip :
    t -> Consensus.Data.Consensus_time.Stable.Latest.t option

  val histograms : t -> Histograms.t option

  val coinbase_receiver : t -> Git_sha.t option

  val block_production_keys : t -> Git_sha.t list

  val catchup_status :
       t
    -> (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int) list
       option

  val sync_status : t -> Sync_status.Stable.Latest.t

  val snark_work_fee : t -> int

  val snark_worker : t -> Git_sha.t option

  val user_commands_sent : t -> int

  val peers : t -> Network_peer.Peer.Display.Stable.Latest.t list

  val conf_dir : t -> Git_sha.t

  val commit_id : t -> Git_sha.t

  val chain_id : t -> Git_sha.t

  val state_hash : t -> Git_sha.t option

  val ledger_merkle_root : t -> Git_sha.t option

  val uptime_secs : t -> int

  val highest_unvalidated_block_length_received : t -> int

  val highest_block_length_received : t -> int

  val blockchain_length : t -> int option

  val num_accounts : t -> int option

  module Fields : sig
    val names : Git_sha.t list

    val addrs_and_ports :
      ( [< `Read | `Set_and_create ]
      , t
      , Node_addrs_and_ports.Display.Stable.Latest.t )
      Fieldslib.Field.t_with_perm

    val consensus_configuration :
      ( [< `Read | `Set_and_create ]
      , t
      , Consensus.Configuration.Stable.Latest.t )
      Fieldslib.Field.t_with_perm

    val consensus_mechanism :
      ([< `Read | `Set_and_create ], t, Git_sha.t) Fieldslib.Field.t_with_perm

    val consensus_time_now :
      ( [< `Read | `Set_and_create ]
      , t
      , Consensus.Data.Consensus_time.Stable.Latest.t )
      Fieldslib.Field.t_with_perm

    val next_block_production :
      ( [< `Read | `Set_and_create ]
      , t
      , Next_producer_timing.t option )
      Fieldslib.Field.t_with_perm

    val global_slot_since_genesis_best_tip :
      ([< `Read | `Set_and_create ], t, int option) Fieldslib.Field.t_with_perm

    val consensus_time_best_tip :
      ( [< `Read | `Set_and_create ]
      , t
      , Consensus.Data.Consensus_time.Stable.Latest.t option )
      Fieldslib.Field.t_with_perm

    val histograms :
      ( [< `Read | `Set_and_create ]
      , t
      , Histograms.t option )
      Fieldslib.Field.t_with_perm

    val coinbase_receiver :
      ( [< `Read | `Set_and_create ]
      , t
      , Git_sha.t option )
      Fieldslib.Field.t_with_perm

    val block_production_keys :
      ( [< `Read | `Set_and_create ]
      , t
      , Git_sha.t list )
      Fieldslib.Field.t_with_perm

    val catchup_status :
      ( [< `Read | `Set_and_create ]
      , t
      , (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int) list
        option )
      Fieldslib.Field.t_with_perm

    val sync_status :
      ( [< `Read | `Set_and_create ]
      , t
      , Sync_status.Stable.Latest.t )
      Fieldslib.Field.t_with_perm

    val snark_work_fee :
      ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm

    val snark_worker :
      ( [< `Read | `Set_and_create ]
      , t
      , Git_sha.t option )
      Fieldslib.Field.t_with_perm

    val user_commands_sent :
      ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm

    val peers :
      ( [< `Read | `Set_and_create ]
      , t
      , Network_peer.Peer.Display.Stable.Latest.t list )
      Fieldslib.Field.t_with_perm

    val conf_dir :
      ([< `Read | `Set_and_create ], t, Git_sha.t) Fieldslib.Field.t_with_perm

    val commit_id :
      ([< `Read | `Set_and_create ], t, Git_sha.t) Fieldslib.Field.t_with_perm

    val chain_id :
      ([< `Read | `Set_and_create ], t, Git_sha.t) Fieldslib.Field.t_with_perm

    val state_hash :
      ( [< `Read | `Set_and_create ]
      , t
      , Git_sha.t option )
      Fieldslib.Field.t_with_perm

    val ledger_merkle_root :
      ( [< `Read | `Set_and_create ]
      , t
      , Git_sha.t option )
      Fieldslib.Field.t_with_perm

    val uptime_secs :
      ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm

    val highest_unvalidated_block_length_received :
      ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm

    val highest_block_length_received :
      ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm

    val blockchain_length :
      ([< `Read | `Set_and_create ], t, int option) Fieldslib.Field.t_with_perm

    val num_accounts :
      ([< `Read | `Set_and_create ], t, int option) Fieldslib.Field.t_with_perm

    val make_creator :
         num_accounts:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> 'a
            -> ('b -> int option) * 'c)
      -> blockchain_length:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> 'c
            -> ('b -> int option) * 'd)
      -> highest_block_length_received:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> 'd
            -> ('b -> int) * 'e)
      -> highest_unvalidated_block_length_received:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> 'e
            -> ('b -> int) * 'f)
      -> uptime_secs:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> 'f
            -> ('b -> int) * 'g)
      -> ledger_merkle_root:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> 'g
            -> ('b -> Git_sha.t option) * 'h)
      -> state_hash:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> 'h
            -> ('b -> Git_sha.t option) * 'i)
      -> chain_id:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> 'i
            -> ('b -> Git_sha.t) * 'j)
      -> commit_id:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> 'j
            -> ('b -> Git_sha.t) * 'k)
      -> conf_dir:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> 'k
            -> ('b -> Git_sha.t) * 'l)
      -> peers:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Display.Stable.Latest.t list )
               Fieldslib.Field.t_with_perm
            -> 'l
            -> ('b -> Network_peer.Peer.Display.Stable.Latest.t list) * 'm)
      -> user_commands_sent:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> 'm
            -> ('b -> int) * 'n)
      -> snark_worker:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> 'n
            -> ('b -> Git_sha.t option) * 'o)
      -> snark_work_fee:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> 'o
            -> ('b -> int) * 'p)
      -> sync_status:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Sync_status.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> 'p
            -> ('b -> Sync_status.Stable.Latest.t) * 'q)
      -> catchup_status:
           (   ( [< `Read | `Set_and_create ]
               , t
               , (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int)
                 list
                 option )
               Fieldslib.Field.t_with_perm
            -> 'q
            -> (   'b
                -> ( Transition_frontier.Full_catchup_tree.Node.State.Enum.t
                   * int )
                   list
                   option)
               * 'r)
      -> block_production_keys:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t list )
               Fieldslib.Field.t_with_perm
            -> 'r
            -> ('b -> Git_sha.t list) * 's)
      -> coinbase_receiver:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> 's
            -> ('b -> Git_sha.t option) * 't)
      -> histograms:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Histograms.t option )
               Fieldslib.Field.t_with_perm
            -> 't
            -> ('b -> Histograms.t option) * 'u)
      -> consensus_time_best_tip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Consensus_time.Stable.Latest.t option )
               Fieldslib.Field.t_with_perm
            -> 'u
            -> ('b -> Consensus.Data.Consensus_time.Stable.Latest.t option) * 'v)
      -> global_slot_since_genesis_best_tip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> 'v
            -> ('b -> int option) * 'w)
      -> next_block_production:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Next_producer_timing.t option )
               Fieldslib.Field.t_with_perm
            -> 'w
            -> ('b -> Next_producer_timing.t option) * 'x)
      -> consensus_time_now:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Consensus_time.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> 'x
            -> ('b -> Consensus.Data.Consensus_time.Stable.Latest.t) * 'y)
      -> consensus_mechanism:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> 'y
            -> ('b -> Git_sha.t) * 'z)
      -> consensus_configuration:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Configuration.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> 'z
            -> ('b -> Consensus.Configuration.Stable.Latest.t) * 'a1)
      -> addrs_and_ports:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Node_addrs_and_ports.Display.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> 'a1
            -> ('b -> Node_addrs_and_ports.Display.Stable.Latest.t) * 'b1)
      -> 'a
      -> ('b -> t) * 'b1

    val create :
         num_accounts:int option
      -> blockchain_length:int option
      -> highest_block_length_received:int
      -> highest_unvalidated_block_length_received:int
      -> uptime_secs:int
      -> ledger_merkle_root:Git_sha.t option
      -> state_hash:Git_sha.t option
      -> chain_id:Git_sha.t
      -> commit_id:Git_sha.t
      -> conf_dir:Git_sha.t
      -> peers:Network_peer.Peer.Display.Stable.Latest.t list
      -> user_commands_sent:int
      -> snark_worker:Git_sha.t option
      -> snark_work_fee:int
      -> sync_status:Sync_status.Stable.Latest.t
      -> catchup_status:
           (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int) list
           option
      -> block_production_keys:Git_sha.t list
      -> coinbase_receiver:Git_sha.t option
      -> histograms:Histograms.t option
      -> consensus_time_best_tip:
           Consensus.Data.Consensus_time.Stable.Latest.t option
      -> global_slot_since_genesis_best_tip:int option
      -> next_block_production:Next_producer_timing.t option
      -> consensus_time_now:Consensus.Data.Consensus_time.Stable.Latest.t
      -> consensus_mechanism:Git_sha.t
      -> consensus_configuration:Consensus.Configuration.Stable.Latest.t
      -> addrs_and_ports:Node_addrs_and_ports.Display.Stable.Latest.t
      -> t

    val map :
         num_accounts:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> int option)
      -> blockchain_length:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> int option)
      -> highest_block_length_received:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> int)
      -> highest_unvalidated_block_length_received:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> int)
      -> uptime_secs:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> int)
      -> ledger_merkle_root:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> Git_sha.t option)
      -> state_hash:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> Git_sha.t option)
      -> chain_id:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> Git_sha.t)
      -> commit_id:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> Git_sha.t)
      -> conf_dir:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> Git_sha.t)
      -> peers:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Display.Stable.Latest.t list )
               Fieldslib.Field.t_with_perm
            -> Network_peer.Peer.Display.Stable.Latest.t list)
      -> user_commands_sent:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> int)
      -> snark_worker:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> Git_sha.t option)
      -> snark_work_fee:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> int)
      -> sync_status:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Sync_status.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> Sync_status.Stable.Latest.t)
      -> catchup_status:
           (   ( [< `Read | `Set_and_create ]
               , t
               , (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int)
                 list
                 option )
               Fieldslib.Field.t_with_perm
            -> (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int)
               list
               option)
      -> block_production_keys:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t list )
               Fieldslib.Field.t_with_perm
            -> Git_sha.t list)
      -> coinbase_receiver:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> Git_sha.t option)
      -> histograms:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Histograms.t option )
               Fieldslib.Field.t_with_perm
            -> Histograms.t option)
      -> consensus_time_best_tip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Consensus_time.Stable.Latest.t option )
               Fieldslib.Field.t_with_perm
            -> Consensus.Data.Consensus_time.Stable.Latest.t option)
      -> global_slot_since_genesis_best_tip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> int option)
      -> next_block_production:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Next_producer_timing.t option )
               Fieldslib.Field.t_with_perm
            -> Next_producer_timing.t option)
      -> consensus_time_now:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Consensus_time.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> Consensus.Data.Consensus_time.Stable.Latest.t)
      -> consensus_mechanism:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> Git_sha.t)
      -> consensus_configuration:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Configuration.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> Consensus.Configuration.Stable.Latest.t)
      -> addrs_and_ports:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Node_addrs_and_ports.Display.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> Node_addrs_and_ports.Display.Stable.Latest.t)
      -> t

    val iter :
         num_accounts:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> blockchain_length:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> highest_block_length_received:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> unit)
      -> highest_unvalidated_block_length_received:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> unit)
      -> uptime_secs:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> unit)
      -> ledger_merkle_root:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> state_hash:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> chain_id:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> commit_id:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> conf_dir:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> peers:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Display.Stable.Latest.t list )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> user_commands_sent:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> unit)
      -> snark_worker:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> snark_work_fee:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> unit)
      -> sync_status:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Sync_status.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> catchup_status:
           (   ( [< `Read | `Set_and_create ]
               , t
               , (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int)
                 list
                 option )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> block_production_keys:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t list )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> coinbase_receiver:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> histograms:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Histograms.t option )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> consensus_time_best_tip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Consensus_time.Stable.Latest.t option )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> global_slot_since_genesis_best_tip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> next_block_production:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Next_producer_timing.t option )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> consensus_time_now:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Consensus_time.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> consensus_mechanism:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> consensus_configuration:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Configuration.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> addrs_and_ports:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Node_addrs_and_ports.Display.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> unit

    val fold :
         init:'a
      -> num_accounts:
           (   'a
            -> ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> 'b)
      -> blockchain_length:
           (   'b
            -> ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> highest_block_length_received:
           (   'c
            -> ( [< `Read | `Set_and_create ]
               , t
               , int )
               Fieldslib.Field.t_with_perm
            -> 'd)
      -> highest_unvalidated_block_length_received:
           (   'd
            -> ( [< `Read | `Set_and_create ]
               , t
               , int )
               Fieldslib.Field.t_with_perm
            -> 'e)
      -> uptime_secs:
           (   'e
            -> ( [< `Read | `Set_and_create ]
               , t
               , int )
               Fieldslib.Field.t_with_perm
            -> 'f)
      -> ledger_merkle_root:
           (   'f
            -> ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> 'g)
      -> state_hash:
           (   'g
            -> ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> 'h)
      -> chain_id:
           (   'h
            -> ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> 'i)
      -> commit_id:
           (   'i
            -> ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> 'j)
      -> conf_dir:
           (   'j
            -> ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> 'k)
      -> peers:
           (   'k
            -> ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Display.Stable.Latest.t list )
               Fieldslib.Field.t_with_perm
            -> 'l)
      -> user_commands_sent:
           (   'l
            -> ( [< `Read | `Set_and_create ]
               , t
               , int )
               Fieldslib.Field.t_with_perm
            -> 'm)
      -> snark_worker:
           (   'm
            -> ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> 'n)
      -> snark_work_fee:
           (   'n
            -> ( [< `Read | `Set_and_create ]
               , t
               , int )
               Fieldslib.Field.t_with_perm
            -> 'o)
      -> sync_status:
           (   'o
            -> ( [< `Read | `Set_and_create ]
               , t
               , Sync_status.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> 'p)
      -> catchup_status:
           (   'p
            -> ( [< `Read | `Set_and_create ]
               , t
               , (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int)
                 list
                 option )
               Fieldslib.Field.t_with_perm
            -> 'q)
      -> block_production_keys:
           (   'q
            -> ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t list )
               Fieldslib.Field.t_with_perm
            -> 'r)
      -> coinbase_receiver:
           (   'r
            -> ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> 's)
      -> histograms:
           (   's
            -> ( [< `Read | `Set_and_create ]
               , t
               , Histograms.t option )
               Fieldslib.Field.t_with_perm
            -> 't)
      -> consensus_time_best_tip:
           (   't
            -> ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Consensus_time.Stable.Latest.t option )
               Fieldslib.Field.t_with_perm
            -> 'u)
      -> global_slot_since_genesis_best_tip:
           (   'u
            -> ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> 'v)
      -> next_block_production:
           (   'v
            -> ( [< `Read | `Set_and_create ]
               , t
               , Next_producer_timing.t option )
               Fieldslib.Field.t_with_perm
            -> 'w)
      -> consensus_time_now:
           (   'w
            -> ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Consensus_time.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> 'x)
      -> consensus_mechanism:
           (   'x
            -> ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> 'y)
      -> consensus_configuration:
           (   'y
            -> ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Configuration.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> 'z)
      -> addrs_and_ports:
           (   'z
            -> ( [< `Read | `Set_and_create ]
               , t
               , Node_addrs_and_ports.Display.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> 'a1)
      -> 'a1

    val map_poly :
      ([< `Read | `Set_and_create ], t, 'a) Fieldslib.Field.user -> 'a list

    val for_all :
         num_accounts:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> blockchain_length:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> highest_block_length_received:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> bool)
      -> highest_unvalidated_block_length_received:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> bool)
      -> uptime_secs:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> bool)
      -> ledger_merkle_root:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> state_hash:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> chain_id:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> commit_id:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> conf_dir:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> peers:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Display.Stable.Latest.t list )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> user_commands_sent:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> bool)
      -> snark_worker:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> snark_work_fee:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> bool)
      -> sync_status:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Sync_status.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> catchup_status:
           (   ( [< `Read | `Set_and_create ]
               , t
               , (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int)
                 list
                 option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> block_production_keys:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t list )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> coinbase_receiver:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> histograms:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Histograms.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> consensus_time_best_tip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Consensus_time.Stable.Latest.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> global_slot_since_genesis_best_tip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> next_block_production:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Next_producer_timing.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> consensus_time_now:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Consensus_time.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> consensus_mechanism:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> consensus_configuration:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Configuration.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> addrs_and_ports:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Node_addrs_and_ports.Display.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val exists :
         num_accounts:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> blockchain_length:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> highest_block_length_received:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> bool)
      -> highest_unvalidated_block_length_received:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> bool)
      -> uptime_secs:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> bool)
      -> ledger_merkle_root:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> state_hash:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> chain_id:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> commit_id:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> conf_dir:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> peers:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Display.Stable.Latest.t list )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> user_commands_sent:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> bool)
      -> snark_worker:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> snark_work_fee:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> bool)
      -> sync_status:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Sync_status.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> catchup_status:
           (   ( [< `Read | `Set_and_create ]
               , t
               , (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int)
                 list
                 option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> block_production_keys:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t list )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> coinbase_receiver:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> histograms:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Histograms.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> consensus_time_best_tip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Consensus_time.Stable.Latest.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> global_slot_since_genesis_best_tip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> next_block_production:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Next_producer_timing.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> consensus_time_now:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Consensus_time.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> consensus_mechanism:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> consensus_configuration:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Configuration.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> addrs_and_ports:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Node_addrs_and_ports.Display.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val to_list :
         num_accounts:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> blockchain_length:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> highest_block_length_received:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> 'a)
      -> highest_unvalidated_block_length_received:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> 'a)
      -> uptime_secs:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> 'a)
      -> ledger_merkle_root:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> state_hash:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> chain_id:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> commit_id:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> conf_dir:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> peers:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Network_peer.Peer.Display.Stable.Latest.t list )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> user_commands_sent:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> 'a)
      -> snark_worker:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> snark_work_fee:
           (   ([< `Read | `Set_and_create ], t, int) Fieldslib.Field.t_with_perm
            -> 'a)
      -> sync_status:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Sync_status.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> catchup_status:
           (   ( [< `Read | `Set_and_create ]
               , t
               , (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int)
                 list
                 option )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> block_production_keys:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t list )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> coinbase_receiver:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t option )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> histograms:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Histograms.t option )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> consensus_time_best_tip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Consensus_time.Stable.Latest.t option )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> global_slot_since_genesis_best_tip:
           (   ( [< `Read | `Set_and_create ]
               , t
               , int option )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> next_block_production:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Next_producer_timing.t option )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> consensus_time_now:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Consensus_time.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> consensus_mechanism:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Git_sha.t )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> consensus_configuration:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Configuration.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> addrs_and_ports:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Node_addrs_and_ports.Display.Stable.Latest.t )
               Fieldslib.Field.t_with_perm
            -> 'a)
      -> 'a list

    module Direct : sig
      val iter :
           t
        -> num_accounts:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> unit)
        -> blockchain_length:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> unit)
        -> highest_block_length_received:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> unit)
        -> highest_unvalidated_block_length_received:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> unit)
        -> uptime_secs:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> unit)
        -> ledger_merkle_root:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> unit)
        -> state_hash:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> unit)
        -> chain_id:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> unit)
        -> commit_id:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> unit)
        -> conf_dir:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> unit)
        -> peers:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Network_peer.Peer.Display.Stable.Latest.t list )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Network_peer.Peer.Display.Stable.Latest.t list
              -> unit)
        -> user_commands_sent:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> unit)
        -> snark_worker:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> unit)
        -> snark_work_fee:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> unit)
        -> sync_status:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Sync_status.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Sync_status.Stable.Latest.t
              -> unit)
        -> catchup_status:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , ( Transition_frontier.Full_catchup_tree.Node.State.Enum.t
                   * int )
                   list
                   option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int)
                 list
                 option
              -> unit)
        -> block_production_keys:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t list )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t list
              -> unit)
        -> coinbase_receiver:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> unit)
        -> histograms:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Histograms.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Histograms.t option
              -> unit)
        -> consensus_time_best_tip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Data.Consensus_time.Stable.Latest.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Data.Consensus_time.Stable.Latest.t option
              -> unit)
        -> global_slot_since_genesis_best_tip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> unit)
        -> next_block_production:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Next_producer_timing.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Next_producer_timing.t option
              -> unit)
        -> consensus_time_now:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Data.Consensus_time.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Data.Consensus_time.Stable.Latest.t
              -> unit)
        -> consensus_mechanism:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> unit)
        -> consensus_configuration:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Configuration.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Configuration.Stable.Latest.t
              -> unit)
        -> addrs_and_ports:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Node_addrs_and_ports.Display.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Node_addrs_and_ports.Display.Stable.Latest.t
              -> 'a)
        -> 'a

      val fold :
           t
        -> init:'a
        -> num_accounts:
             (   'a
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> 'b)
        -> blockchain_length:
             (   'b
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> 'c)
        -> highest_block_length_received:
             (   'c
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> 'd)
        -> highest_unvalidated_block_length_received:
             (   'd
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> 'e)
        -> uptime_secs:
             (   'e
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> 'f)
        -> ledger_merkle_root:
             (   'f
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> 'g)
        -> state_hash:
             (   'g
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> 'h)
        -> chain_id:
             (   'h
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> 'i)
        -> commit_id:
             (   'i
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> 'j)
        -> conf_dir:
             (   'j
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> 'k)
        -> peers:
             (   'k
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Network_peer.Peer.Display.Stable.Latest.t list )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Network_peer.Peer.Display.Stable.Latest.t list
              -> 'l)
        -> user_commands_sent:
             (   'l
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> 'm)
        -> snark_worker:
             (   'm
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> 'n)
        -> snark_work_fee:
             (   'n
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> 'o)
        -> sync_status:
             (   'o
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Sync_status.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Sync_status.Stable.Latest.t
              -> 'p)
        -> catchup_status:
             (   'p
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , ( Transition_frontier.Full_catchup_tree.Node.State.Enum.t
                   * int )
                   list
                   option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int)
                 list
                 option
              -> 'q)
        -> block_production_keys:
             (   'q
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t list )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t list
              -> 'r)
        -> coinbase_receiver:
             (   'r
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> 's)
        -> histograms:
             (   's
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Histograms.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Histograms.t option
              -> 't)
        -> consensus_time_best_tip:
             (   't
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Data.Consensus_time.Stable.Latest.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Data.Consensus_time.Stable.Latest.t option
              -> 'u)
        -> global_slot_since_genesis_best_tip:
             (   'u
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> 'v)
        -> next_block_production:
             (   'v
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Next_producer_timing.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Next_producer_timing.t option
              -> 'w)
        -> consensus_time_now:
             (   'w
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Data.Consensus_time.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Data.Consensus_time.Stable.Latest.t
              -> 'x)
        -> consensus_mechanism:
             (   'x
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> 'y)
        -> consensus_configuration:
             (   'y
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Configuration.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Configuration.Stable.Latest.t
              -> 'z)
        -> addrs_and_ports:
             (   'z
              -> ( [< `Read | `Set_and_create ]
                 , t
                 , Node_addrs_and_ports.Display.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Node_addrs_and_ports.Display.Stable.Latest.t
              -> 'a1)
        -> 'a1

      val for_all :
           t
        -> num_accounts:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> bool)
        -> blockchain_length:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> bool)
        -> highest_block_length_received:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> bool)
        -> highest_unvalidated_block_length_received:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> bool)
        -> uptime_secs:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> bool)
        -> ledger_merkle_root:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> bool)
        -> state_hash:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> bool)
        -> chain_id:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> bool)
        -> commit_id:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> bool)
        -> conf_dir:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> bool)
        -> peers:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Network_peer.Peer.Display.Stable.Latest.t list )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Network_peer.Peer.Display.Stable.Latest.t list
              -> bool)
        -> user_commands_sent:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> bool)
        -> snark_worker:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> bool)
        -> snark_work_fee:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> bool)
        -> sync_status:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Sync_status.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Sync_status.Stable.Latest.t
              -> bool)
        -> catchup_status:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , ( Transition_frontier.Full_catchup_tree.Node.State.Enum.t
                   * int )
                   list
                   option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int)
                 list
                 option
              -> bool)
        -> block_production_keys:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t list )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t list
              -> bool)
        -> coinbase_receiver:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> bool)
        -> histograms:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Histograms.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Histograms.t option
              -> bool)
        -> consensus_time_best_tip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Data.Consensus_time.Stable.Latest.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Data.Consensus_time.Stable.Latest.t option
              -> bool)
        -> global_slot_since_genesis_best_tip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> bool)
        -> next_block_production:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Next_producer_timing.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Next_producer_timing.t option
              -> bool)
        -> consensus_time_now:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Data.Consensus_time.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Data.Consensus_time.Stable.Latest.t
              -> bool)
        -> consensus_mechanism:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> bool)
        -> consensus_configuration:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Configuration.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Configuration.Stable.Latest.t
              -> bool)
        -> addrs_and_ports:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Node_addrs_and_ports.Display.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Node_addrs_and_ports.Display.Stable.Latest.t
              -> bool)
        -> bool

      val exists :
           t
        -> num_accounts:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> bool)
        -> blockchain_length:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> bool)
        -> highest_block_length_received:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> bool)
        -> highest_unvalidated_block_length_received:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> bool)
        -> uptime_secs:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> bool)
        -> ledger_merkle_root:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> bool)
        -> state_hash:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> bool)
        -> chain_id:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> bool)
        -> commit_id:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> bool)
        -> conf_dir:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> bool)
        -> peers:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Network_peer.Peer.Display.Stable.Latest.t list )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Network_peer.Peer.Display.Stable.Latest.t list
              -> bool)
        -> user_commands_sent:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> bool)
        -> snark_worker:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> bool)
        -> snark_work_fee:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> bool)
        -> sync_status:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Sync_status.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Sync_status.Stable.Latest.t
              -> bool)
        -> catchup_status:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , ( Transition_frontier.Full_catchup_tree.Node.State.Enum.t
                   * int )
                   list
                   option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int)
                 list
                 option
              -> bool)
        -> block_production_keys:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t list )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t list
              -> bool)
        -> coinbase_receiver:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> bool)
        -> histograms:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Histograms.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Histograms.t option
              -> bool)
        -> consensus_time_best_tip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Data.Consensus_time.Stable.Latest.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Data.Consensus_time.Stable.Latest.t option
              -> bool)
        -> global_slot_since_genesis_best_tip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> bool)
        -> next_block_production:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Next_producer_timing.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Next_producer_timing.t option
              -> bool)
        -> consensus_time_now:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Data.Consensus_time.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Data.Consensus_time.Stable.Latest.t
              -> bool)
        -> consensus_mechanism:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> bool)
        -> consensus_configuration:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Configuration.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Configuration.Stable.Latest.t
              -> bool)
        -> addrs_and_ports:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Node_addrs_and_ports.Display.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Node_addrs_and_ports.Display.Stable.Latest.t
              -> bool)
        -> bool

      val to_list :
           t
        -> num_accounts:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> 'a)
        -> blockchain_length:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> 'a)
        -> highest_block_length_received:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> 'a)
        -> highest_unvalidated_block_length_received:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> 'a)
        -> uptime_secs:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> 'a)
        -> ledger_merkle_root:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> 'a)
        -> state_hash:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> 'a)
        -> chain_id:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> 'a)
        -> commit_id:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> 'a)
        -> conf_dir:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> 'a)
        -> peers:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Network_peer.Peer.Display.Stable.Latest.t list )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Network_peer.Peer.Display.Stable.Latest.t list
              -> 'a)
        -> user_commands_sent:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> 'a)
        -> snark_worker:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> 'a)
        -> snark_work_fee:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> 'a)
        -> sync_status:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Sync_status.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Sync_status.Stable.Latest.t
              -> 'a)
        -> catchup_status:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , ( Transition_frontier.Full_catchup_tree.Node.State.Enum.t
                   * int )
                   list
                   option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int)
                 list
                 option
              -> 'a)
        -> block_production_keys:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t list )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t list
              -> 'a)
        -> coinbase_receiver:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> 'a)
        -> histograms:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Histograms.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Histograms.t option
              -> 'a)
        -> consensus_time_best_tip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Data.Consensus_time.Stable.Latest.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Data.Consensus_time.Stable.Latest.t option
              -> 'a)
        -> global_slot_since_genesis_best_tip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> 'a)
        -> next_block_production:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Next_producer_timing.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Next_producer_timing.t option
              -> 'a)
        -> consensus_time_now:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Data.Consensus_time.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Data.Consensus_time.Stable.Latest.t
              -> 'a)
        -> consensus_mechanism:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> 'a)
        -> consensus_configuration:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Configuration.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Configuration.Stable.Latest.t
              -> 'a)
        -> addrs_and_ports:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Node_addrs_and_ports.Display.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Node_addrs_and_ports.Display.Stable.Latest.t
              -> 'a)
        -> 'a list

      val map :
           t
        -> num_accounts:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> int option)
        -> blockchain_length:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> int option)
        -> highest_block_length_received:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> int)
        -> highest_unvalidated_block_length_received:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> int)
        -> uptime_secs:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> int)
        -> ledger_merkle_root:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> Git_sha.t option)
        -> state_hash:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> Git_sha.t option)
        -> chain_id:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> Git_sha.t)
        -> commit_id:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> Git_sha.t)
        -> conf_dir:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> Git_sha.t)
        -> peers:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Network_peer.Peer.Display.Stable.Latest.t list )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Network_peer.Peer.Display.Stable.Latest.t list
              -> Network_peer.Peer.Display.Stable.Latest.t list)
        -> user_commands_sent:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> int)
        -> snark_worker:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> Git_sha.t option)
        -> snark_work_fee:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int
              -> int)
        -> sync_status:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Sync_status.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Sync_status.Stable.Latest.t
              -> Sync_status.Stable.Latest.t)
        -> catchup_status:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , ( Transition_frontier.Full_catchup_tree.Node.State.Enum.t
                   * int )
                   list
                   option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int)
                 list
                 option
              -> (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int)
                 list
                 option)
        -> block_production_keys:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t list )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t list
              -> Git_sha.t list)
        -> coinbase_receiver:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t option
              -> Git_sha.t option)
        -> histograms:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Histograms.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Histograms.t option
              -> Histograms.t option)
        -> consensus_time_best_tip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Data.Consensus_time.Stable.Latest.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Data.Consensus_time.Stable.Latest.t option
              -> Consensus.Data.Consensus_time.Stable.Latest.t option)
        -> global_slot_since_genesis_best_tip:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , int option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> int option
              -> int option)
        -> next_block_production:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Next_producer_timing.t option )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Next_producer_timing.t option
              -> Next_producer_timing.t option)
        -> consensus_time_now:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Data.Consensus_time.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Data.Consensus_time.Stable.Latest.t
              -> Consensus.Data.Consensus_time.Stable.Latest.t)
        -> consensus_mechanism:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Git_sha.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Git_sha.t
              -> Git_sha.t)
        -> consensus_configuration:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Consensus.Configuration.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Consensus.Configuration.Stable.Latest.t
              -> Consensus.Configuration.Stable.Latest.t)
        -> addrs_and_ports:
             (   ( [< `Read | `Set_and_create ]
                 , t
                 , Node_addrs_and_ports.Display.Stable.Latest.t )
                 Fieldslib.Field.t_with_perm
              -> t
              -> Node_addrs_and_ports.Display.Stable.Latest.t
              -> Node_addrs_and_ports.Display.Stable.Latest.t)
        -> t

      val set_all_mutable_fields : 'a -> unit
    end
  end

  val entries : t -> (Git_sha.t * Core_kernel__.Import.string) list

  val to_text : t -> Git_sha.t
end
