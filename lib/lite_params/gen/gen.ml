open Ppxlib
open Asttypes
open Parsetree
open Core

let pedersen_params ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let arr = Crypto_params.Pedersen_params.params in
  let arr_expr =
    List.init (Array.length arr) ~f:(fun i ->
        let g, _, _, _ = arr.(i) in
        estring
          (B64.encode
             (Binable.to_string (module Snarkette.Mnt6.G1) (Lite_compat.g1 g)))
    )
    |> E.pexp_array
  in
  [%expr
    Array.map
      (fun s ->
        Core_kernel.Binable.of_string (module Snarkette.Mnt6.G1) (B64.decode s)
        )
      [%e arr_expr]]

let wrap_vk ~loc =
  let open Async in
  let%map keys = Snark_keys.blockchain_verification () in
  let vk = keys.wrap in
  let module V =
    Snarky.Gm_verifier_gadget.Mnt4 (Snark_params.Tick)
      (struct
        let input_size = 1
      end)
      (Snark_params.Tick.Inner_curve) in
  let native_bits =
    V.Verification_key_data.(to_bits (full_data_of_verification_key vk))
  in
  let vk = Lite_compat.verification_key vk in
  let caml_bits =
    Fold_lib.Fold.to_list
      (Snarkette.Mnt6.Groth_maller.Verification_key.fold_bits vk)
  in
  let bitstring bs =
    List.map bs ~f:(fun b -> if b then '1' else '0') |> String.of_char_list
  in
  printf "Native: %s\n" (bitstring native_bits) ;
  printf "Caml: %s\n" (bitstring caml_bits) ;
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%expr
    Core_kernel.Binable.of_string
      (module Snarkette.Mnt6.Groth_maller.Verification_key)
      (B64.decode
         [%e
           estring
             (B64.encode
                (Binable.to_string
                   (module Snarkette.Mnt6.Groth_maller.Verification_key)
                   vk))])]

open Async

let main () =
  let fmt =
    Format.formatter_of_out_channel (Out_channel.create "lite_params.ml")
  in
  let loc = Ppxlib.Location.none in
  let%map wrap_vk_expr = wrap_vk ~loc in
  let structure =
    [%str
      let pedersen_params = [%e pedersen_params ~loc]

      let wrap_vk = [%e wrap_vk_expr]]
  in
  Pprintast.top_phrase fmt (Ptop_def structure) ;
  exit 0

let () =
  ignore (main ()) ;
  never_returns (Scheduler.go ())
