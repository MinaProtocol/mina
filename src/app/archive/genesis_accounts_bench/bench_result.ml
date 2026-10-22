(* bench_result.ml -- what a genesis_accounts_bench run measured *)

open Core

type t =
  { rows : int  (** rows each timed write added *)
  ; ledger_load_ms : float  (** loading the genesis ledger, once *)
  ; write_ms : float list  (** each timed write, in run order *)
  }

let runs t = List.length t.write_ms

let median_ms t =
  let sorted = List.sort t.write_ms ~compare:Float.compare in
  List.nth_exn sorted (List.length sorted / 2)

let min_ms t = List.reduce_exn t.write_ms ~f:Float.min

let max_ms t = List.reduce_exn t.write_ms ~f:Float.max

let rows_per_s t = Float.of_int t.rows /. (median_ms t /. 1000.)

let summary t =
  sprintf
    "genesis_accounts write: %d rows, %d runs, median %.0f ms (min %.0f, max \
     %.0f), %.0f rows/s; genesis ledger loaded in %.0f ms"
    t.rows (runs t) (median_ms t) (min_ms t) (max_ms t) (rows_per_s t)
    t.ledger_load_ms

(** The result as one InfluxDB line. *)
let to_line ~measurement ~tags t =
  Influxdb_line_protocol.(
    to_line
      (create ~tags ~measurement
         [ ("rows", Int t.rows)
         ; ("median_ms", Float (median_ms t))
         ; ("min_ms", Float (min_ms t))
         ; ("max_ms", Float (max_ms t))
         ; ("rows_per_s", Float (rows_per_s t))
         ; ("ledger_load_ms", Float t.ledger_load_ms)
         ; ("runs", Int (runs t))
         ] ))
