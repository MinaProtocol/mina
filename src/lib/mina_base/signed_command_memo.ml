(* signed_command_memo.ml *)

[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params

(** See documentation of the {!Mina_wire_types} library *)
module Wire_types = Mina_wire_types.Mina_base.Signed_command_memo

module Make_sig (A : Wire_types.Types.S) = struct
  module type S = Signed_command_memo_intf.S with type t = A.V1.t
end

module Make_str (_ : Wire_types.Concrete) = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      [@@@with_all_version_tags]

      type t = Bounded_types.String.Tagged.Stable.V1.t
      [@@deriving sexp, equal, compare, hash]

      let to_latest = Fn.id

      module Base58_check = Base58_check.Make (struct
        let description = "User command memo"

        let version_byte = Base58_check.Version_bytes.user_command_memo
      end)

      let to_base58_check (memo : t) : string = Base58_check.encode memo

      let of_base58_check (s : string) : t Or_error.t = Base58_check.decode s

      let of_base58_check_exn (s : string) : t = Base58_check.decode_exn s

      module T = struct
        type nonrec t = t

        let to_string = to_base58_check

        let of_string = of_base58_check_exn
      end

      include Codable.Make_of_string (T)
    end
  end]

  [%%define_locally
  Stable.Latest.
    (to_yojson, of_yojson, to_base58_check, of_base58_check, of_base58_check_exn)]

  exception Too_long_user_memo_input

  exception Too_long_digestible_string

  let max_digestible_string_length = 1000

  (* 0th byte is a tag to distinguish digests from other data
     1st byte is length, always 32 for digests
     bytes 2 to 33 are data, 0-right-padded if length is less than 32
  *)

  let digest_tag = '\x00'

  let bytes_tag = '\x01'

  let tag_index = 0

  let length_index = 1

  let digest_length = Blake2.digest_size_in_bytes

  let digest_length_byte = Char.of_int_exn digest_length

  (* +2 for tag and length bytes *)
  let memo_length = digest_length + 2

  let max_input_length = digest_length

  let tag (memo : t) = memo.[tag_index]

  let length memo = Char.to_int memo.[length_index]

  let is_bytes memo = Char.equal (tag memo) bytes_tag

  let is_digest memo = Char.equal (tag memo) digest_tag

  let is_valid memo =
    Int.(String.length memo = memo_length)
    &&
    let length = length memo in
    if is_digest memo then Int.(length = digest_length)
    else
      Char.equal (tag memo) bytes_tag
      && Int.(length <= digest_length)
      &&
      let padded =
        String.sub memo ~pos:(length + 2) ~len:(digest_length - length)
      in
      String.for_all padded ~f:(Char.equal '\x00')

  let create_by_digesting_string_exn s =
    if Int.(String.length s > max_digestible_string_length) then
      raise Too_long_digestible_string ;
    let digest = Blake2.(to_raw_string (digest_string s)) in
    String.init memo_length ~f:(fun ndx ->
        if Int.(ndx = tag_index) then digest_tag
        else if Int.(ndx = length_index) then digest_length_byte
        else digest.[ndx - 2] )

  let create_by_digesting_string (s : string) =
    try Ok (create_by_digesting_string_exn s)
    with Too_long_digestible_string ->
      Or_error.error_string "create_by_digesting_string: string too long"

  module type Memoable = sig
    type t

    val length : t -> int

    val get : t -> int -> char
  end

  let create_from_value_exn (type t) (module M : Memoable with type t = t)
      (value : t) =
    let len = M.length value in
    if Int.(len > max_input_length) then raise Too_long_user_memo_input ;
    String.init memo_length ~f:(fun ndx ->
        if Int.(ndx = tag_index) then bytes_tag
        else if Int.(ndx = length_index) then Char.of_int_exn len
        else if Int.(ndx < len + 2) then M.get value (ndx - 2)
        else '\x00' )

  let create_from_bytes_exn bytes = create_from_value_exn (module Bytes) bytes

  let create_from_bytes bytes =
    try Ok (create_from_bytes_exn bytes)
    with Too_long_user_memo_input ->
      Or_error.error_string
        (sprintf "create_from_bytes: length exceeds %d" max_input_length)

  let create_from_string_exn s = create_from_value_exn (module String) s

  let create_from_string s =
    try Ok (create_from_string_exn s)
    with Too_long_user_memo_input ->
      Or_error.error_string
        (sprintf "create_from_string: length exceeds %d" max_input_length)

  let dummy = (create_by_digesting_string_exn "" :> t)

  let empty = create_from_string_exn ""

  type raw = Digest of string | Bytes of string

  let to_raw_exn memo =
    let tag = tag memo in
    if Char.equal tag digest_tag then Digest (to_base58_check memo)
    else if Char.equal tag bytes_tag then
      let len = length memo in
      Bytes (String.init len ~f:(fun idx -> memo.[idx - 2]))
    else failwithf "Unknown memo tag %c" tag ()

  let to_raw_bytes_exn memo =
    match to_raw_exn memo with
    | Digest _ ->
        failwith "Cannot convert a digest to raw bytes"
    | Bytes str ->
        str

  let of_raw_exn = function
    | Digest base58_check ->
        of_base58_check_exn base58_check
    | Bytes str ->
        of_base58_check_exn str

  let fold_bits t =
    { Fold_lib.Fold.fold =
        (fun ~init ~f ->
          let n = 8 * String.length t in
          let rec go acc i =
            if i = n then acc
            else
              let b = (Char.to_int t.[i / 8] lsr (i mod 8)) land 1 = 1 in
              go (f acc b) (i + 1)
          in
          go init 0 )
    }

  let to_bits t = Fold_lib.Fold.to_list (fold_bits t)

  let gen =
    Quickcheck.Generator.map String.quickcheck_generator
      ~f:create_by_digesting_string_exn

  let hash memo =
    Random_oracle.hash ~init:Hash_prefix.zkapp_memo
      (Random_oracle.Legacy.pack_input
         (Random_oracle_input.Legacy.bitstring (to_bits memo)) )

  let to_plaintext (memo : t) : string Or_error.t =
    if is_bytes memo then Ok (String.sub memo ~pos:2 ~len:(length memo))
    else Error (Error.of_string "Memo does not contain text bytes")

  let to_digest (memo : t) : string Or_error.t =
    if is_digest memo then Ok (String.sub memo ~pos:2 ~len:digest_length)
    else Error (Error.of_string "Memo does not contain a digest")

  let to_string_hum (memo : t) =
    match to_plaintext memo with
    | Ok text ->
        text
    | Error _ -> (
        match to_digest memo with
        | Ok digest ->
            sprintf "0x%s" (Hex.encode digest)
        | Error _ ->
            "(Invalid memo, neither text nor a digest)" )

  [%%ifdef consensus_mechanism]

  module Boolean = Tick.Boolean
  module Typ = Tick.Typ

  (* the code below is much the same as in Random_oracle.Digest; tag and length bytes
     make it a little different
  *)

  module Checked = struct
    type unchecked = t

    type t = Boolean.var array

    let constant unchecked =
      assert (Int.(String.length (unchecked :> string) = memo_length)) ;
      Array.map
        (Blake2.string_to_bits (unchecked :> string))
        ~f:Boolean.var_of_value
  end

  let length_in_bits = 8 * memo_length

  let typ : (Checked.t, t) Typ.t =
    Typ.transport
      (Typ.array ~length:length_in_bits Boolean.typ)
      ~there:(fun (t : t) -> Blake2.string_to_bits (t :> string))
      ~back:(fun bs -> (Blake2.bits_to_string bs :> t))

  [%%endif]

  let deriver obj =
    Fields_derivers_zkapps.iso_string obj ~name:"Memo" ~js_type:String
      ~to_string:to_base58_check ~of_string:of_base58_check_exn

  let%test_module "user_command_memo" =
    ( module struct
      let data memo = String.sub memo ~pos:(length_index + 1) ~len:(length memo)

      let%test "digest string" =
        let s = "this is a string" in
        let memo = create_by_digesting_string_exn s in
        is_valid memo

      let%test "digest too-long string" =
        let s =
          String.init (max_digestible_string_length + 1) ~f:(fun _ -> '\xFF')
        in
        try
          let (_ : t) = create_by_digesting_string_exn s in
          false
        with Too_long_digestible_string -> true

      let%test "memo from string" =
        let s = "time and tide wait for no one" in
        let memo = create_from_string_exn s in
        is_valid memo && String.equal s (data memo)

      let%test "memo from too-long string" =
        let s = String.init (max_input_length + 1) ~f:(fun _ -> '\xFF') in
        try
          let (_ : t) = create_from_string_exn s in
          false
        with Too_long_user_memo_input -> true

      [%%ifdef consensus_mechanism]

      let%test_unit "typ is identity" =
        let s = "this is a string" in
        let memo = create_by_digesting_string_exn s in
        let read_constant = function
          | Snarky_backendless.Cvar.Constant x ->
              x
          | _ ->
              assert false
        in
        let (Typ typ) = typ in
        let memo_var =
          memo |> typ.value_to_fields
          |> (fun (arr, aux) ->
               ( Array.map arr ~f:(fun x -> Snarky_backendless.Cvar.Constant x)
               , aux ) )
          |> typ.var_of_fields
        in
        let memo_read =
          memo_var |> typ.var_to_fields
          |> (fun (arr, aux) ->
               (Array.map arr ~f:(fun x -> read_constant x), aux) )
          |> typ.value_of_fields
        in
        [%test_eq: string] memo memo_read

      [%%endif]
    end )
end

include Wire_types.Make (Make_sig) (Make_str)
