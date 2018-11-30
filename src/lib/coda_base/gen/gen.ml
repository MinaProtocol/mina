open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core
open Crypto_params
open Signature_lib

let seed = "Coda_sample_keypairs"

let random_bool = Crs.create ~seed

module Group = Crypto_params_init.Tick_backend.Inner_curve
open Tuple_lib

let bigint_of_bits bits =
  List.foldi bits ~init:Bigint.zero ~f:(fun i acc b ->
      if b then Bigint.(acc + (of_int 2 lsl i)) else acc )

let rec random_scalar () =
  let n =
    bigint_of_bits
      (List.init Tock0.Field.size_in_bits ~f:(fun _ -> random_bool ()))
  in
  if Bigint.(n < Tock0.Field.size) then
    Tock0.Bigint.(to_field (of_bignum_bigint n))
  else random_scalar ()

let keypairs =
  let n = 40 in
  List.init n ~f:(fun _ ->
      let pk = random_scalar () in
      Keypair.of_private_key_exn pk )

let expr ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let earray =
    E.pexp_array
      (List.map keypairs ~f:(fun {public_key; private_key} ->
           E.pexp_tuple
             [ estring
                 (Public_key.Compressed.to_base64
                    (Public_key.compress public_key))
             ; estring (Private_key.to_base64 private_key) ] ))
  in
  let%expr conv (pk, sk) =
    ( Signature_lib.Public_key.Compressed.of_base64_exn pk
    , Signature_lib.Private_key.of_base64_exn sk )
  in
  Array.map conv [%e earray]

let structure ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%str let keypairs = [%e expr ~loc]]

let json =
  `List
    (List.map keypairs ~f:(fun kp ->
         `Assoc
           [ ( "public_key"
             , `String
                 Public_key.(Compressed.to_base64 (compress kp.public_key)) )
           ; ("private_key", `String (Private_key.to_base64 kp.private_key)) ]
     ))

let main () =
  let fmt =
    Format.formatter_of_out_channel (Out_channel.create "sample_keypairs.ml")
  in
  Yojson.pretty_to_channel (Out_channel.create "sample_keypairs.json") json ;
  Pprintast.top_phrase fmt (Ptop_def (structure ~loc:Ppxlib.Location.none)) ;
  exit 0

let () = main ()
