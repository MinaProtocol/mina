open Pickles_types

let bulletproof_log2 = 15

let dlog_pcs_batch ~domain_h ~domain_k =
  let h = Domain.size domain_h in
  let k = Domain.size domain_k in
  Pcs_batch.create ~without_degree_bound:Nat.N17.n
    ~with_degree_bound:[h - 1; h - 1; k - 1]

let pairing_beta_1_pcs_batch =
  Pcs_batch.create ~without_degree_bound:Nat.N6.n ~with_degree_bound:[]

let pairing_beta_2_pcs_batch =
  Pcs_batch.create ~without_degree_bound:Nat.N2.n ~with_degree_bound:[]

let pairing_beta_3_pcs_batch =
  Pcs_batch.create ~without_degree_bound:Nat.N11.n ~with_degree_bound:[]

let hash_pairing_me_only t =
  Fp_sponge.digest Fp_sponge.params
    (Types.Pairing_based.Proof_state.Me_only.to_field_elements t
       ~g:(fun g ->
         let x, y = Snarky_bn382_backend.G.to_affine_exn g in
         [x; y] )
       ~app_state:(fun x -> [|x|]))
  |> Digest.Constant.of_bits

let hash_dlog_me_only t =
  Fq_sponge.digest Fq_sponge.params
    (Types.Dlog_based.Proof_state.Me_only.to_field_elements t ~g1:(fun g ->
         let x, y = g in
         [x; y] ))
  |> Digest.Constant.of_bits

let split_last xs =
  let rec go acc = function
    | [x] ->
        (List.rev acc, x)
    | x :: xs ->
        go (x :: acc) xs
    | [] ->
        failwith "Empty list"
  in
  go [] xs

let time lab f =
  let open Core_kernel in
  let start = Time.now () in
  let x = f () in
  let stop = Time.now () in
  Core.printf "%s: %s\n%!" lab (Time.Span.to_string_hum (Time.diff stop start)) ;
  x
