open Snark_params
open Tick

type 'a t = Field.Var.t * 'a As_prover.Ref.t

let hash (x, _) = x

let ref (_, x) = x

let typ ~hash =
  Typ.transport
    Typ.(Field.typ * Internal.ref ())
    ~there:(fun s -> (hash s, s))
    ~back:(fun (_, s) -> s)

let optional_typ ~hash ~non_preimage ~dummy_value =
  Typ.transport
    Typ.(Field.typ * Internal.ref ())
    ~there:(function
      | None -> (non_preimage, dummy_value) | Some s -> (hash s, s) )
    ~back:(fun (_, s) -> Some s)

let to_input (x, _) = Random_oracle_input.Chunked.field x

let if_ b ~then_ ~else_ =
  let open Run in
  let hash = Field.if_ b ~then_:(fst then_) ~else_:(fst else_) in
  let ref =
    As_prover.Ref.create
      As_prover.(
        fun () ->
          let ref = if read Boolean.typ b then snd then_ else snd else_ in
          As_prover.Ref.get ref)
  in
  (hash, ref)

let make_unsafe hash ref : 'a t = (hash, ref)
