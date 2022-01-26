module Backend = Kimchi_pasta.Vesta_based_plonk
module Impl = Pickles.Impls.Step
module Field = Impl.Field

(* function to check a circuit defined by a 'main' function *)
let keygen_prove_verify (main : ?w:'a -> 'b -> unit -> unit) spec ?priv pub =
  let kp = Impl.generate_keypair ~exposing:spec (fun z -> main z) in
  let pk = Impl.Keypair.pk kp in
  let proof =
    Impl.generate_witness_conv
      ~f:(fun { Impl.Proof_inputs.auxiliary_inputs; public_inputs } ->
        Backend.Proof.create pk ~auxiliary:auxiliary_inputs
          ~primary:public_inputs)
      spec
      (match priv with None -> fun z -> main z | Some w -> main ~w)
      () pub
  in
  let vk = Impl.Keypair.vk kp in
  (* TODO: make work for larger arbitrary pub spec *)
  let pub_vec = Backend.Field.Vector.create () in
  Backend.Field.Vector.emplace_back pub_vec pub ;
  let ok = Backend.Proof.verify proof vk pub_vec in
  Core_kernel.printf (if ok then "ok\n" else "not ok\n") ;
  assert ok

let read_witness typ w =
  Impl.exists typ ~compute:(fun () -> Core_kernel.Option.value_exn w)

let to_value (x : Field.t) =
  match x with Constant y -> y | y -> Impl.As_prover.read_var y

let poseidon_hash xs =
  let hash =
    match List.map to_value xs with
    | exception _ ->
        let module Sponge = Pickles.Step_main_inputs.Sponge in
        let sponge_params = Pickles.Step_main_inputs.sponge_params in
        let s = Sponge.create sponge_params in
        for i = 0 to List.length xs - 1 do
          Sponge.absorb s (`Field (List.nth xs i))
        done ;
        Sponge.squeeze_field s
    | xs ->
        let module Field = Pickles.Tick_field_sponge.Field in
        let params = Pickles.Tick_field_sponge.params in
        let s = Field.create params in
        for i = 0 to List.length xs - 1 do
          Field.absorb s (List.nth xs i)
        done ;
        Impl.Field.constant (Field.squeeze s)
  in
  hash

let%test_unit "poseidon" =
  Core_kernel.printf "unit test poseidon\n" ;
  let preimage = Field.one in
  let hash = poseidon_hash [ preimage ] in

  let main ?w z () =
    let preimage = read_witness Field.typ w in
    Field.Assert.equal (poseidon_hash [ preimage ]) z
  in
  keygen_prove_verify main
    Impl.Data_spec.[ Field.typ ]
    (to_value hash) ~priv:(to_value preimage)

(* let%test_unit "simple" =
  (* Core_kernel.printf "unit test simple\n" ; *)
  let preimage = Field.one in
  let hash = Field.of_int 2 in

  let main ?w z () =
    let preimage = read_witness Field.typ w in
    Field.Assert.equal (Field.add preimage preimage) z
  in
  keygen_prove_verify main
    Impl.Data_spec.[ Field.typ ]
    (to_value hash) ~priv:(to_value preimage) *)

(* let%test_unit "sqrt" =
  Core_kernel.printf "unit test sqrt\n" ;

  let main ?w:_ z () =
    let x =
      Impl.exists Field.typ ~compute:(fun () ->
          Field.Constant.sqrt (Impl.As_prover.read_var z))
    in
    Field.Assert.equal (Field.mul x x) z
  in
  keygen_prove_verify main
    Impl.Data_spec.[ Field.typ ]
    (Field.Constant.of_int 4)

let%test_unit "sqrt witness" =
  Core_kernel.printf "unit test sqrt witness\n" ;

  let main ?w z () =
    let x = read_witness Field.typ w in
    Field.Assert.equal (Field.mul x x) z
  in
  keygen_prove_verify main
    Impl.Data_spec.[ Field.typ ]
    (Field.Constant.of_int 4) ~priv:(Field.Constant.of_int 2) *)
