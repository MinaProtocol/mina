open Core
open Snarky_backendless
module Field = Marlin_plonk_bindings.Pasta_fp

module Signature = struct
  type t = (Field.t * Field.t) * Field.t
end

type _ Snarky_backendless.Request.t +=
  | Get_ciphertext : Bytes.t Snarky_backendless.Request.t

type _ Snarky_backendless.Request.t +=
  | Get_key : Bytes.t Snarky_backendless.Request.t

type _ Snarky_backendless.Request.t +=
  | Get_iv : Bytes.t Snarky_backendless.Request.t

type _ Snarky_backendless.Request.t +=
  | Get_signature : Signature.t Snarky_backendless.Request.t

module Witness = struct
  type t =
    {ciphertext: Bytes.t; key: Bytes.t; iv: Bytes.t; signature: Signature.t}
end

let witness_handler (witness : Witness.t) :
    Snarky_backendless.Request.request -> _ =
 fun (With {request; respond} as r) ->
  match request with
  | Get_ciphertext ->
      respond (Provide witness.ciphertext)
  | Get_key ->
      respond (Provide witness.key)
  | Get_iv ->
      respond (Provide witness.iv)
  | Get_signature ->
      respond (Provide witness.signature)
  | _ ->
      respond Unhandled

let bits_to_bytes (bits : bool list) : int array =
  let byte_of_bits (bs : bool list) : int =
    List.foldi bs ~init:0 ~f:(fun i acc bit ->
        if bit then acc lor (1 lsl i) else acc )
  in
  Array.of_list
    (List.map ~f:byte_of_bits
       (List.groupi bits ~break:(fun i _ _ -> i mod 8 = 0)))

let bytes_to_bits (bytes : int array) : bool list =
  List.init
    (8 * Array.length bytes)
    ~f:(fun i ->
      if bytes.(i / 8) land (1 lsl (7 - (i % 8))) <> 0 then true else false )

let%test_module "httpsnapps witness tests" =
  ( module struct
    ;;
    let bits = [false; false; true; true; true; true; true; true] in
    let bytes : int array = bits_to_bytes bits in
    Printf.printf "byte = %d\n" bytes.(0) ;
    let bytes = [|0x01; 0x02; 0x03|] in
    let bits : bool list = bytes_to_bits bytes in
    Printf.printf "httpsnapps witness tests\n"
  end )
