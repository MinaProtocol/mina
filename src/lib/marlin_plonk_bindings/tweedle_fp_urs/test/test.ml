open Marlin_plonk_bindings_tweedle_fp_urs
module Fp = Marlin_plonk_bindings_tweedle_fp

let () =
  let urs = create 17 in
  let _lgr = lagrange_commitment urs ~domain_size:255 1 in
  let _evals =
    commit_evaluations urs ~domain_size:12 [|Fp.of_int 15; Fp.of_int 35|]
  in
  Format.printf "batch_accumulator_check=%b@."
    (batch_accumulator_check urs [||] [||]) ;
  ( match h urs with
  | Infinite ->
      Format.printf "h= Infinite@."
  | Finite (x, y) ->
      Format.printf "h= (%s, %s)@."
        Marlin_plonk_bindings_tweedle_fq.(to_string x)
        Marlin_plonk_bindings_tweedle_fq.(to_string y) ) ;
  write urs "./test_urs_17" ;
  let urs2 =
    match read "./test_urs_17" with Some urs -> urs | None -> assert false
  in
  Sys.remove "./test_urs_17" ;
  let _lgr = lagrange_commitment urs2 ~domain_size:255 1 in
  let _evals =
    commit_evaluations urs2 ~domain_size:12 [|Fp.of_int 15; Fp.of_int 35|]
  in
  Format.printf "batch_accumulator_check=%b@."
    (batch_accumulator_check urs2 [||] [||]) ;
  match h urs with
  | Infinite ->
      Format.printf "h= Infinite@."
  | Finite (x, y) ->
      Format.printf "h= (%s, %s)@."
        Marlin_plonk_bindings_tweedle_fq.(to_string x)
        Marlin_plonk_bindings_tweedle_fq.(to_string y)
