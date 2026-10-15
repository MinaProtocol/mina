(** InfluxDB line protocol: points for [influx write], as the benchmarks send
    them to InfluxDB (buildkite/scripts/bench/send.sh).

    {v measurement,tag=value,... field=value,... timestamp v}

    Names (the measurement, tag keys and field keys) are set in code: each
    must be non-empty, of [A-Za-z0-9_.-], and must not start with [_]
    (reserved by InfluxDB). Tag values are strings, escaped as the protocol
    requires; they must be non-empty and on one line. Field values are
    numbers. *)

open Core

module Field : sig
  type t =
    | Int of int  (** written with the [i] suffix *)
    | Float of float  (** finite; written with 15 significant digits *)
end

type t

(** A point; [timestamp] defaults to now. Raises [Invalid_argument] for an
    invalid name, an empty or multi-line tag value, a non-finite float, a key
    given twice, or no field. *)
val create :
     ?timestamp:Time_ns.t
  -> ?tags:(string * string) list
  -> measurement:string
  -> (string * Field.t) list
  -> t

(** The point as one line. *)
val to_line : t -> string

(** Write [points] to [path], one line each. *)
val write_file : string -> t list -> unit
