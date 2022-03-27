module type Iso_intf = sig
  type original

  type standardized

  val standardized_to_yojson : standardized -> Yojson.Safe.t

  val standardized_of_yojson :
    Yojson.Safe.t -> standardized Ppx_deriving_yojson_runtime.error_or

  val encode : original -> standardized

  val decode : standardized -> original
end

module type S = sig
  type t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
end

module Make : functor (Iso : Iso_intf) -> sig
  val to_yojson : Iso.original -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> (Iso.original, string) Core_kernel.Result.t

  module For_tests : sig
    val check_encoding :
      Iso.original -> equal:(Iso.original -> Iso.original -> 'a) -> 'a
  end
end

module For_tests : sig
  val check_encoding :
    (module S with type t = 't) -> 't -> equal:('t -> 't -> 'a) -> 'a
end

module Make_of_int : functor
  (Iso : sig
     type t

     val to_int : t -> int

     val of_int : int -> t
   end)
  -> sig
  val to_yojson : Iso.t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> (Iso.t, string) Core_kernel.Result.t

  module For_tests : sig
    val check_encoding : Iso.t -> equal:(Iso.t -> Iso.t -> 'a) -> 'a
  end
end

module Make_of_string : functor
  (Iso : sig
     type t

     val to_string : t -> string

     val of_string : string -> t
   end)
  -> sig
  val to_yojson : Iso.t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> (Iso.t, string) Core_kernel.Result.t

  module For_tests : sig
    val check_encoding : Iso.t -> equal:(Iso.t -> Iso.t -> 'a) -> 'a
  end
end

module Make_base58_check : functor
  (T : sig
     type t

     val bin_size_t : t Bin_prot.Size.sizer

     val bin_write_t : t Bin_prot.Write.writer

     val bin_read_t : t Bin_prot.Read.reader

     val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

     val bin_shape_t : Bin_prot.Shape.t

     val bin_writer_t : t Bin_prot.Type_class.writer

     val bin_reader_t : t Bin_prot.Type_class.reader

     val bin_t : t Bin_prot.Type_class.t

     val description : string

     val version_byte : char
   end)
  -> sig
  module Base58_check : sig
    val encode : string -> string

    val decode_exn : string -> string

    val decode : string -> string Core_kernel.Or_error.t
  end

  val to_base58_check : T.t -> string

  val of_base58_check : string -> T.t Base__Or_error.t

  val of_base58_check_exn : string -> T.t

  val to_yojson : T.t -> [> `String of string ]

  val of_yojson : Yojson.Safe.t -> (T.t, string) Core_kernel.Result.t
end

module type Base58_check_base_intf = sig
  type t

  val of_base58_check : string -> t Base.Or_error.t

  val of_base58_check_exn : string -> t
end

module type Base58_check_intf = sig
  type t

  val to_base58_check : t -> string

  val of_base58_check : string -> t Base.Or_error.t

  val of_base58_check_exn : string -> t
end
