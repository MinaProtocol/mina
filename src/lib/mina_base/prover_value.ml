open Snark_params.Step.Run

type 'a t = 'a As_prover.Ref.t

let get = As_prover.Ref.get

let create = As_prover.Ref.create

let if_ b ~then_ ~else_ =
  create (fun () ->
      get (if Impl.As_prover.read Boolean.typ b then then_ else else_) )

let map t ~f = create (fun () -> f (get t))

let typ = Typ.Internal.ref
