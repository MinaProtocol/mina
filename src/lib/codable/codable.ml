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

module Hex = struct
  (** Hex-encode data *)

  (** to_hex : {0x0-0xff}* -> [A-F0-9]* *)
  let to_hex (data : string) : string =
    String.to_list data
    |> List.map ~f:(fun c ->
           let charify u4 =
             match u4 with
             | x when x <= 9 && x >= 0 ->
                 Char.(of_int_exn @@ (x + to_int '0'))
             | x when x <= 15 && x >= 10 ->
                 Char.(of_int_exn @@ (x - 10 + to_int 'A'))
             | _ ->
                 failwith "Unexpected u4 has only 4bits of information"
           in
           let high = charify @@ ((Char.to_int c land 0xF0) lsr 4) in
           let lo = charify (Char.to_int c land 0x0F) in
           String.of_char_list [high; lo] )
    |> String.concat

  let%test_unit "to_hex sane" =
    let start = "a" in
    let hexified = to_hex start in
    let expected = "61" in
    if String.equal expected hexified then ()
    else
      failwithf "start: %s ; hexified : %s ; expected: %s" start hexified
        expected ()

  (** of_hex : [a-fA-F0-9]* -> {0x0-0xff}* option *)
  let of_hex (hex : string) : string option =
    let to_u4 c =
      let open Char in
      assert (is_alphanum c) ;
      match c with
      | _ when is_digit c ->
          to_int c - to_int '0'
      | _ when is_uppercase c ->
          to_int c - to_int 'A' + 10
      | _ (* when is_alpha *) ->
          to_int c - to_int 'a' + 10
    in
    String.to_list hex |> List.chunks_of ~length:2
    |> List.fold_result ~init:[] ~f:(fun acc chunk ->
           match chunk with
           | [a; b] when Char.is_alphanum a && Char.is_alphanum b ->
               Or_error.return
               @@ (Char.((to_u4 a lsl 4) lor to_u4 b |> of_int_exn) :: acc)
           | _ ->
               Or_error.error_string "invalid hex" )
    |> Or_error.ok
    |> Option.map ~f:(Fn.compose String.of_char_list List.rev)

  let%test_unit "partial isomorphism" =
    Quickcheck.test ~sexp_of:[%sexp_of: string] ~examples:["\243"; "abc"]
      Quickcheck.Generator.(map (list char) ~f:String.of_char_list)
      ~f:(fun s ->
        let hexified = to_hex s in
        let actual = of_hex hexified |> Option.value_exn in
        let expected = s in
        if String.equal actual expected then ()
        else
          failwithf
            !"expected: %s ; hexified: %s ; actual: %s"
            expected hexified actual () )
end
