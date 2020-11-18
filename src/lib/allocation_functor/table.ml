open Core_kernel

type allocation_info = {count: int} [@@deriving yojson]

let empty_allocation_info = {count= 0}

let table = String.Table.create ()

let capture id =
  String.Table.update table id ~f:(fun info_opt ->
      let info = Option.value info_opt ~default:empty_allocation_info in
      {count= info.count + 1} ) ;
  Coda_metrics.(
    Gauge.inc_one (Object_lifetime_statistics.object_count ~name:id))

let release id =
  String.Table.update table id ~f:(fun info_opt ->
      let info = Option.value info_opt ~default:empty_allocation_info in
      {count= info.count - 1} ) ;
  Coda_metrics.(
    Gauge.dec_one (Object_lifetime_statistics.object_count ~name:id))

let attach_finalizer id obj =
  capture id ;
  Gc.Expert.add_finalizer_exn obj (fun _ -> release id) ;
  obj

let dump () =
  let entries =
    String.Table.to_alist table |> List.Assoc.map ~f:allocation_info_to_yojson
  in
  `Assoc entries
