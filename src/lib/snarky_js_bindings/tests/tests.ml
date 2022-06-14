module Backend = Kimchi_pasta.Vesta_based_plonk
module Impl = Pickles.Impls.Step
module Field = Impl.Field

(* function to check a circuit defined by a 'main' function *)
let keygen_prove_verify (main : ?w:'a -> 'b -> unit -> unit) spec ?priv pub =
  let kp =
    Impl.constraint_system ~exposing:spec
      ~return_typ:(Snarky_backendless.Typ.unit ())
      (main ?w:None)
    |> Impl.Keypair.generate
  in
  let pk = Impl.Keypair.pk kp in
  let proof =
    Impl.generate_witness_conv
      ~f:(fun { Impl.Proof_inputs.auxiliary_inputs; public_inputs } _ ->
        Backend.Proof.create pk ~auxiliary:auxiliary_inputs
          ~primary:public_inputs )
      spec
      ~return_typ:(Snarky_backendless.Typ.unit ())
      (main ?w:priv) pub
  in
  let vk = Impl.Keypair.vk kp in
  (* TODO: make work for larger arbitrary pub spec *)
  let pub_vec = Backend.Field.Vector.create () in
  Backend.Field.Vector.emplace_back pub_vec pub ;
  let ok = Backend.Proof.verify proof vk pub_vec in
  assert ok

let read_witness typ w =
  Impl.exists typ ~compute:(fun () -> Core_kernel.Option.value_exn w)

let to_unchecked (x : Field.t) =
  match x with Constant y -> y | y -> Impl.As_prover.read_var y

let poseidon_hash input =
  try Random_oracle.Checked.hash input
  with _ ->
    Random_oracle.hash (Core_kernel.Array.map ~f:to_unchecked input)
    |> Field.constant

let%test_unit "poseidon" =
  let preimage = Field.one in
  let hash = poseidon_hash [| preimage |] in

  let main ?w z () =
    let preimage = read_witness Field.typ w in
    Field.Assert.equal (poseidon_hash [| preimage |]) z
  in
  keygen_prove_verify main
    Impl.Data_spec.[ Field.typ ]
    (to_unchecked hash) ~priv:(to_unchecked preimage)

let%test_unit "sqrt" =
  let main ?w z () =
    let x = read_witness Field.typ w in
    Field.Assert.equal (Field.mul x x) z
  in
  keygen_prove_verify main
    Impl.Data_spec.[ Field.typ ]
    (Field.Constant.of_int 4) ~priv:(Field.Constant.of_int 2)
