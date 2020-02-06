open Pickles_types

let hash_pairing_me_only ~app_state t =
  Fp_sponge.digest Fp_sponge.params
    (Types.Pairing_based.Proof_state.Me_only.to_field_elements t
       ~g:(fun ((x, y) : Snarky_bn382_backend.G.Affine.t) -> [x; y])
       ~app_state)
  |> Digest.Constant.of_bits

let hash_dlog_me_only t =
  Fq_sponge.digest Fq_sponge.params
    (Types.Dlog_based.Proof_state.Me_only.to_field_elements t
       ~g1:(fun (g : Snarky_bn382_backend.G1.Affine.t) ->
         let x, y = g in
         [x; y] ))
  |> Digest.Constant.of_bits

open Core_kernel

let dlog_pcs_batch ~domain_h ~domain_k =
  let h = Domain.size domain_h in
  let k = Domain.size domain_k in
  Pcs_batch.create ~without_degree_bound:Nat.N20.n
    ~with_degree_bound:[h - 1; h - 1; k - 1]

let pairing_beta_1_pcs_batch =
  Pcs_batch.create ~without_degree_bound:Nat.N6.n ~with_degree_bound:[]

let pairing_beta_2_pcs_batch =
  Pcs_batch.create ~without_degree_bound:Nat.N2.n ~with_degree_bound:[]

let pairing_beta_3_pcs_batch =
  Pcs_batch.create ~without_degree_bound:Nat.N11.n ~with_degree_bound:[]

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
  let start = Time.now () in
  let x = f () in
  let stop = Time.now () in
  printf "%s: %s\n%!" lab (Time.Span.to_string_hum (Time.diff stop start)) ;
  x

let bits_random_oracle =
  let h = Digestif.blake2s 32 in
  fun ?(length = 256) s ->
    Digestif.digest_string h s |> Digestif.to_raw_string h |> String.to_list
    |> List.concat_map ~f:(fun c ->
           let c = Char.to_int c in
           List.init 8 ~f:(fun i -> (c lsr i) land 1 = 1) )
    |> fun a -> List.take a length

let bits_to_bytes bits =
  let byte_of_bits bs =
    List.foldi bs ~init:0 ~f:(fun i acc b ->
        if b then acc lor (1 lsl i) else acc )
    |> Char.of_int_exn
  in
  List.map (List.groupi bits ~break:(fun i _ _ -> i mod 8 = 0)) ~f:byte_of_bits
  |> String.of_char_list

let group_map m ~a ~b =
  let params = Group_map.Params.create m ~a ~b in
  stage (fun x -> Group_map.to_group m ~params x)
