(* Statistics and InfluxDB line protocol shared by the benchmark tools, so
   that their percentiles agree and their points are valid line protocol. *)

open Core_kernel

module Stats = struct
  (** [sorted xs] is [xs] in ascending order, as an array. *)
  let sorted xs =
    let a = Array.of_list xs in
    Array.sort a ~compare:Float.compare ;
    a

  (** Nearest-rank percentile of the ascending array [sorted], [p] in [0, 1].
      [None] when there is no sample. *)
  let percentile sorted p =
    let n = Array.length sorted in
    if n = 0 then None
    else
      let rank = Float.iround_up_exn (p *. Float.of_int n) in
      Some sorted.(Int.clamp_exn (rank - 1) ~min:0 ~max:(n - 1))

  (** The middle value of the ascending array [sorted], or the mean of the two
      middle values for an even count. [None] when there is no sample. *)
  let median sorted =
    let n = Array.length sorted in
    if n = 0 then None
    else if n % 2 = 1 then Some sorted.(n / 2)
    else Some ((sorted.((n / 2) - 1) +. sorted.(n / 2)) /. 2.)

  (** The largest value of the ascending array [sorted]. *)
  let max sorted =
    if Array.is_empty sorted then None else Some (Array.last sorted)
end

module Influx = struct
  type value = Float of float | Int of int | Int64 of int64 | String of string

  (* A measurement escapes commas and spaces; tag keys, tag values and field
     keys also escape equals signs. *)
  let escape ~special s =
    String.concat_map s ~f:(fun c ->
        if List.mem special c ~equal:Char.equal then "\\" ^ String.of_char c
        else String.of_char c )

  let escape_measurement = escape ~special:[ ','; ' ' ]

  let escape_key = escape ~special:[ ','; '='; ' ' ]

  (** A field value, or [None] for a float that is not finite: line protocol
      has no NaN or infinity. *)
  let format_value = function
    | Float f ->
        Option.some_if (Float.is_finite f) (sprintf "%.3f" f)
    | Int i ->
        Some (sprintf "%di" i)
    | Int64 i ->
        Some (sprintf "%Ldi" i)
    | String s ->
        Some
          ( "\""
          ^ String.concat_map s ~f:(function
              | '"' ->
                  "\\\""
              | '\\' ->
                  "\\\\"
              | c ->
                  String.of_char c )
          ^ "\"" )

  (** One point. A field whose value has no line-protocol form is left out,
      and so is a tag with an empty value. [None] when no field is left. *)
  let line ~measurement ~tags ~fields ~timestamp_ns =
    let fields =
      List.filter_map fields ~f:(fun (key, value) ->
          Option.map (format_value value) ~f:(fun v -> escape_key key ^ "=" ^ v) )
    in
    if List.is_empty fields then None
    else
      let tags =
        List.filter_map tags ~f:(fun (key, value) ->
            Option.some_if
              (not (String.is_empty value))
              ("," ^ escape_key key ^ "=" ^ escape_key value) )
      in
      Some
        (sprintf "%s%s %s %s"
           (escape_measurement measurement)
           (String.concat tags)
           (String.concat ~sep:"," fields)
           (Int63.to_string timestamp_ns) )
end
