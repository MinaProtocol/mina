open Core_kernel

let get_rfc3339_time () =
  let tm = Core.Unix.gettimeofday () in
  match Ptime.of_float_s tm with
  | None ->
      (* should never occur *)
      failwith "Could not convert current time to Ptime.t"
  | Some ptime ->
      Ptime.to_rfc3339 ~tz_offset_s:0 ptime
