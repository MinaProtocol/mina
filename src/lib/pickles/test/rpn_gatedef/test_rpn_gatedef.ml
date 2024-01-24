(* open Core_kernel *)
(* open Kimchi_types *)
open Plonk_checks
open Pickles_types
(* open Pickles.Impls.Step *)

module Type1 = Plonk_checks.Make (Shifted_value.Type1) (Scalars.Tick)

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () =
  (* let env =
       let module Env_bool = struct
         include Boolean

         type t = Boolean.var
       end in
       let module Env_field = struct
         include Field

         type bool = Env_bool.t

         let if_ (b : bool) ~then_ ~else_ =
           match Impl.Field.to_constant (b :> t) with
           | Some x ->
               (* We have a constant, only compute the branch we care about. *)
               if Impl.Field.Constant.(equal one) x then then_ () else else_ ()
           | None ->
               if_ b ~then_:(then_ ()) ~else_:(else_ ())
       end in
       Plonk_checks.scalars_env
         (module Env_bool)
         (module Env_field)
         ~srs_length_log2:Common.Max_degree.wrap_log2 ~zk_rows:3
         ~endo:(Impl.Field.constant Endo.Wrap_inner_curve.base)
         ~mds:sponge_params.mds
         ~field_of_hex:(fun s ->
           Kimchi_pasta.Pasta.Bigint256.of_hex_string s
           |> Kimchi_pasta.Pasta.Fq.of_bigint |> Field.constant )
         ~domain plonk_minimal combined_evals
     in *)

  (* Type1.evaluate_rpn (module Kimchi_pasta.Vesta_based_plonk.Field) ~_rpn_gate:[||] *)
  (* Type1.evaluate_rpn (module Field) ~_rpn_gate:[||] *)
  (* Type1.evaluate_rpn (module Backend.Tick.Field) ~_rpn_gate:[||] *)
  let conditional_gate =
    Kimchi_types.
      [| Cell { col = Index ForeignFieldAdd; row = Curr }
       ; Cell { col = Witness 3; row = Curr }
       ; Dup
       ; Mul
       ; Cell { col = Witness 3; row = Curr }
       ; Sub
       ; Alpha
       ; Pow 1l
       ; Cell { col = Witness 0; row = Curr }
       ; Cell { col = Witness 3; row = Curr }
       ; Cell { col = Witness 1; row = Curr }
       ; Mul
       ; Literal (Pickles.Backend.Tick.Field.of_int 1)
       ; Cell { col = Witness 3; row = Curr }
       ; Sub
       ; Cell { col = Witness 2; row = Curr }
       ; Mul
       ; Add
       ; Sub
       ; Mul
       ; Add
       ; Mul
      |]
  in
  let _x =
    Type1.evaluate_rpn
      (module Pickles.Backend.Tick.Field)
      ~gate_rpn:conditional_gate
  in
  ()
