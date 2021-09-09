open Core_kernel

(* For now, we'll just support Exp_time_spans histogram *)
let t : Histogram.Exp_time_spans.t String.Table.t = String.Table.create ()

let add_span ~name s =
  let hist =
    String.Table.find_or_add t name ~default:Histogram.Exp_time_spans.create
  in
  Histogram.Exp_time_spans.add hist s

let report ~name =
  String.Table.find_and_call t name
    ~if_found:(fun tbl -> Some (Histogram.Exp_time_spans.report tbl))
    ~if_not_found:(fun _ -> None)

let wipe () =
  String.Table.iter t ~f:(fun tbl -> Histogram.Exp_time_spans.clear tbl)
