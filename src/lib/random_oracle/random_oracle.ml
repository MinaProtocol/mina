[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Pickles.Impls.Step.Internal_Basic

[%%else]

open Snark_params_nonconsensus

[%%endif]

module State = struct
  include Array

  let map2 = map2_exn
end

module Input = Input

let params : Field.t Sponge.Params.t =
  Sponge.Params.(map tweedle_q ~f:Field.of_string)

(* TODO: Unify with Bn382_inputs in the sponge lib *)
module Inputs = struct
  module Field = Field

  let rounds_full = 8

  let rounds_partial = 30

  [%%ifdef
  consensus_mechanism]

  (* Computes x^17 *)
  let to_the_alpha x =
    let open Field in
    let res = square x in
    let open Pickles.Backend.Tick.Field in
    Mutable.square res ;
    (* x^4 *)
    Mutable.square res ;
    (* x^8 *)
    Mutable.square res ;
    (* x^16 *)
    res *= x ;
    res

  [%%else]

  (* Computes x^17 *)
  let to_the_alpha x =
    let open Field in
    let res = x in
    let res = res * res in
    (* x^2 *)
    let res = res * res in
    (* x^4 *)
    let res = res * res in
    (* x^8 *)
    let res = res * res in
    (* x^16 *)
    res * x

  [%%endif]

  module Operations = struct
    [%%ifdef
    consensus_mechanism]

    let add_assign ~state i x = Field.(state.(i) += x)

    let apply_affine_map (_rows, c) v =
      let open Field in
      let res = [|v.(0) + v.(2); v.(0) + v.(1); v.(1) + v.(2)|] in
      Array.iteri res ~f:(fun i ri -> ri += c.(i)) ;
      res

    (* TODO: Have an explicit function for making a copy of a field element. *)
    let copy a = Array.map a ~f:(fun x -> Field.(x + zero))

    [%%else]

    let add_assign ~state i x = Field.(state.(i) <- state.(i) + x)

    (* TODO: Clean this up to use the near mds matrix properly *)
    let apply_affine_map (_matrix, constants) v =
      let open Field in
      let near_mds_matrix_v =
        [|v.(0) + v.(2); v.(0) + v.(1); v.(1) + v.(2)|]
      in
      Array.mapi near_mds_matrix_v ~f:(fun i x -> constants.(i) + x)

    let copy a = Array.map a ~f:Fn.id

    [%%endif]
  end
end

module Digest = struct
  open Field

  type nonrec t = t

  let to_bits ?length x =
    match length with
    | None ->
        unpack x
    | Some length ->
        List.take (unpack x) length
end

include Sponge.Make_hash (Sponge.Poseidon (Inputs))

let update ~state = update ~state params

let hash ?init = hash ?init params

[%%ifdef
consensus_mechanism]

module Checked = struct
  module Inputs = Pickles.Sponge_inputs.Make (Pickles.Impls.Step)

  module Digest = struct
    open Pickles.Impls.Step.Field

    type nonrec t = t

    let to_bits ?(length = Field.size_in_bits) (x : t) =
      List.take (choose_preimage_var ~length:Field.size_in_bits x) length
  end

  include Sponge.Make_hash (Sponge.Poseidon (Inputs))

  let params = Sponge.Params.map ~f:Inputs.Field.constant params

  open Inputs.Field

  let update ~state xs = update params ~state xs

  let hash ?init xs =
    O1trace.measure "Random_oracle.hash" (fun () ->
        hash ?init:(Option.map init ~f:(State.map ~f:constant)) params xs )

  let pack_input =
    Input.pack_to_fields ~size_in_bits:Field.size_in_bits ~pack:Field.Var.pack

  let digest xs = xs.(0)
end

[%%endif]

let pack_input =
  Input.pack_to_fields ~size_in_bits:Field.size_in_bits ~pack:Field.project

let prefix_to_field (s : string) =
  let bits_per_character = 8 in
  assert (bits_per_character * String.length s < Field.size_in_bits) ;
  Field.project Fold_lib.Fold.(to_list (string_bits (s :> string)))

let salt (s : string) = update ~state:initial_state [|prefix_to_field s|]

let%test_unit "iterativeness" =
  let x1 = Field.random () in
  let x2 = Field.random () in
  let x3 = Field.random () in
  let x4 = Field.random () in
  let s_full = update ~state:initial_state [|x1; x2; x3; x4|] in
  let s_it =
    update ~state:(update ~state:initial_state [|x1; x2|]) [|x3; x4|]
  in
  [%test_eq: Field.t array] s_full s_it

[%%ifdef
consensus_mechanism]

let%test_unit "sponge checked-unchecked" =
  let open Pickles.Impls.Step in
  let module T = Internal_Basic in
  let x = T.Field.random () in
  let y = T.Field.random () in
  T.Test.test_equal ~equal:T.Field.equal ~sexp_of_t:T.Field.sexp_of_t
    T.Typ.(field * field)
    T.Typ.field
    (fun (x, y) -> make_checked (fun () -> Checked.hash [|x; y|]))
    (fun (x, y) -> hash [|x; y|])
    (x, y)

[%%endif]
