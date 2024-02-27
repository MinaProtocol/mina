open Core_kernel

module type S = sig
  module Stable : sig
    module V1 : sig
      type t = private Zkapp_basic.F.t

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val bin_size_t : t Bin_prot.Size.sizer

      val bin_write_t : t Bin_prot.Write.writer

      val bin_read_t : t Bin_prot.Read.reader

      val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

      val bin_shape_t : Bin_prot.Shape.t

      val bin_writer_t : t Bin_prot.Type_class.writer

      val bin_reader_t : t Bin_prot.Type_class.reader

      val bin_t : t Bin_prot.Type_class.t

      val __versioned__ : unit

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val compare : t -> t -> int

      val equal : t -> t -> bool

      val hash_fold_t :
        Base_internalhash_types.state -> t -> Base_internalhash_types.state

      val hash : t -> int
    end

    module Latest = V1
  end

  type t = Stable.V1.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val compare : t -> t -> int

  val equal : t -> t -> bool

  val hash_fold_t :
    Base_internalhash_types.state -> t -> Base_internalhash_types.state

  val hash : t -> int
end

module type S_checked = sig
  open Pickles.Impls.Step

  type t = private Field.t

  val if_ : Boolean.var -> then_:t -> else_:t -> t

  val equal : t -> t -> Boolean.var

  module Assert : sig
    val equal : t -> t -> unit
  end
end

module type S_aux = sig
  type t

  type checked

  val typ : (checked, t) Pickles.Impls.Step.Typ.t

  val constant : t -> checked
end
