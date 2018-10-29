open Core_kernel

let genesis = Time.now ()

module Call_ring = struct
  type t = string * int ref * int array

  let window = 8

  let create name : t = (name, ref 0, Array.create ~len:window 0)

  let report ((name, epoch, cs) : t) =
    Printf.printf !"$$$ %s@%d: [%s]\n%!" name !epoch
      (String.concat ~sep:"," (Array.to_list (Array.map cs ~f:string_of_int)))

  let record ((name, epoch, cs) : t) =
    let now = Time.now () in
    let span_since_genesis = Time.diff now genesis in
    let mins_since_genesis =
      int_of_float (Time.Span.to_min span_since_genesis)
    in
    let curr_epoch = mins_since_genesis / window in
    let curr_index = mins_since_genesis mod window in
    if curr_epoch > !epoch then (
      report (name, epoch, cs) ;
      epoch := curr_epoch ;
      Array.fill cs ~pos:0 ~len:(Array.length cs) 0 ) ;
    cs.(curr_index) <- cs.(curr_index) + 1
end

let rings = String.Table.create ()

let record_call name =
  let ring =
    match Hashtbl.find rings name with
    | Some ring -> ring
    | None ->
        let ring = Call_ring.create name in
        Hashtbl.set rings ~key:name ~data:ring ;
        ring
  in
  Call_ring.record ring
