open Pickles_types

type t =
  ( G1.Affine.t
  , Fp.t
  , (G1.Affine.t, Fp.t) Pairing_marlin_types.Openings.Wire.t )
  Pairing_marlin_types.Proof.t
[@@deriving bin_io]

let of_backend t : t =
  let g1 f =
    let aff = f t in
    let res = G1.Affine.of_backend aff in
    Snarky_bn382.G1.Affine.delete aff ;
    res
  in
  let fp' x =
    Caml.Gc.finalise Snarky_bn382.Fp.delete x ;
    x
  in
  let fp f =
    let res = f t in
    Caml.Gc.finalise Snarky_bn382.Fp.delete res ;
    res
  in
  let open Snarky_bn382.Fp_proof in
  let row_evals = row_evals_nocopy t in
  let col_evals = col_evals_nocopy t in
  let val_evals = val_evals_nocopy t in
  let open Evals in
  { messages=
      { w_hat= g1 w_comm
      ; s= failwith "remove s"
      ; z_hat_a= g1 za_comm
      ; z_hat_b= g1 zb_comm
      ; gh_1= (failwith "implement degree bounds", g1 h1_comm)
      ; sigma_gh_2=
          (fp sigma2, (failwith "implement degree bounds", g1 h2_comm))
      ; sigma_gh_3=
          (fp sigma3, (failwith "implement degree bounds", g1 h3_comm)) }
  ; openings=
      { beta_1=
          { proof= g1 proof1
          ; values=
              (* TODO: Rearrange the order *)
              Vector.map ~f:fp
                [ g1_eval
                ; h1_eval
                ; za_eval
                ; zb_eval
                ; w_eval
                ; failwith "remove s" ] }
      ; beta_2= {proof= g1 proof2; values= Vector.map ~f:fp [g2_eval; h2_eval]}
      ; beta_3=
          { proof= g1 proof3
          ; values=
              [ fp g3_eval
              ; fp h3_eval
              ; fp' (f0 row_evals)
              ; fp' (f1 row_evals)
              ; fp' (f2 row_evals)
              ; fp' (f0 col_evals)
              ; fp' (f1 col_evals)
              ; fp' (f2 col_evals)
              ; fp' (f0 val_evals)
              ; fp' (f1 val_evals)
              ; fp' (f2 val_evals) ] } } }

type message = unit

let create ?message:_ pk ~primary ~auxiliary =
  let res = Snarky_bn382.Fp_proof.create pk primary auxiliary in
  let t = of_backend res in
  Snarky_bn382.Fp_proof.delete res ;
  t

let verify ?message:_ _ _ _ = true
