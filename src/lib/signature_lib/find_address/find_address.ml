(** This module defines a tool that can be used to find invalid public keys
    with some fixed prefix.

    By invalid, we mean that the public key is not a valid point on the Mina
    elliptic curve, and thus that the public key has no corresponding private
    key.

    The prefix to search for can be found as the first positional argument to
    this command. If none is given, the default value used is
    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz

    Usage: dune exec src/lib/find_address/find_address.exe [PREFIX_STRING].
*)

open Core_kernel
open Signature_lib

let debug = false

let default_prefix = "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"

let desired_prefix =
  try Sys.argv.(1)
  with _ ->
    Format.eprintf "No prefix provided as first argument, using %s@."
      default_prefix ;
    default_prefix

let min_value : Public_key.Compressed.t =
  { x = Snark_params.Tick.Field.zero; is_odd = false }

let min_value_compressed = Public_key.Compressed.to_base58_check min_value

let max_value : Public_key.Compressed.t =
  { x =
      Kimchi_backend.Pasta.Basic.Bigint256.of_hex_string
        "0x0FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
      |> Kimchi_backend.Pasta.Basic.Fp.of_bigint
  ; is_odd = true
  }

let max_value_compressed = Public_key.Compressed.to_base58_check max_value

let first_different_position =
  let rec go i =
    if Char.equal min_value_compressed.[i] max_value_compressed.[i] then
      go (i + 1)
    else i
  in
  go 0

let fixed_prefix =
  String.sub ~pos:0 ~len:first_different_position min_value_compressed

let changed_prefixes =
  let rec go c c_final acc =
    if c >= c_final then List.rev acc else go (Int.succ c) c_final (c :: acc)
  in
  let get_char_int str = Char.to_int str.[first_different_position] in
  go (get_char_int min_value_compressed) (get_char_int max_value_compressed) []

let true_prefixes =
  List.map changed_prefixes ~f:(fun c ->
      fixed_prefix ^ String.of_char (Char.of_int_exn c) ^ desired_prefix)

let field_elements =
  let open Snark_params.Tick.Field in
  let two = of_int 2 in
  let rec go current_pow_2 pow acc =
    if Int.( < ) pow size_in_bits then
      go (mul current_pow_2 two) (Int.succ pow) (current_pow_2 :: acc)
    else List.rev acc
  in
  go one 0 []

let field_elements =
  List.sort field_elements ~compare:(fun field1 field2 ->
      let pk1 =
        { min_value with x = Snark_params.Tick.Field.add min_value.x field1 }
      in
      let pk2 =
        { min_value with x = Snark_params.Tick.Field.add min_value.x field2 }
      in
      -String.compare
         (Public_key.Compressed.to_base58_check pk1)
         (Public_key.Compressed.to_base58_check pk2))

let print_values prefix =
  let len = String.length prefix in
  if debug then Format.eprintf "Finding base for %s@." prefix ;
  let add_index = ref None in
  let base_pk, _ =
    List.fold_until
      ~init:(0, min_value, min_value_compressed)
      ~finish:(fun (_, min_value, min_value_compressed) ->
        (min_value, min_value_compressed))
      field_elements
      ~f:(fun (i, pk, pk_compressed) field ->
        let pk' = { pk with x = Snark_params.Tick.Field.add pk.x field } in
        let pk_string = Public_key.Compressed.to_base58_check pk' in
        let actual_prefix = String.prefix pk_string len in
        let compared = String.compare actual_prefix prefix in
        if debug then Format.eprintf "%s@." pk_string ;
        if compared < 0 && String.( < ) pk_compressed pk_string then
          Continue (i + 1, pk', pk_string)
        else if compared > 0 then Continue (i + 1, pk, pk_compressed)
        else (
          if Option.is_none !add_index then add_index := Some i ;
          Stop (pk, pk_compressed) ))
  in
  Option.iter !add_index ~f:(fun add_index ->
      let field_elements = List.drop field_elements add_index in
      let field_selectors = List.map ~f:(fun _ -> false) field_elements in
      let exception Stop in
      let next_exn x =
        let rec go = function
          | [] ->
              raise Stop
          | false :: rest ->
              true :: rest
          | true :: rest ->
              false :: go rest
        in
        go x
      in
      let print_value_if_valid pk =
        let pk_string = Public_key.Compressed.to_base58_check pk in
        let actual_prefix = String.prefix pk_string len in
        if String.equal actual_prefix prefix then (
          match Public_key.decompress pk with
          | Some _ ->
              (* Format.printf "%s (valid)@." pk_string ; *)
              false
          | None ->
              Format.printf "%s@." pk_string ;
              true )
        else false
      in
      let rec go field_selectors =
        let field =
          List.fold2_exn ~init:base_pk.x field_elements field_selectors
            ~f:(fun field selected_field selected ->
              if selected then Snark_params.Tick.Field.add field selected_field
              else field)
        in
        let pk_odd = { base_pk with x = field } in
        ( if print_value_if_valid pk_odd then
          let pk_even = { pk_odd with is_odd = true } in
          ignore @@ print_value_if_valid pk_even ) ;
        (* We could backtrack when the pk is invalid rather than blindly
           calling [next_exn], but this is efficient enough with a sufficiently
           large prefix.
        *)
        match next_exn field_selectors with
        | field_selectors ->
            go field_selectors
        | exception Stop ->
            ()
      in
      if debug then Format.eprintf "Keys for %s:@." prefix ;
      go field_selectors)

let () = List.iter ~f:print_values true_prefixes
