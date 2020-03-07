[%%import
"/src/config.mlh"]

open Ppxlib
open Asttypes
open Parsetree
open Longident
open Async
open Core_kernel

[%%ifdef
consensus_mechanism]

module Coefficients = Snark_params.Tick.Inner_curve.Coefficients
module Field = Snark_params.Tick.Field

[%%else]

module Coefficients = Snark_params_nonconsensus.Inner_curve.Coefficients
module Field = Snark_params_nonconsensus.Field

[%%endif]

let smallest_out_of_scope_field_element =
  let open Coefficients in
  let open Field in
  let rec go x =
    if is_square ((x * x * x) + (a * x) + b) then go (x + one) else x
  in
  go zero

[%%ifdef
consensus_mechanism]

let main () =
  let target = Sys.argv.(1) in
  let format = Format.formatter_of_out_channel (Out_channel.create target) in
  let loc = Ppxlib.Location.none in
  let structure =
    [%str
      let t =
        [%e
          [%expr
            Snark_params.Tick.Field.t_of_sexp
              [%e
                Ppx_util.expr_of_sexp ~loc
                  (Snark_params.Tick.Field.sexp_of_t
                     smallest_out_of_scope_field_element)]]]]
  in
  Pprintast.top_phrase format (Ptop_def structure) ;
  exit 0

[%%else]

let main () =
  let target = Sys.argv.(1) in
  let format = Format.formatter_of_out_channel (Out_channel.create target) in
  let loc = Ppxlib.Location.none in
  let structure =
    [%str
      let t =
        [%e
          [%expr
            Snark_params_nonconsensus.Field.t_of_sexp
              [%e
                Ppx_util.expr_of_sexp ~loc
                  (Snark_params_nonconsensus.Field.sexp_of_t
                     smallest_out_of_scope_field_element)]]]]
  in
  Pprintast.top_phrase format (Ptop_def structure) ;
  exit 0

[%%endif]

let () =
  don't_wait_for (main ()) ;
  never_returns (Scheduler.go ())
