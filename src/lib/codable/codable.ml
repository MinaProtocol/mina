open Core_kernel

module type Iso_intf = sig
  type original

  type standardized [@@deriving yojson]

  val encode : original -> standardized

  val decode : standardized -> original
end

module type S = sig
  type t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
end

module Make (Iso : Iso_intf) = struct
  let to_yojson t = Iso.encode t |> Iso.standardized_to_yojson

  let of_yojson json =
    Result.map ~f:Iso.decode (Iso.standardized_of_yojson json)

  module For_tests = struct
    let check_encoding t ~equal =
      match of_yojson (to_yojson t) with
      | Ok result ->
          equal t result
      | Error e ->
          failwithf !"%s" e ()
  end
end

module For_tests = struct
  let check_encoding (type t) (module M : S with type t = t) t ~equal =
    match M.of_yojson (M.to_yojson t) with
    | Ok result ->
        equal t result
    | Error e ->
        failwithf !"%s" e ()
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

module Make_base58_check (T : sig
  type t [@@deriving bin_io]

  val description : string

  val version_byte : char
end) =
struct
  module Base58_check = Base58_check.Make (T)

  let to_base58_check t = Base58_check.encode (Binable.to_string (module T) t)

  let of_base58_check s =
    let open Or_error.Let_syntax in
    let%bind decoded = Base58_check.decode s in
    Or_error.try_with (fun () -> Binable.of_string (module T) decoded)

  let of_base58_check_exn s = of_base58_check s |> Or_error.ok_exn

  module String_ops = struct
    type t = T.t

    let to_string = to_base58_check

    let of_string = of_base58_check_exn
  end

  include Make_of_string (String_ops)
end

module type Base58_check_base_intf = sig
  type t

  (** Base58Check decoding *)
  val of_base58_check : string -> t Base.Or_error.t

  (** Base58Check decoding *)
  val of_base58_check_exn : string -> t
end

module type Base58_check_intf = sig
  type t

  (** string encoding (Base58Check) *)
  val to_string : t -> string

  (** string (Base58Check) decoding *)
  val of_string : string -> t

  (** explicit Base58Check encoding *)
  val to_base58_check : t -> string

  include Base58_check_base_intf with type t := t
end
