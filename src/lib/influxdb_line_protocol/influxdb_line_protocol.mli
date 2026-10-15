(** InfluxDB line protocol: points for [influx write], as the benchmarks send
    them to InfluxDB (buildkite/scripts/bench/send.sh).

    {v measurement,tag=value,... field=value,... timestamp v} *)

open Core

module Field : sig
  type t =
    | Int of int  (** written with the [i] suffix *)
    | Float of float
        (** written with 15 significant digits; a non-finite value is left
            out, as InfluxDB rejects the whole line *)
    | String of string
    | Bool of bool
end

type t

(** A point. [timestamp] defaults to now; tags with an empty value are left
    out, as InfluxDB rejects them. *)
val create :
     ?timestamp:Time_ns.t
  -> ?tags:(string * string) list
  -> measurement:string
  -> (string * Field.t) list
  -> t

(** The point as one line, escaped as the protocol requires. Raises when the
    point has no field to write. *)
val to_line : t -> string

(** Write [points] to [path], one line each. *)
val write_file : string -> t list -> unit
