

(* open Snarkette

module Backend = Sonic_prototype.Default_backend.Backend

module Inputs (Impl : Snarky.Snark_intf.Run) : Inputs.S_run = struct
  implements run

  module G1 = struct
    module Unchecked = Backend.G1

    let add_exn a b =

    
  end
end *)

module Make (Inputs : Inputs.S_run) = struct
  open Inputs
  open Impl

  module Verification_key = struct
    type ('g1, 'g2) t_ =
      { g: 'g1
      ; h: 'g2
      ; h_alpha: 'g2
      ; h_alpha_x: 'g2 }
    
    type ('a, 'b) vk = ('a, 'b) t_

    module Precomputation = struct
      type t = { g: G1_precomputation.t
               ; h: G2_precomputation.t
               ; h_alpha: G2_precomputation.t
               ; h_alpha_x: G2_precomputation.t }

      let create (vk : (_, _) vk) =
        let g = G1_precomputation.create vk.g in
        let h = G2_precomputation.create vk.h in
        let h_alpha = G2_precomputation.create vk.h_alpha in
        let h_alpha_x = G2_precomputation.create vk.h_alpha_x in
        {g; h; h_alpha; h_alpha_x}
    end
  end
  
  let pc_v (vk : _ Verification_key.t_)
      (vk_precomp : Verification_key.Precomputation.t) commitment z (v, w) : Boolean.var =
    final_exponentiation
      (batch_miller_loop
        [ (Pos, G1_precomputation.create w, vk_precomp.h_alpha_x)
        ; ( Pos
          , G1_precomputation.create (G1.add_exn
              (G1.scale vk.g Field.(unpack_full (sub v one)) ~init:vk.g)
              (G1.scale w Field.(unpack_full (sub (sub zero z) one)) ~init:w))
          , vk_precomp.h_alpha)
        ; (Neg, G1_precomputation.create commitment, vk_precomp.h) ])
    |> Fqk.(equal one)
end


(* 
let%test_unit "checked-unchecked equivalence" =
(* let open Quickcheck in
test ~trials:20 (Generator.tuple2 gen User_command_payload.gen)
  ~f:(fun (base, payload) -> *)
    let unchecked = cons payload base in
    let checked =
      let comp =
        let open Snark_params.Tick.Checked.Let_syntax in
        let%bind payload =
          Schnorr.Message.var_of_payload
            Transaction_union_payload.(
              Checked.constant (of_user_command_payload payload))
        in
        let%map res = Checked.cons ~payload (var_of_t base) in
        As_prover.read typ res
      in
      let (), x = Or_error.ok_exn (run_and_check comp ()) in
      x
    in
    assert (equal unchecked checked)
 *)

