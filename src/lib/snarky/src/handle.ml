open Core_kernel

type ('var, 'value) t = {var: 'var; value: 'value option}

let value (t : ('var, 'value) t) : ('value, 'cvar -> 'field, 's) As_prover0.t =
 fun _ s -> (s, Option.value_exn t.value)

let var {var; _} = var
