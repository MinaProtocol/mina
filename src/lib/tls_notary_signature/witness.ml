(*
 * httpsnapps prover witness structure
 *)

open Core

(* Import snarky primaitves on top of pasta/vesta plonk plookup backend *)
module Impl =
  Snarky.Snark.Run.Make
    (Zexe_backend.Pasta.Vesta_based_plonk_plookup)
    (Core.Unit)
open Impl

(*
 * Useful shorthands
 *)

module Field = Impl.Field.Constant

module Bytes = struct
  type t = int array
end

module Bits = struct
  type t = bool list
end

module Signature = struct
  type t = (Field.t * Field.t) * Field.t
end

(*
 * Witness structure
 *)

module Witness = struct
  type t =
    {ciphertext: Bytes.t; key: Bytes.t; iv: Bytes.t; signature: Signature.t}
end

(*
 * Interface to access witness data
 *)

type _ Snarky_backendless.Request.t +=
  | Get_ciphertext : Bytes.t Snarky_backendless.Request.t

type _ Snarky_backendless.Request.t +=
  | Get_key : Bytes.t Snarky_backendless.Request.t

type _ Snarky_backendless.Request.t +=
  | Get_iv : Bytes.t Snarky_backendless.Request.t

type _ Snarky_backendless.Request.t +=
  | Get_signature : Signature.t Snarky_backendless.Request.t

let witness_handler (witness : Witness.t) : Impl.request -> _ =
 fun (With {request; respond}) ->
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

(*
 * Convert list of bits from prover byte-order to array of big-endian bytes
 *)
let bits_to_bytes (bits : Bits.t) : Bytes.t =
  let byte_of_bits (bs : Bits.t) : int =
    List.foldi bs ~init:0 ~f:(fun i acc bit ->
        if bit then acc lor (1 lsl i) else acc )
  in
  Array.of_list
    (List.map ~f:byte_of_bits
       (List.groupi bits ~break:(fun i _ _ -> i mod 8 = 0)))

(*
 * Convert array of big-endian bytes to list of bits in prover byte-order
 *)
let bytes_to_bits (bytes : Bytes.t) : Bits.t =
  List.init
    (8 * Array.length bytes)
    ~f:(fun i ->
      if bytes.(i / 8) land (1 lsl (i % 8)) <> 0 then true else false )

let bytes_transporter num_bytes =
  Typ.transport ~there:bytes_to_bits ~back:bits_to_bytes
    (Typ.list ~length:(8 * num_bytes) Boolean.typ)

(*
 * Unit tests
*)

let%test "bits_to_bytes test 1" =
  let bytes : Bytes.t =
    bits_to_bytes [false; false; true; true; true; true; true; true]
  in
  bytes = [|0xfc|]

let%test "bits_to_bytes test 2" =
  let bytes : Bytes.t =
    bits_to_bytes
      [ false
      ; false
      ; true
      ; true
      ; true
      ; true
      ; true
      ; true
      ; false
      ; false
      ; false
      ; true
      ; false
      ; true
      ; true
      ; true
      ; true
      ; true
      ; true
      ; true
      ; false
      ; true
      ; true
      ; false ]
  in
  bytes = [|0xfc; 0xe8; 0x6f|]

let%test "bytes_to_bits test 1" =
  let bits : Bits.t = bytes_to_bits [|0xfc|] in
  bits = [false; false; true; true; true; true; true; true]

let%test "bytes_to_bits test 2" =
  let bits : Bits.t = bytes_to_bits [|0x01; 0x02; 0x03|] in
  bits
  = [ true
    ; false
    ; false
    ; false
    ; false
    ; false
    ; false
    ; false
    ; false
    ; true
    ; false
    ; false
    ; false
    ; false
    ; false
    ; false
    ; true
    ; true
    ; false
    ; false
    ; false
    ; false
    ; false
    ; false ]

let%test "bytes_transporter 1" =
  let fe = Field.of_int 1 in
  let witness : Witness.t =
    { ciphertext= [|0x01; 0x02; 0x03|]
    ; key= [|0x01; 0x02; 0x03|]
    ; iv= [|0x01; 0x02; 0x03|]
    ; signature= ((fe, fe), fe) }
  in
  let get_ciphertext () =
    (* bytes to prover bits *)
    Impl.exists (bytes_transporter 3) ~request:(fun () -> Get_ciphertext)
  in
  let state =
    Impl.run_and_check (fun () ->
        let ct = handle get_ciphertext (witness_handler witness) in
        fun () ->
          (* Testing postscript (run as test prover) *)
          ( As_prover.read (bytes_transporter 3) ct
          , As_prover.read (Typ.list Boolean.typ ~length:(3 * 8)) ct ) )
  in
  let (), (bytes, bits) = Or_error.ok_exn @@ state () in
  bytes = [|0x01; 0x02; 0x03|]
  && bits
     = [ true
       ; false
       ; false
       ; false
       ; false
       ; false
       ; false
       ; false
       ; false
       ; true
       ; false
       ; false
       ; false
       ; false
       ; false
       ; false
       ; true
       ; true
       ; false
       ; false
       ; false
       ; false
       ; false
       ; false ]
