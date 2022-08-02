module Schema = Graphql_wrapper.Make(Graphql_async.Schema)
open Schema

let interval () : (_, (Core_kernel.Time.Span.t * Core_kernel.Time.Span.t) option) typ =
      obj "Interval" ~fields:(fun _ ->
          [ field "start" ~typ:(non_null string)
              ~args:Arg.[]
              ~resolve:(fun _ (start, _) ->
                Core_kernel.Time.Span.to_ms start |> Int64.of_float |> Int64.to_string )
          ; field "stop" ~typ:(non_null string)
              ~args:Arg.[]
              ~resolve:(fun _ (_, end_) ->
                Core_kernel.Time.Span.to_ms end_ |> Int64.of_float |> Int64.to_string )
          ] )

open Graphql_basic_scalars.Shorthand
let histogram () : (_, Perf_histograms.Report.t option) typ =
  obj "Histogram" ~fields:(fun _ ->
      List.rev
      @@ Perf_histograms.Report.Fields.fold ~init:[]
           ~values:(id ~typ:Schema.(non_null (list (non_null int))))
           ~intervals:(id ~typ:(non_null (list (non_null (interval ())))))
           ~underflow:nn_int ~overflow:nn_int )
