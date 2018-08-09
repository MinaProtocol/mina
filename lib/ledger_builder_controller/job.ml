open Async_kernel

type ('input, 'output) t =
  'input * ('input -> ('output, 'input) Interruptible.t * 'input Ivar.t)

let run ((i, g): ('input, 'output) t) = g i
