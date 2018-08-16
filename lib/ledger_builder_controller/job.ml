open Async_kernel

type ('input, 'output) t =
  'input * ('input -> ('output, unit) Interruptible.t * 'input Ivar.t)

let run ((i, g): ('input, 'output) t) = g i
