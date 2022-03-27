module type S = sig
  type t

  val to_yojson : t -> Yojson.Safe.t

  val t_of_sexp : Sexplib0.Sexp.t -> t

  val sexp_of_t : t -> Sexplib0.Sexp.t

  module Stable : sig
    module V1 : sig
      type t_ := t

      type t = t_

      val to_yojson : t -> Yojson.Safe.t

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t

      val bin_size_t : t Bin_prot.Size.sizer

      val bin_write_t : t Bin_prot.Write.writer

      val bin_read_t : t Bin_prot.Read.reader

      val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

      val bin_shape_t : Bin_prot.Shape.t

      val bin_writer_t : t Bin_prot.Type_class.writer

      val bin_reader_t : t Bin_prot.Type_class.reader

      val bin_t : t Bin_prot.Type_class.t
    end

    module Latest = V1
  end

  val create :
       snark_transition:Mina_state.Snark_transition.Value.t
    -> ledger_proof:Ledger_proof.t option
    -> prover_state:Consensus.Data.Prover_state.t
    -> staged_ledger_diff:Staged_ledger_diff.t
    -> t

  val snark_transition : t -> Mina_state.Snark_transition.Value.t

  val ledger_proof : t -> Ledger_proof.t option

  val prover_state : t -> Consensus.Data.Prover_state.t

  val staged_ledger_diff : t -> Staged_ledger_diff.t
end

module Stable : sig
  module V1 : sig
    type t =
      { snark_transition : Mina_state.Snark_transition.Value.Stable.V1.t
      ; ledger_proof : Ledger_proof.Stable.V1.t option
      ; prover_state : Consensus.Data.Prover_state.Stable.V1.t
      ; staged_ledger_diff : Staged_ledger_diff.Stable.V1.t
      }

    val version : int

    val __versioned__ : unit

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

    val bin_read_t : Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t

    val __bin_read_t__ :
      Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> int -> t

    val bin_size_t : t -> int

    val bin_write_t :
      Bin_prot.Common.buf -> pos:Bin_prot.Common.pos -> t -> Bin_prot.Common.pos

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

type t = Stable.V1.t =
  { snark_transition : Mina_state.Snark_transition.Value.t
  ; ledger_proof : Ledger_proof.t option
  ; prover_state : Consensus.Data.Prover_state.t
  ; staged_ledger_diff : Staged_ledger_diff.t
  }

val to_yojson : t -> Yojson.Safe.t

val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

val staged_ledger_diff : t -> Staged_ledger_diff.t

val prover_state : t -> Consensus.Data.Prover_state.t

val ledger_proof : t -> Ledger_proof.t option

val snark_transition : t -> Mina_state.Snark_transition.Value.t

