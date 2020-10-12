open Core
open Async

let decorate_dispatch ~name (dispatch : ('q, 'r) Intf.dispatch) :
    ('q, 'r) Intf.dispatch =
 fun conn q ->
  let open Deferred.Or_error.Let_syntax in
  let start = Time.now () in
  let%map r = dispatch conn q in
  let span = Time.diff (Time.now ()) start in
  Perf_histograms0.add_span ~name:(sprintf "rpc_dispatch_%s" name) span ;
  Coda_metrics.(
    Network.Rpc_latency_histogram.observe Network.rpc_latency_ms_summary
      (Time.Span.to_ms span)) ;
  Coda_metrics.(
    Gauge.set (Network.rpc_latency_ms ~name) (Time.Span.to_ms span)) ;
  r

let decorate_impl ~name (impl : ('q, 'r, 'state) Intf.impl) :
    ('q, 'r, 'state) Intf.impl =
 fun state ~version q ->
  let open Deferred.Let_syntax in
  let start = Time.now () in
  let%map r = impl state ~version q in
  Perf_histograms0.add_span
    ~name:(sprintf "rpc_impl_%s" name)
    (Time.diff (Time.now ()) start) ;
  r

module Plain = struct
  module Extend (Rpc : Intf.Rpc.S) :
    Intf.Patched.S
    with type callee_query := Rpc.Callee.query
     and type callee_response := Rpc.Callee.response
     and type caller_query := Rpc.Caller.query
     and type caller_response := Rpc.Caller.response = struct
    include Rpc

    let dispatch_multi = dispatch_multi |> decorate_dispatch ~name

    let implement_multi ?log_not_previously_seen_version f =
      implement_multi ?log_not_previously_seen_version
        (f |> decorate_impl ~name)
  end

  module Decorate_bin_io (M : Intf.Rpc.S) (Rpc : Intf.Versioned_rpc(M).S) =
  struct
    include Rpc

    module type Running_stats = sig
      val max_value : unit -> int

      val average_value : unit -> float

      val update_stats : int -> unit
    end

    module Make_stats () : Running_stats = struct
      let num_values_ref = ref 0

      let max_value_ref = ref 0

      let average_value_ref = ref 0.0

      let max_value () = !max_value_ref

      let average_value () = !average_value_ref

      let update_stats v =
        incr num_values_ref ;
        (* Knuth's online mean algorithm *)
        let delta = Float.of_int v -. !average_value_ref in
        average_value_ref :=
          !average_value_ref +. (delta /. Float.of_int !num_values_ref) ;
        if v > !max_value_ref then max_value_ref := v
    end

    module Read_stats = Make_stats ()

    let bin_read_response buf ~pos_ref =
      let open Coda_metrics in
      let response = bin_read_response buf ~pos_ref in
      let read_size = bin_size_response response in
      Read_stats.update_stats read_size ;
      let name = M.name ^ "_read_response" in
      let observations =
        [ (Network.rpc_size_bytes ~name, read_size |> Float.of_int)
        ; (Network.rpc_max_bytes ~name, Read_stats.max_value () |> Float.of_int)
        ; (Network.rpc_avg_bytes ~name, Read_stats.average_value ()) ]
      in
      List.iter observations ~f:(fun (histogram, value) ->
          Network.Rpc_size_histogram.observe histogram value ) ;
      response

    let bin_reader_response =
      { Bin_prot.Type_class.read= bin_read_response
      ; vtag_read= __bin_read_response__ }

    module Write_stats = Make_stats ()

    let bin_write_response buf ~pos response =
      let open Coda_metrics in
      let write_size = bin_size_response response in
      Write_stats.update_stats write_size ;
      let name = M.name ^ "_write_response" in
      let observations =
        [ (Network.rpc_size_bytes ~name, write_size |> Float.of_int)
        ; ( Network.rpc_max_bytes ~name
          , Write_stats.max_value () |> Float.of_int )
        ; (Network.rpc_avg_bytes ~name, Write_stats.average_value ()) ]
      in
      List.iter observations ~f:(fun (histogram, value) ->
          Network.Rpc_size_histogram.observe histogram value ) ;
      bin_write_response buf ~pos response

    let bin_writer_response =
      {Bin_prot.Type_class.write= bin_write_response; size= bin_size_response}

    let bin_response =
      { Bin_prot.Type_class.reader= bin_reader_response
      ; writer= bin_writer_response
      ; shape= bin_shape_response }
  end
end
