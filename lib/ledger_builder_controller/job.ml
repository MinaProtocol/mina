open Core_kernel
open Async_kernel

type ('input, 'output) t =
  { input: 'input
  ; fn: 'input -> ('output, unit) Interruptible.t * 'input Ivar.t
  ; after: unit -> unit }

let create input ~f = {input; fn= f; after= Fn.id}

let run ({input; fn; after}: ('input, 'output) t) =
  let interruptible, ivar = fn input in
  (Interruptible.finally interruptible ~f:after, ivar)

let after {input; fn; after} ~f = {input; fn; after= Fn.compose after f}
