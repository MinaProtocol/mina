open Core

let l = ref ""

let r = ref (Time.now ())

let start =
  Common.when_profiling
    (fun loc ->
      r := Time.now () ;
      l := loc )
    ignore

let clock =
  Common.when_profiling
    (fun loc ->
      let t = Time.now () in
      Core.printf "%s -> %s: %s\n%!" !l loc
        (Time.Span.to_string_hum (Time.diff t !r)) ;
      r := t ;
      l := loc )
    ignore
