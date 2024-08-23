open Core_kernel
open Pickles.Impls.Step.Internal_Basic

module State = struct
  include Array

  let map2 = map2_exn

  let to_array t = t

  let of_array t = t
end

module Input = Random_oracle_input

let params : Field.t Sponge.Params.t = Kimchi_pasta_basic.poseidon_params_fp

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

module Digest = struct
  type t = Field.t

  let to_bits ?length x =
    match length with
    | None ->
        Field.unpack x
    | Some length ->
        List.take (Field.unpack x) length
end

include Sponge.Make_hash (Random_oracle_permutation)

let update ~state = update ~state params

let hash ?init = hash ?init params

let pow2 =
  let rec pow2 acc n = if n = 0 then acc else pow2 Field.(acc + acc) (n - 1) in
  Memo.general ~hashable:Int.hashable (fun n -> pow2 Field.one n)

module Checked = struct
  module Inputs = Pickles.Step_main_inputs.Sponge.Permutation

  module Digest = struct
    open Pickles.Impls.Step.Field

    type nonrec t = t

    let to_bits ?(length = Field.size_in_bits) (x : t) =
      List.take (choose_preimage_var ~length:Field.size_in_bits x) length
  end

  include Sponge.Make_hash (Inputs)

  let params = Sponge.Params.map ~f:Inputs.Field.constant params

  open Inputs.Field

  let update ~state xs = update params ~state xs

  let hash ?init xs =
    hash ?init:(Option.map init ~f:(State.map ~f:constant)) params xs

  let pack_input =
    Input.Chunked.pack_to_fields
      ~pow2:(Fn.compose Field.Var.constant pow2)
      (module Pickles.Impls.Step.Field)

  let digest xs = xs.(0)
end

let read_typ ({ field_elements; packeds } : _ Input.Chunked.t) =
  let open Pickles.Impls.Step in
  let open As_prover in
  { Input.Chunked.field_elements = Array.map ~f:(read Field.typ) field_elements
  ; packeds = Array.map packeds ~f:(fun (x, i) -> (read Field.typ x, i))
  }

let read_typ' input : _ Pickles.Impls.Step.Internal_Basic.As_prover.t =
 fun _ -> read_typ input

let pack_input = Input.Chunked.pack_to_fields ~pow2 (module Field)

let prefix_to_field (s : string) =
  let bits_per_character = 8 in
  assert (bits_per_character * String.length s < Field.size_in_bits) ;
  Field.project Fold_lib.Fold.(to_list (string_bits (s :> string)))

let salt (s : string) = update ~state:initial_state [| prefix_to_field s |]

let%test_unit "iterativeness" =
  let x1 = Field.random () in
  let x2 = Field.random () in
  let x3 = Field.random () in
  let x4 = Field.random () in
  let s_full = update ~state:initial_state [| x1; x2; x3; x4 |] in
  let s_it =
    update ~state:(update ~state:initial_state [| x1; x2 |]) [| x3; x4 |]
  in
  [%test_eq: Field.t array] s_full s_it

let%test_unit "sponge checked-unchecked" =
  let open Pickles.Impls.Step in
  let module T = Internal_Basic in
  let x = T.Field.random () in
  let y = T.Field.random () in
  T.Test.test_equal ~equal:T.Field.equal ~sexp_of_t:T.Field.sexp_of_t
    T.Typ.(field * field)
    T.Typ.field
    (fun (x, y) -> make_checked (fun () -> Checked.hash [| x; y |]))
    (fun (x, y) -> hash [| x; y |])
    (x, y)

module Legacy = struct
  module Input = Random_oracle_input.Legacy
  module State = State

  let params : Field.t Sponge.Params.t =
    Sponge.Params.(map pasta_p_legacy ~f:Kimchi_pasta_basic.Fp.of_string)

  module Rounds = struct
    let rounds_full = 63

    let initial_ark = true

    let rounds_partial = 0
  end

  module Inputs = struct
    module Field = Field
    include Rounds

    let alpha = 5

    (* Computes x^5 *)
    let to_the_alpha x =
      let open Field in
      let res = x in
      let res = res * res in
      (* x^2 *)
      let res = res * res in
      (* x^4 *)
      res * x

    module Operations = Operations
  end

  include Sponge.Make_hash (Sponge.Poseidon (Inputs))

  let hash ?init = hash ?init params

  let update ~state = update ~state params

  let salt (s : string) = update ~state:initial_state [| prefix_to_field s |]

  let pack_input =
    Input.pack_to_fields ~size_in_bits:Field.size_in_bits ~pack:Field.project

  module Digest = Digest

  module Checked = struct
    let pack_input =
      Input.pack_to_fields ~size_in_bits:Field.size_in_bits ~pack:Field.Var.pack

    module Digest = Checked.Digest

    module Inputs = struct
      include Rounds
      module Impl = Pickles.Impls.Step
      open Impl
      module Field = Field

      let alpha = 5

      (* Computes x^5 *)
      let to_the_alpha x =
        let open Field in
        let res = x in
        let res = res * res in
        (* x^2 *)
        let res = res * res in
        (* x^4 *)
        res * x

      module Operations = struct
        open Field

        let seal = Pickles.Util.seal (module Impl)

        let add_assign ~state i x = state.(i) <- seal (state.(i) + x)

        let apply_affine_map (matrix, constants) v =
          let dotv row =
            Array.reduce_exn (Array.map2_exn row v ~f:( * )) ~f:( + )
          in
          let res = Array.map matrix ~f:dotv in
          Array.map2_exn res constants ~f:(fun x c -> seal (x + c))

        let copy a = Array.map a ~f:Fn.id
      end
    end

    include Sponge.Make_hash (Sponge.Poseidon (Inputs))

    let params = Sponge.Params.map ~f:Inputs.Field.constant params

    open Inputs.Field

    let update ~state xs = update params ~state xs

    let hash ?init xs =
      hash ?init:(Option.map init ~f:(State.map ~f:constant)) params xs
  end
end
