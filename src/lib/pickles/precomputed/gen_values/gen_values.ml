open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core_kernel
open Zexe_backend.Tweedle
open Pickles_types

let () =
  Dee_based_plonk.Keypair.set_urs_info [] ;
  Dum_based_plonk.Keypair.set_urs_info []

let time lab f =
  printf "%s: %!" lab ;
  let start = Time.now () in
  let x = f () in
  printf "%s\n%!" (Time.Span.to_string_hum (Time.diff (Time.now ()) start)) ;
  x

let unwrap = function
  | `With_degree_bound _ ->
      assert false
  | `Without_degree_bound a ->
      Array.to_list a

let max_public_input_size = 128

let dee =
  let max_domain_log2 = Nat.to_int Backend.Tock.Rounds.n in
  List.map
    (List.range ~start:`inclusive ~stop:`inclusive 1 max_domain_log2)
    ~f:(fun d ->
      let domain_size = 1 lsl d in
      let n = Int.min max_public_input_size domain_size in
      List.init n ~f:(fun i ->
          ksprintf time "dee %d" i (fun () ->
              Snarky_bn382.Tweedle.Dee.Field_urs.lagrange_commitment
                (Dee_based_plonk.Keypair.load_urs ())
                (Unsigned.Size_t.of_int domain_size)
                (Unsigned.Size_t.of_int i) )
          |> Zexe_backend.Tweedle.Fp_poly_comm.of_backend_without_degree_bound
          |> unwrap ) )

let dum =
  let max_domain_log2 = Nat.to_int Backend.Tick.Rounds.n in
  List.map
    (List.range ~start:`inclusive ~stop:`inclusive 1 max_domain_log2)
    ~f:(fun d ->
      let domain_size = 1 lsl d in
      let n = Int.min max_public_input_size domain_size in
      List.init n ~f:(fun i ->
          ksprintf time "dum %d" i (fun () ->
              Snarky_bn382.Tweedle.Dum.Field_urs.lagrange_commitment
                (Dum_based_plonk.Keypair.load_urs ())
                (Unsigned.Size_t.of_int domain_size)
                (Unsigned.Size_t.of_int i) )
          |> Zexe_backend.Tweedle.Fq_poly_comm.of_backend_without_degree_bound
          |> unwrap ) )

let mk xss ~f =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = Location.none
  end) in
  let open E in
  pexp_array
    (List.map xss ~f:(fun xs ->
         pexp_array (List.map xs ~f:(fun g -> pexp_array (List.map g ~f))) ))

let structure =
  let loc = Ppxlib.Location.none in
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let fq x =
    [%expr f [%e estring (Bigint256.to_hex_string (Fq.to_bigint x))]]
  in
  let fp x =
    [%expr f [%e estring (Bigint256.to_hex_string (Fp.to_bigint x))]]
  in
  [%str
    module Lagrange_precomputations = struct
      let index_of_domain_log2 d = d - 1

      let max_public_input_size = 150

      open Zexe_backend.Tweedle

      let dee =
        let f s = Fq.of_bigint (Bigint256.of_hex_string s) in
        [%e mk dee ~f:(fun (x, y) -> pexp_tuple [fq x; fq y])]

      let dum =
        let f s = Fp.of_bigint (Bigint256.of_hex_string s) in
        [%e mk dum ~f:(fun (x, y) -> pexp_tuple [fp x; fp y])]
    end]

let () =
  let target = Sys.argv.(1) in
  let fmt = Format.formatter_of_out_channel (Out_channel.create target) in
  Pprintast.top_phrase fmt (Ptop_def structure) ;
  exit 0
