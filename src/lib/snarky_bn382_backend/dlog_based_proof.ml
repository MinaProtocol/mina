open Core_kernel
open Rugelach_types

module Challenge_polynomial = struct
  type t = {challenges: Fq.t array; commitment: G.Affine.t} [@@deriving bin_io]
end

type message = Challenge_polynomial.t list

type t =
  ( G.Affine.t
  , Fq.t
  , (Fq.t, G.Affine.t) Dlog_marlin_types.Openings.t )
  Pairing_marlin_types.Proof.t
[@@deriving bin_io]

let g t f = G.Affine.of_backend (f t)

let fq t f =
  let t = f t in
  Caml.Gc.finalise Fq.delete t ;
  t

(* TODO: Lots of leakage here. *)
let of_backend (t : Snarky_bn382.Fq_proof.t) : t =
  let open Snarky_bn382.Fq_proof in
  let gpair (type a) (t : a) (f : a -> Snarky_bn382.G.Affine.Pair.t) :
      G.Affine.t * G.Affine.t =
    let t = f t in
    let g = G.Affine.of_backend in
    Snarky_bn382.G.Affine.Pair.(g (f0 t), g (f1 t))
  in
  let proof =
    let t = proof t in
    let fq = fq t in
    let g = g t in
    let open Snarky_bn382.Fq_opening_proof in
    let lr =
      let v = lr t in
      Array.init (Snarky_bn382.G.Affine.Pair.Vector.length v) (fun i ->
          gpair v (fun v -> Snarky_bn382.G.Affine.Pair.Vector.get v i) )
    in
    { Dlog_marlin_types.Openings.Bulletproof.lr
    ; z_1= fq z1
    ; z_2= fq z2
    ; delta= g delta
    ; sg= g sg }
  in
  let g = g t in
  let gpair = gpair t in
  let evals =
    let t = evals_nocopy t in
    Evaluations.Triple.(f0 t, f1 t, f2 t)
    |> Tuple_lib.Triple.map ~f:(fun e ->
           let open Evaluations in
           let abc trip =
             let t = trip e in
             let fq = fq t in
             let open Snarky_bn382.Fq_triple in
             {Abc.a= fq f0; b= fq f1; c= fq f2}
           in
           let fq = fq e in
           { Dlog_marlin_types.Evals.w_hat= fq w
           ; z_hat_a= fq za
           ; z_hat_b= fq zb
           ; h_1= fq h1
           ; h_2= fq h2
           ; h_3= fq h3
           ; row= abc row_nocopy
           ; col= abc col_nocopy
           ; value= abc val_nocopy
           ; rc= abc rc_nocopy
           ; g_1= fq g1
           ; g_2= fq g2
           ; g_3= fq g3 } )
  in
  let fq = fq t in
  { messages=
      { w_hat= g w_comm
      ; z_hat_a= g za_comm
      ; z_hat_b= g zb_comm
      ; gh_1= (gpair g1_comm_nocopy, g h1_comm)
      ; sigma_gh_2= (fq sigma2, (gpair g2_comm_nocopy, g h2_comm))
      ; sigma_gh_3= (fq sigma3, (gpair g3_comm_nocopy, g h3_comm)) }
  ; openings= {proof; evals} }

let eval_to_backend
    { Dlog_marlin_types.Evals.w_hat
    ; z_hat_a
    ; z_hat_b
    ; h_1
    ; h_2
    ; h_3
    ; row= {a= row_a; b= row_b; c= row_c}
    ; col= {a= col_a; b= col_b; c= col_c}
    ; value= {a= value_a; b= value_b; c= value_c}
    ; rc= {a= rc_a; b= rc_b; c= rc_c}
    ; g_1
    ; g_2
    ; g_3 } =
  Snarky_bn382.Fq_proof.Evaluations.make w_hat z_hat_a z_hat_b h_1 g_1 h_2 g_2
    h_3 g_3 row_a row_b row_c col_a col_b col_c value_a value_b value_c rc_a
    rc_b rc_c

let to_backend chal_polys primary_input
    ({ messages=
         { w_hat= w_comm
         ; z_hat_a= za_comm
         ; z_hat_b= zb_comm
         ; gh_1= (g1_comm_0, g1_comm_1), h1_comm
         ; sigma_gh_2= sigma2, ((g2_comm_0, g2_comm_1), h2_comm)
         ; sigma_gh_3= sigma3, ((g3_comm_0, g3_comm_1), h3_comm) }
     ; openings=
         {proof= {lr; z_1; z_2; delta; sg}; evals= evals0, evals1, evals2} } :
      t) : Snarky_bn382.Fq_proof.t =
  let primary_input =
    let v = Fq.Vector.create () in
    List.iter ~f:(Fq.Vector.emplace_back v) primary_input ;
    v
  in
  let g (a, b) =
    let open Snarky_bn382.G.Affine in
    let t = create a b in
    Caml.Gc.finalise delete t ; t
  in
  let lr =
    let v = Snarky_bn382.G.Affine.Pair.Vector.create () in
    Array.iter lr ~f:(fun (l, r) ->
        (* Very leaky *)
        Snarky_bn382.G.Affine.Pair.Vector.emplace_back v
          (Snarky_bn382.G.Affine.Pair.make (g l) (g r)) ) ;
    v
  in
  let challenges =
    List.map chal_polys ~f:(fun {Challenge_polynomial.challenges; _} ->
        challenges )
    |> Array.concat |> Fq.Vector.of_array
  in
  let commitments =
    Array.of_list_map chal_polys
      ~f:(fun {Challenge_polynomial.commitment; _} ->
        G.Affine.to_backend commitment )
    |> G.Affine.Vector.of_array
  in
  Snarky_bn382.Fq_proof.make primary_input (g w_comm) (g za_comm) (g zb_comm)
    (g h1_comm) (g g1_comm_0) (g g1_comm_1) (g h2_comm) (g g2_comm_0)
    (g g2_comm_1) (g h3_comm) (g g3_comm_0) (g g3_comm_1) sigma2 sigma3 lr z_1
    z_2 (g delta) (g sg)
    (* Leaky! *)
    (eval_to_backend evals0)
    (eval_to_backend evals1) (eval_to_backend evals2) challenges commitments

let create ?message pk ~primary ~auxiliary =
  let chal_polys = Option.value_exn message in
  let challenges =
    List.map chal_polys ~f:(fun {Challenge_polynomial.challenges; _} ->
        challenges )
    |> Array.concat |> Fq.Vector.of_array
  in
  let commitments =
    Array.of_list_map chal_polys
      ~f:(fun {Challenge_polynomial.commitment; _} ->
        G.Affine.to_backend commitment )
    |> G.Affine.Vector.of_array
  in
  let res =
    Snarky_bn382.Fq_proof.create pk primary auxiliary challenges commitments
  in
  let t = of_backend res in
  Snarky_bn382.Fq_proof.delete res ;
  t

let verify ?message:_ _ _ _ = true
