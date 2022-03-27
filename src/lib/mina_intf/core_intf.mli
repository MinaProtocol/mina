module type Security_intf = sig
  val max_depth : [ `Finite of int | `Infinity ]
end

module type Snark_pool_proof_intf = sig
  module Statement : sig
    type t

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

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

  type t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

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
