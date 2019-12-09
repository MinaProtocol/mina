open Ppxlib
open Asttypes
open Parsetree
open Longident
open Async
open Core

let smallest_out_of_scope_field_element =
  let open Snark_params.Tick.Inner_curve.Coefficients in
  let open Snark_params.Tick.Field in
  let rec go x =
    if is_square ((x * x * x) + (a * x) + b) then go (x + one) else x
  in
  go zero

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

let () =
  don't_wait_for (main ()) ;
  never_returns (Scheduler.go ())
