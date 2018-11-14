open Core_kernel

module type Converter_intf = sig
  type t

  type primitive [@@deriving yojson]

  val to_primitive : t -> primitive

  val of_primitive : primitive -> t
end

module type S = sig
  type t

  val to_yojson : t -> Yojson.Safe.json

  val of_yojson : Yojson.Safe.json -> t Ppx_deriving_yojson_runtime.error_or
end

module Make (Converter : Converter_intf) = struct
  let to_yojson t = Converter.to_primitive t |> Converter.primitive_to_yojson

  let of_yojson json =
    Result.map ~f:Converter.of_primitive (Converter.primitive_of_yojson json)
end

module Make_from_int (Converter : sig
  type t

  val to_int : t -> int

  val of_int : int -> t
end) =
Make (struct
  type t = Converter.t

  type primitive = int [@@deriving yojson]

  let to_primitive = Converter.to_int

  let of_primitive = Converter.of_int
end)

module Make_from_string (Converter : sig
  type t

  val to_string : t -> string

  val of_string : string -> t
end) =
Make (struct
  type t = Converter.t

  type primitive = string [@@deriving yojson]

  let to_primitive = Converter.to_string

  let of_primitive = Converter.of_string
end)
