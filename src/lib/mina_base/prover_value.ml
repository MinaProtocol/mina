open Snark_params.Tick.Run

type 'a t = 'a Typ.prover_value

let get x = As_prover.read (Typ.prover_value ()) x

let create compute = exists (Typ.prover_value ()) ~compute

let if_ b ~then_ ~else_ =
  create (fun () ->
      get (if Impl.As_prover.read Boolean.typ b then then_ else else_) )

let map t ~f = create (fun () -> f (get t))

let typ = Typ.prover_value
