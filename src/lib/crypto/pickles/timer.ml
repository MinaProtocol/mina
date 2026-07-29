open Core

let l = ref ""

let r = ref (Time_float.now ())

let start =
  Common.when_profiling
    (fun loc ->
      r := Time_float.now () ;
      l := loc )
    ignore

let clock =
  Common.when_profiling
    (fun loc ->
      let t = Time_float.now () in
      printf "%s -> %s: %s\n%!" !l loc
        (Time_float.Span.to_string_hum (Time_float.diff t !r)) ;
      r := t ;
      l := loc )
    ignore
