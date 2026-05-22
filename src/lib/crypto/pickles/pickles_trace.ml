(** Trace logger for byte-identical pickles transcript reproduction tests.
 *
 *  Sister module to PureScript's `Pickles.Trace`. Both write to the file
 *  named by the `PICKLES_TRACE_FILE` env var, one line per traced value,
 *  in the format `[LABEL] DECIMAL_VALUE`. Both sides are expected to emit
 *  the same labels in the same order so the resulting trace files can be
 *  diffed.
 *
 *  Environment:
 *  - `PICKLES_TRACE_FILE` — path to the trace file (truncated on first
 *    write). When unset, all trace functions are no-ops, so production
 *    OCaml code that calls these helpers pays only a single env-var
 *    lookup per call.
 *
 *  Label naming convention: semantic, dot-separated, lowercase. Examples:
 *    [step.app_state]
 *    [step.unfinalized.0.beta]
 *    [step.proof.public_input.0]
 *    [wrap.statement.deferred_values.combined_inner_product]
 *
 *  The PureScript-side helper at packages/pickles/src/Pickles/Trace.purs
 *  MUST emit the same label strings for the same logical values.
 *)

open Core_kernel

let env_var = "PICKLES_TRACE_FILE"

(* The trace channel is opened lazily on first write and kept open for the
 * lifetime of the process. We truncate on first open so each run produces
 * a fresh trace file (re-running the test without restarting OCaml would
 * append to the same file, which is fine for our use case but to be aware
 * of). *)
let trace_channel : Out_channel.t option ref = ref None

let initialized = ref false

let get_channel () : Out_channel.t option =
  if !initialized then !trace_channel
  else begin
    initialized := true ;
    (match Stdlib.Sys.getenv_opt env_var with
    | None ->
        trace_channel := None
    | Some path ->
        let ch = Out_channel.create ~binary:false ~append:false path in
        trace_channel := Some ch) ;
    !trace_channel
  end

let emit_line label value_str =
  match get_channel () with
  | None ->
      ()
  | Some ch ->
      Out_channel.output_string ch "[" ;
      Out_channel.output_string ch label ;
      Out_channel.output_string ch "] " ;
      Out_channel.output_string ch value_str ;
      Out_channel.output_char ch '\n' ;
      Out_channel.flush ch

(* ------------------------------------------------------------------------ *)
(* Field elements                                                           *)
(* ------------------------------------------------------------------------ *)

(** Trace a [Tick.Field.t] (= Vesta scalar field = Pallas base field = Fp). *)
let tick_field label x =
  emit_line label (Backend.Tick.Field.to_string x)

(** Trace a [Tock.Field.t] (= Pallas scalar field = Vesta base field = Fq). *)
let tock_field label x =
  emit_line label (Backend.Tock.Field.to_string x)

(* ------------------------------------------------------------------------ *)
(* Curve points                                                             *)
(* ------------------------------------------------------------------------ *)

(** Trace a [Tick.Inner_curve.Affine.t] (= Pallas point, coords in Fp).
 *  Emits two lines: [{label}.x] and [{label}.y].
 *
 *  Uses the underlying coordinate fields directly via the affine
 *  representation; matches what the PureScript-side helper emits for an
 *  [AffinePoint StepField]. *)
let tick_point label (x, y : Backend.Tick.Inner_curve.Affine.t) =
  emit_line (label ^ ".x") (Backend.Tick.Field.to_string x) ;
  emit_line (label ^ ".y") (Backend.Tick.Field.to_string y)

(** Trace a [Tock.Inner_curve.Affine.t] (= Vesta point, coords in Fq). *)
let tock_point label (x, y : Backend.Tock.Inner_curve.Affine.t) =
  emit_line (label ^ ".x") (Backend.Tock.Field.to_string x) ;
  emit_line (label ^ ".y") (Backend.Tock.Field.to_string y)

(* ------------------------------------------------------------------------ *)
(* Primitives                                                               *)
(* ------------------------------------------------------------------------ *)

let int label x = emit_line label (Int.to_string x)

let bool label x = emit_line label (if x then "1" else "0")

let string label x = emit_line label x

(* ------------------------------------------------------------------------ *)
(* Arrays / vectors                                                         *)
(* ------------------------------------------------------------------------ *)

(** Trace a [Tick.Field.t array]. Emits one line per element with index
 *  appended to the label: [{label}.0], [{label}.1], … *)
let tick_field_array label xs =
  Array.iteri xs ~f:(fun i x ->
      tick_field (label ^ "." ^ Int.to_string i) x)

let tock_field_array label xs =
  Array.iteri xs ~f:(fun i x ->
      tock_field (label ^ "." ^ Int.to_string i) x)

let tick_point_array label xs =
  Array.iteri xs ~f:(fun i x ->
      tick_point (label ^ "." ^ Int.to_string i) x)

let tock_point_array label xs =
  Array.iteri xs ~f:(fun i x ->
      tock_point (label ^ "." ^ Int.to_string i) x)
