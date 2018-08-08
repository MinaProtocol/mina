open Async_kernel

type ('input, 'output) t =
  'input * ('input -> ('output, 'input) Interruptible.t * 'input Ivar.t)

let xmap_input (i, g) ~f ~finv = (finv i, fun in2 -> g (f in2))

let map (i, g) ~f =
  let m, ivar = g i in
  (i, (Interruptible.map m ~f, ivar))

let run ((i, g): ('input, 'output) t) = g i
