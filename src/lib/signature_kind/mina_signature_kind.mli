type t = Mina_signature_kind_type.t =
  | Testnet
  | Mainnet
  | Other_network of string

val bin_t : t Bin_prot.Type_class.t

val bin_read_t : t Bin_prot.Read.reader

val bin_reader_t : t Bin_prot.Type_class.reader

val bin_shape_t : Bin_prot.Shape.t

val bin_size_t : t Bin_prot.Size.sizer

val bin_write_t : t Bin_prot.Write.writer

val bin_writer_t : t Bin_prot.Type_class.writer

(** The Mina_signature_kind_type in the compiled config. Deprecated - will be
    replaced by a runtime-derived value. *)
val t_DEPRECATED : t
