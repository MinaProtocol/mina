open Core
open Async

let decorate_dispatch ~name (dispatch : ('q, 'r) Intf.dispatch) :
    ('q, 'r) Intf.dispatch =
 fun conn q ->
  let open Deferred.Or_error.Let_syntax in
  let start = Time.now () in
  let%map r = dispatch conn q in
  Perf_histograms0.add_span
    ~name:(sprintf "rpc_dispatch_%s" name)
    (Time.diff (Time.now ()) start) ;
  r

let deocorate_impl ~name (impl : ('q, 'r, 'state) Intf.impl) :
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
        (f |> deocorate_impl ~name)
  end
end