module Fields : sig
  val names : string list

  val staged_ledger_diff :
    ( [< `Read | `Set_and_create ]
    , t
    , Staged_ledger_diff.t )
    Fieldslib.Field.t_with_perm

  val prover_state :
    ( [< `Read | `Set_and_create ]
    , t
    , Consensus.Data.Prover_state.t )
    Fieldslib.Field.t_with_perm

  val ledger_proof :
    ( [< `Read | `Set_and_create ]
    , t
    , Ledger_proof.t option )
    Fieldslib.Field.t_with_perm

  val snark_transition :
    ( [< `Read | `Set_and_create ]
    , t
    , Mina_state.Snark_transition.Value.t )
    Fieldslib.Field.t_with_perm

  val make_creator :
       snark_transition:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Mina_state.Snark_transition.Value.t )
             Fieldslib.Field.t_with_perm
          -> 'a
          -> ('b -> Mina_state.Snark_transition.Value.t) * 'c)
    -> ledger_proof:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Ledger_proof.t option )
             Fieldslib.Field.t_with_perm
          -> 'c
          -> ('b -> Ledger_proof.t option) * 'd)
    -> prover_state:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Consensus.Data.Prover_state.t )
             Fieldslib.Field.t_with_perm
          -> 'd
          -> ('b -> Consensus.Data.Prover_state.t) * 'e)
    -> staged_ledger_diff:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Staged_ledger_diff.t )
             Fieldslib.Field.t_with_perm
          -> 'e
          -> ('b -> Staged_ledger_diff.t) * 'f)
    -> 'a
    -> ('b -> t) * 'f

  val create :
       snark_transition:Mina_state.Snark_transition.Value.t
    -> ledger_proof:Ledger_proof.t option
    -> prover_state:Consensus.Data.Prover_state.t
    -> staged_ledger_diff:Staged_ledger_diff.t
    -> t

  val map :
       snark_transition:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Mina_state.Snark_transition.Value.t )
             Fieldslib.Field.t_with_perm
          -> Mina_state.Snark_transition.Value.t)
    -> ledger_proof:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Ledger_proof.t option )
             Fieldslib.Field.t_with_perm
          -> Ledger_proof.t option)
    -> prover_state:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Consensus.Data.Prover_state.t )
             Fieldslib.Field.t_with_perm
          -> Consensus.Data.Prover_state.t)
    -> staged_ledger_diff:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Staged_ledger_diff.t )
             Fieldslib.Field.t_with_perm
          -> Staged_ledger_diff.t)
    -> t

  val iter :
       snark_transition:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Mina_state.Snark_transition.Value.t )
             Fieldslib.Field.t_with_perm
          -> unit)
    -> ledger_proof:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Ledger_proof.t option )
             Fieldslib.Field.t_with_perm
          -> unit)
    -> prover_state:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Consensus.Data.Prover_state.t )
             Fieldslib.Field.t_with_perm
          -> unit)
    -> staged_ledger_diff:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Staged_ledger_diff.t )
             Fieldslib.Field.t_with_perm
          -> unit)
    -> unit

  val fold :
       init:'a
    -> snark_transition:
         (   'a
          -> ( [< `Read | `Set_and_create ]
             , t
             , Mina_state.Snark_transition.Value.t )
             Fieldslib.Field.t_with_perm
          -> 'b)
    -> ledger_proof:
         (   'b
          -> ( [< `Read | `Set_and_create ]
             , t
             , Ledger_proof.t option )
             Fieldslib.Field.t_with_perm
          -> 'c)
    -> prover_state:
         (   'c
          -> ( [< `Read | `Set_and_create ]
             , t
             , Consensus.Data.Prover_state.t )
             Fieldslib.Field.t_with_perm
          -> 'd)
    -> staged_ledger_diff:
         (   'd
          -> ( [< `Read | `Set_and_create ]
             , t
             , Staged_ledger_diff.t )
             Fieldslib.Field.t_with_perm
          -> 'e)
    -> 'e

  val map_poly :
    ([< `Read | `Set_and_create ], t, 'a) Fieldslib.Field.user -> 'a list

  val for_all :
       snark_transition:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Mina_state.Snark_transition.Value.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> ledger_proof:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Ledger_proof.t option )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> prover_state:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Consensus.Data.Prover_state.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> staged_ledger_diff:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Staged_ledger_diff.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> bool

  val exists :
       snark_transition:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Mina_state.Snark_transition.Value.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> ledger_proof:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Ledger_proof.t option )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> prover_state:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Consensus.Data.Prover_state.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> staged_ledger_diff:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Staged_ledger_diff.t )
             Fieldslib.Field.t_with_perm
          -> bool)
    -> bool

  val to_list :
       snark_transition:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Mina_state.Snark_transition.Value.t )
             Fieldslib.Field.t_with_perm
          -> 'a)
    -> ledger_proof:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Ledger_proof.t option )
             Fieldslib.Field.t_with_perm
          -> 'a)
    -> prover_state:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Consensus.Data.Prover_state.t )
             Fieldslib.Field.t_with_perm
          -> 'a)
    -> staged_ledger_diff:
         (   ( [< `Read | `Set_and_create ]
             , t
             , Staged_ledger_diff.t )
             Fieldslib.Field.t_with_perm
          -> 'a)
    -> 'a list

  module Direct : sig
    val iter :
         t
      -> snark_transition:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Mina_state.Snark_transition.Value.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Mina_state.Snark_transition.Value.t
            -> unit)
      -> ledger_proof:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Ledger_proof.t option )
               Fieldslib.Field.t_with_perm
            -> t
            -> Ledger_proof.t option
            -> unit)
      -> prover_state:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Prover_state.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Consensus.Data.Prover_state.t
            -> unit)
      -> staged_ledger_diff:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Staged_ledger_diff.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Staged_ledger_diff.t
            -> 'a)
      -> 'a

    val fold :
         t
      -> init:'a
      -> snark_transition:
           (   'a
            -> ( [< `Read | `Set_and_create ]
               , t
               , Mina_state.Snark_transition.Value.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Mina_state.Snark_transition.Value.t
            -> 'b)
      -> ledger_proof:
           (   'b
            -> ( [< `Read | `Set_and_create ]
               , t
               , Ledger_proof.t option )
               Fieldslib.Field.t_with_perm
            -> t
            -> Ledger_proof.t option
            -> 'c)
      -> prover_state:
           (   'c
            -> ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Prover_state.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Consensus.Data.Prover_state.t
            -> 'd)
      -> staged_ledger_diff:
           (   'd
            -> ( [< `Read | `Set_and_create ]
               , t
               , Staged_ledger_diff.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Staged_ledger_diff.t
            -> 'e)
      -> 'e

    val for_all :
         t
      -> snark_transition:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Mina_state.Snark_transition.Value.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Mina_state.Snark_transition.Value.t
            -> bool)
      -> ledger_proof:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Ledger_proof.t option )
               Fieldslib.Field.t_with_perm
            -> t
            -> Ledger_proof.t option
            -> bool)
      -> prover_state:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Prover_state.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Consensus.Data.Prover_state.t
            -> bool)
      -> staged_ledger_diff:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Staged_ledger_diff.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Staged_ledger_diff.t
            -> bool)
      -> bool

    val exists :
         t
      -> snark_transition:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Mina_state.Snark_transition.Value.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Mina_state.Snark_transition.Value.t
            -> bool)
      -> ledger_proof:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Ledger_proof.t option )
               Fieldslib.Field.t_with_perm
            -> t
            -> Ledger_proof.t option
            -> bool)
      -> prover_state:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Prover_state.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Consensus.Data.Prover_state.t
            -> bool)
      -> staged_ledger_diff:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Staged_ledger_diff.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Staged_ledger_diff.t
            -> bool)
      -> bool

    val to_list :
         t
      -> snark_transition:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Mina_state.Snark_transition.Value.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Mina_state.Snark_transition.Value.t
            -> 'a)
      -> ledger_proof:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Ledger_proof.t option )
               Fieldslib.Field.t_with_perm
            -> t
            -> Ledger_proof.t option
            -> 'a)
      -> prover_state:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Prover_state.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Consensus.Data.Prover_state.t
            -> 'a)
      -> staged_ledger_diff:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Staged_ledger_diff.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Staged_ledger_diff.t
            -> 'a)
      -> 'a list

    val map :
         t
      -> snark_transition:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Mina_state.Snark_transition.Value.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Mina_state.Snark_transition.Value.t
            -> Mina_state.Snark_transition.Value.t)
      -> ledger_proof:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Ledger_proof.t option )
               Fieldslib.Field.t_with_perm
            -> t
            -> Ledger_proof.t option
            -> Ledger_proof.t option)
      -> prover_state:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Consensus.Data.Prover_state.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Consensus.Data.Prover_state.t
            -> Consensus.Data.Prover_state.t)
      -> staged_ledger_diff:
           (   ( [< `Read | `Set_and_create ]
               , t
               , Staged_ledger_diff.t )
               Fieldslib.Field.t_with_perm
            -> t
            -> Staged_ledger_diff.t
            -> Staged_ledger_diff.t)
      -> t

    val set_all_mutable_fields : 'a -> unit
  end
end

val create :
     snark_transition:Mina_state.Snark_transition.Value.Stable.V1.t
  -> ledger_proof:Ledger_proof.Stable.V1.t option
  -> prover_state:Consensus.Data.Prover_state.Stable.V1.t
  -> staged_ledger_diff:Staged_ledger_diff.Stable.V1.t
  -> t
