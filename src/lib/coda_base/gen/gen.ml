open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core_kernel
open Signature_lib

let keypairs =
  let n = 120 in
  let generated_keypairs =
    let sks =
      Quickcheck.(
        random_value ~seed:(`Deterministic "Coda_sample_keypairs")
          (Generator.list_with_length n Private_key.gen))
    in
    List.map sks ~f:Keypair.of_private_key_exn
  in
(*
  let () =
    Core.printf "key0 ex: %s\n%!"
      (Private_key.to_base58_check (Private_key.create ())) ;
    let pk =
      Private_key.of_base58_check_exn
        "21mS8Wb8E2FctkfR2cZcxCJSGRnyNQsLatRHiT1WYiXtdaRJSxPbPx"
      (*        non-raw binio  "Z2iaxFLZ3Xnb3mHYg56vwrbCdC5Y7ZQo1FUf31j8L18cW7XWH7GYxFxkZgztD6DXxQpNBs5FnD4" *)
      (*         "6BnSKU5GQjgvEPbM45Qzazsf6M8eCrQdpL7x4jAvA4sr8Ga3FAx8AxdgWcqN7uNGu1SthMgDeMSUvEbkY9a56UxwmJpTzhzVUjfgfFsjJSVp9H1yWHt6H5couPNpF7L7e5u7NBGYnDMhx" *)
    in
    let pubkey = Public_key.of_private_key_exn pk in
    Core.printf !"privkey0 %{sexp:Private_key.t}\n%!" pk ;
    Core.printf !"pubkey0 %{sexp:Public_key.t}\n%!" pubkey
  in
*)
  List.cons
    (* FIXME #2936: remove this "precomputed VRF keypair" *)
    (* This key is also at the start of all the release ledgers. It's needed to generate a valid genesis transition *)
    (Keypair.of_private_key_exn
       (Private_key.of_base58_check_exn
          "21mS8Wb8E2FctkfR2cZcxCJSGRnyNQsLatRHiT1WYiXtdaRJSxPbPx"))
    generated_keypairs

let expr ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let earray =
    E.pexp_array
      (List.map keypairs ~f:(fun {public_key; private_key} ->
           Core.printf
             !"keypair gen privkey %s %{sexp:Private_key.t}\n%!"
             __LOC__ private_key ;
           Core.printf
             !"keypair gen %s %{sexp:Public_key.t}\n%!"
             __LOC__ public_key ;
           E.pexp_tuple
             [ estring
                 (Binable.to_string
                    (module Public_key.Compressed.Stable.Latest)
                    (Public_key.compress public_key))
             ; estring
                 (Binable.to_string
                    (module Private_key.Stable.Latest)
                    private_key) ] ))
  in
  let%expr conv (pk, sk) =
    ( Core_kernel.Binable.of_string
        (module Signature_lib.Public_key.Compressed.Stable.Latest)
        pk
    , Core_kernel.Binable.of_string
        (module Signature_lib.Private_key.Stable.Latest)
        sk )
  in
  Array.map conv [%e earray]

let structure ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%str let keypairs = lazy [%e expr ~loc]]

let json =
  `List
    (List.map keypairs ~f:(fun kp ->
         `Assoc
           [ ( "public_key"
             , `String
                 Public_key.(
                   Compressed.to_base58_check (compress kp.public_key)) )
           ; ( "private_key"
             , `String (Private_key.to_base58_check kp.private_key) ) ] ))

let main () =
  Out_channel.with_file "sample_keypairs.ml" ~f:(fun ml_file ->
      let fmt = Format.formatter_of_out_channel ml_file in
      Pprintast.top_phrase fmt (Ptop_def (structure ~loc:Ppxlib.Location.none))
  ) ;
  Out_channel.with_file "sample_keypairs.json" ~f:(fun json_file ->
      Yojson.pretty_to_channel json_file json ) ;
  exit 0

let () = main ()
