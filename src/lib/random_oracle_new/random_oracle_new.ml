[%%import
"/src/config.mlh"]

open Core_kernel

(* import field and configuration to create random_oracle *)

[%%ifdef
consensus_mechanism]

module Field = Pickles.Impls.Step.Internal_Basic.Field
module Inputs = Pickles.Tick_field_sponge.Inputs

[%%else]

module Field = Snark_params_nonconsensus.Field

module Inputs = struct
  module Field = Field

  let rounds_full = 63

  let rounds_partial = 0

  (* Computes x^5 *)
  let to_the_alpha x =
    let open Field in
    let squared = x * x in
    x * squared * squared

  module Operations = struct
    let add_assign ~state i x = Field.(state.(i) <- state.(i) + x)

    let apply_affine_map (matrix, constants) v =
      let dotv row =
        Array.reduce_exn (Array.map2_exn row v ~f:Field.( * )) ~f:Field.( + )
      in
      let res = Array.map matrix ~f:dotv in
      Array.map2_exn res constants ~f:Field.( + )

    let copy a = Array.map a ~f:Fn.id
  end
end

[%%endif]

(* create hash from random_oracle library *)

module Config = struct
  let params = Sponge.Params.(map pasta_p ~f:Field.of_string)
end

module Sponge_Hash = Random_oracle_to_extract.From_poseidong_config (Inputs)

module Hash_to_include :
  Random_oracle_to_extract.Intf.S
  with type field := Field.t
   and type field_constant := Field.t
   and type boolean := bool
   and module State := Random_oracle_to_extract.State =
  Random_oracle_to_extract.Make_hash (Field) (Config) (Sponge_Hash)

include Hash_to_include

(* add salt function (can panic) *)

let salt (s : string) =
  let prefix_to_field (s : string) =
    let bits_per_character = 8 in
    assert (bits_per_character * String.length s < Field.size_in_bits) ;
    Field.project Fold_lib.Fold.(to_list (string_bits (s :> string)))
  in
  update ~state:initial_state [|prefix_to_field s|]

(* tests *)

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

(* create checked hash *)

[%%ifdef
consensus_mechanism]

module Checked = struct
  module Permutation = Pickles.Step_main_inputs.Sponge.Permutation

  module Digest = struct
    open Pickles.Impls.Step.Field

    type nonrec t = t

    let to_bits ?(length = Field.size_in_bits) (x : t) =
      List.take
        (Pickles.Impls.Step.Field.choose_preimage_var
           ~length:Field.size_in_bits x)
        length
  end

  include Random_oracle_to_extract.From_permutation (Permutation)

  let params =
    let params : Field.t Sponge.Params.t =
      Sponge.Params.(map pasta_p ~f:Field.of_string)
    in
    Sponge.Params.map ~f:Permutation.Field.constant params

  open Permutation.Field

  let update ~state xs = update params ~state xs

  let hash ?init xs =
    O1trace.measure "Random_oracle.hash" (fun () ->
        hash
          ?init:
            (Option.map init
               ~f:(Random_oracle_to_extract.State.map ~f:constant))
          params xs )

  let pack_input =
    Random_oracle_to_extract.Input.pack_to_fields
      ~size_in_bits:Field.size_in_bits ~pack:Field.Var.pack
end

(* tests *)

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
