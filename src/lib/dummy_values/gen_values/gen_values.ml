open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core
open Async

module Curve_name = struct
  type t = Tick | Tock

  let to_string = function Tick -> "Tick" | Tock -> "Tock"
end

module Proof_system_name = struct
  type t = Groth16 | Bowe_gabizon18

  let to_string = function
    | Groth16 ->
        "Groth16"
    | Bowe_gabizon18 ->
        "Bowe_gabizon18"
end

module Make
    (B : Snarky.Backend_intf.S) (M : sig
        val curve : Curve_name.t

        val proof_system : Proof_system_name.t
    end) =
struct
  open M
  module Impl = Snarky.Snark.Make (B)

  let proof_string =
    let open Impl in
    let exposing = Data_spec.[Typ.field] in
    let main x =
      let%bind _z = Field.Checked.mul x x in
      Field.Checked.Assert.equal x x
    in
    let keypair = generate_keypair main ~exposing in
    let proof = prove (Keypair.pk keypair) exposing () main Field.one in
    assert (verify proof (Keypair.vk keypair) exposing Field.one) ;
    Binable.to_string (module Proof) proof

  let vk_string, pk_string =
    let open Impl in
    let kp =
      match M.curve with
      | Tick ->
          generate_keypair
            ~exposing:Data_spec.[Boolean.typ]
            (fun b -> Boolean.Assert.is_true b)
      | Tock -> (
          (* Hack *)
          let n =
            Crypto_params.Tock0.Data_spec.(size [Crypto_params.Wrap_input.typ])
          in
          match n with
          | 1 ->
              generate_keypair
                ~exposing:Data_spec.[Boolean.typ]
                (fun b1 -> Boolean.Assert.is_true b1)
          | 2 ->
              generate_keypair
                ~exposing:Data_spec.[Boolean.typ; Boolean.typ]
                (fun b1 _b2 -> Boolean.Assert.is_true b1)
          | _ ->
              assert false )
    in
    ( Verification_key.to_string (Keypair.vk kp)
    , Proving_key.to_string (Keypair.pk kp) )

  let structure ~loc =
    let ident str = Loc.make ~loc (Longident.parse str) in
    let ( ^. ) x y = x ^ "." ^ y in
    let module E = Ppxlib.Ast_builder.Make (struct
      let loc = loc
    end) in
    let open E in
    let curve_name = Curve_name.to_string curve in
    let curve_module_name =
      match proof_system with
      | Bowe_gabizon18 ->
          sprintf "Crypto_params.%s_backend" curve_name
      | Groth16 ->
          sprintf "Crypto_params.%s_backend.Full.Default" curve_name
    in
    let of_string_expr submodule_name str =
      [%expr
        [%e
          pexp_ident
            (ident (curve_module_name ^. submodule_name ^. "of_string"))]
          [%e estring str]]
    in
    let proof_stri =
      [%stri
        let proof =
          Core_kernel.Binable.of_string
            [%e pexp_pack (pmod_ident (ident (curve_module_name ^. "Proof")))]
            [%e estring proof_string]]
    in
    let vk_stri =
      [%stri
        let verification_key = [%e of_string_expr "Verification_key" vk_string]]
    in
    let pk_stri =
      [%stri let proving_key = [%e of_string_expr "Proving_key" pk_string]]
    in
    pstr_module
      (module_binding
         ~name:(Loc.make ~loc (Proof_system_name.to_string proof_system))
         ~expr:(pmod_structure [proof_stri; vk_stri; pk_stri]))
end

type spec = Curve_name.t * Proof_system_name.t

let proof_system_of_curve : Curve_name.t -> Proof_system_name.t = function
  | Tick ->
      Groth16
  | Tock ->
      Bowe_gabizon18

let backend_of_curve (s : Curve_name.t) =
  match s with
  | Tick ->
      assert (proof_system_of_curve Tick = Groth16) ;
      (module Crypto_params.Tick_backend : Snarky.Backend_intf.S)
  | Tock ->
      assert (proof_system_of_curve Tock = Bowe_gabizon18) ;
      (module Crypto_params.Tock_backend : Snarky.Backend_intf.S)

let structure_item_of_spec ((curve, proof_system) : spec) =
  let module N = struct
    let curve = curve

    let proof_system = proof_system
  end in
  let module B = (val backend_of_curve curve) in
  let module M = Make (B) (N) in
  M.structure ~loc:Ppxlib.Location.none

let curves = [Curve_name.Tick; Curve_name.Tock]

let main () =
  let fmt =
    Format.formatter_of_out_channel (Out_channel.create "dummy_values.ml")
  in
  let structure =
    let loc = Ppxlib.Location.none in
    List.map curves ~f:(fun curve ->
        let module E = Ppxlib.Ast_builder.Make (struct
          let loc = loc
        end) in
        let open E in
        pstr_module
          (module_binding
             ~name:(Loc.make ~loc (Curve_name.to_string curve))
             ~expr:
               (pmod_structure
                  [structure_item_of_spec (curve, proof_system_of_curve curve)]))
    )
  in
  Pprintast.top_phrase fmt (Ptop_def structure) ;
  exit 0

let () =
  ignore (main ()) ;
  never_returns (Scheduler.go ())
