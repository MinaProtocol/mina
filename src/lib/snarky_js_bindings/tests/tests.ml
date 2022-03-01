module Backend = Kimchi_pasta.Vesta_based_plonk
module Impl = Pickles.Impls.Step
module Field = Impl.Field

(* function to check a circuit defined by a 'main' function *)
let keygen_prove_verify (main : ?w:'a -> 'b -> unit -> unit) spec ?priv pub =
  (* Core_kernel.printf "generating keypair...\n" ; *)
  let kp = Impl.generate_keypair ~exposing:spec (main ?w:None) in
  let pk = Impl.Keypair.pk kp in
  (* Core_kernel.printf "prove...\n" ; *)
  let proof =
    Impl.generate_witness_conv
      ~f:(fun { Impl.Proof_inputs.auxiliary_inputs; public_inputs } ->
        Backend.Proof.create pk ~auxiliary:auxiliary_inputs
          ~primary:public_inputs)
      spec (main ?w:priv) () pub
  in
  let vk = Impl.Keypair.vk kp in
  (* TODO: make work for larger arbitrary pub spec *)
  let pub_vec = Backend.Field.Vector.create () in
  Backend.Field.Vector.emplace_back pub_vec pub ;
  (* Core_kernel.printf "verify...\n" ; *)
  let ok = Backend.Proof.verify proof vk pub_vec in
  Core_kernel.printf (if ok then "ok\n" else "not ok\n") ;
  assert ok

let read_witness typ w =
  Impl.exists typ ~compute:(fun () -> Core_kernel.Option.value_exn w)

let to_unchecked (x : Field.t) =
  match x with Constant y -> y | y -> Impl.As_prover.read_var y

let poseidon_hash input =
  let digest =
    try Random_oracle.Checked.hash input
    with _ ->
      Random_oracle.hash (Core_kernel.Array.map ~f:to_unchecked input)
      |> Field.constant
  in
  (* debug hash value: *)
  (* let () =
       try
         let s = digest |> to_unchecked |> Field.Constant.to_string in
         Core_kernel.printf "got hash\n" ;
         Core_kernel.printf "%s\n" s ;
         ()
       with _ ->
         Impl.as_prover (fun () ->
             let s = digest |> to_unchecked |> Field.Constant.to_string in
             Core_kernel.printf "got hash (as_prover)\n" ;
             Core_kernel.printf "%s\n" s)
     in *)
  digest

let%test_unit "poseidon" =
  Core_kernel.printf "unit test poseidon\n" ;
  let preimage = Field.one in
  let hash = poseidon_hash [| preimage |] in

  let main ?w z () =
    let preimage = read_witness Field.typ w in
    Field.Assert.equal (poseidon_hash [| preimage |]) z
  in
  keygen_prove_verify main
    Impl.Data_spec.[ Field.typ ]
    (to_unchecked hash) ~priv:(to_unchecked preimage)

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
