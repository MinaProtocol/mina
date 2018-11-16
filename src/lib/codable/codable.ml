open Core_kernel

module type Iso_intf = sig
  type original

  type standardized [@@deriving yojson]

  val encode : original -> standardized

  val decode : standardized -> original
end

module type S = sig
  type t

  val to_yojson : t -> Yojson.Safe.json

  val of_yojson : Yojson.Safe.json -> t Ppx_deriving_yojson_runtime.error_or
end

module Make (Iso : Iso_intf) = struct
  let to_yojson t = Iso.encode t |> Iso.standardized_to_yojson

  let of_yojson json =
    Result.map ~f:Iso.decode (Iso.standardized_of_yojson json)

  module For_tests = struct
    let check_encoding t ~equal =
      match of_yojson (to_yojson t) with
      | Ok result -> equal t result
      | Error e -> failwithf !"%s" e ()
  end
end

module For_tests = struct
  let check_encoding (type t) (module M : S with type t = t) t ~equal =
    match M.of_yojson (M.to_yojson t) with
    | Ok result -> equal t result
    | Error e -> failwithf !"%s" e ()
end

module Make_of_int (Iso : sig
  type t

  val to_int : t -> int

  val of_int : int -> t
end) =
Make (struct
  type original = Iso.t

  type standardized = int [@@deriving yojson]

  let encode = Iso.to_int

  let decode = Iso.of_int
end)

module Make_of_string (Iso : sig
  type t

  val to_string : t -> string

  val of_string : string -> t
end) =
Make (struct
  type original = Iso.t

  type standardized = string [@@deriving yojson]

  let encode = Iso.to_string

  let decode = Iso.of_string
end)
