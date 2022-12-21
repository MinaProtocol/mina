module type Bindings = sig
  type t

  val num_limbs : unit -> int

  val bytes_per_limb : unit -> int

  val compare : t -> t -> int

  val div : t -> t -> t

  val test_bit : t -> int -> bool

  val print : t -> unit

  val to_string : t -> string

  val of_numeral : string -> int -> int -> t

  val of_decimal_string : string -> t

  val to_bytes : t -> bytes

  val of_bytes : bytes -> t
end

module type Intf = sig
  type t

  val bin_size_t : t Bin_prot.Size.sizer

  val bin_write_t : t Bin_prot.Write.writer

  val bin_read_t : t Bin_prot.Read.reader

  val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

  val bin_shape_t : Bin_prot.Shape.t

  val bin_writer_t : t Bin_prot.Type_class.writer

  val bin_reader_t : t Bin_prot.Type_class.reader

  val bin_t : t Bin_prot.Type_class.t

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val compare : t -> t -> int

  val div : t -> t -> t

  val test_bit : t -> int -> bool

  val print : t -> unit

  val to_string : t -> string

  val of_decimal_string : string -> t

  val to_bytes : t -> bytes

  val of_bytes : bytes -> t

  val num_limbs : int

  val bytes_per_limb : int

  val length_in_bytes : int

  val to_hex_string : t -> string

  val of_hex_string : ?reverse:bool -> string -> t

  val of_numeral : string -> base:int -> t
end

module Make : functor
  (B : Bindings)
  (M : sig
     val length_in_bytes : int
   end)
  -> sig
  type t = B.t

  val bin_size_t : t Bin_prot.Size.sizer

  val bin_write_t : t Bin_prot.Write.writer

  val bin_read_t : t Bin_prot.Read.reader

  val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

  val bin_shape_t : Bin_prot.Shape.t

  val bin_writer_t : t Bin_prot.Type_class.writer

  val bin_reader_t : t Bin_prot.Type_class.reader

  val bin_t : t Bin_prot.Type_class.t

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val compare : t -> t -> int

  val div : t -> t -> t

  val test_bit : t -> int -> bool

  val print : t -> unit

  val to_string : t -> string

  val of_decimal_string : string -> t

  val to_bytes : t -> bytes

  val of_bytes : bytes -> t

  val num_limbs : int

  val bytes_per_limb : int

  val length_in_bytes : int

  val to_hex_string : t -> string

  val of_hex_string : ?reverse:bool -> string -> t

  val of_numeral : string -> base:int -> t
end
