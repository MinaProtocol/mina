[%%import "/src/config.mlh"]

open Core_kernel

[%%ifdef consensus_mechanism]

open Pickles.Impls.Step.Internal_Basic

[%%else]

open Snark_params.Tick

[%%endif]

module State = struct
  include Array

  let map2 = map2_exn
end

module Input = Random_oracle_input

let params : Field.t Sponge.Params.t =
  Sponge.Params.(map pasta_p_kimchi ~f:Field.of_string)

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

[%%ifdef consensus_mechanism]

module Inputs = Pickles.Tick_field_sponge.Inputs

[%%else]

module Inputs = struct
  module Field = Field

  let rounds_full = 55

  let initial_ark = false

  let rounds_partial = 0

  (* Computes x^7 *)
  let to_the_alpha x =
    let open Field in
    square (square x * x) * x

  module Operations = Operations
end

[%%endif]

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

module Ocaml_permutation = Sponge.Poseidon (Inputs)

[%%ifdef consensus_mechanism]

module Permutation : Sponge.Intf.Permutation with module Field = Field = struct
  module Field = Field

  let add_assign = Ocaml_permutation.add_assign

  let copy = Ocaml_permutation.copy

  let params = Kimchi_pasta_fp_poseidon.create ()

  let block_cipher _params (s : Field.t array) =
    let v = Kimchi.FieldVectors.Fp.create () in
    Array.iter s ~f:(Kimchi.FieldVectors.Fp.emplace_back v) ;
    Kimchi_pasta_fp_poseidon.block_cipher params v ;
    Array.init (Array.length s) ~f:(Kimchi.FieldVectors.Fp.get v)
end

[%%else]

module Permutation = Ocaml_permutation

[%%endif]

include Sponge.Make_hash (Permutation)

let update ~state = update ~state params

let hash ?init = hash ?init params

let pow2 =
  let rec pow2 acc n = if n = 0 then acc else pow2 Field.(acc + acc) (n - 1) in
  Memo.general ~hashable:Int.hashable (fun n -> pow2 Field.one n)

[%%ifdef consensus_mechanism]

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
    O1trace.measure "Random_oracle.hash" (fun () ->
        hash ?init:(Option.map init ~f:(State.map ~f:constant)) params xs)

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
 fun _ x -> (x, read_typ input)

[%%endif]

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

[%%ifdef consensus_mechanism]

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

let%test_unit "check rust implementation of block-cipher" =
  let open Pickles.Impls.Step in
  let module T = Internal_Basic in
  Quickcheck.test (Quickcheck.Generator.list_with_length 3 T.Field.gen)
    ~f:(fun s ->
      let s () = Array.of_list s in
      [%test_eq: T.Field.t array]
        (Ocaml_permutation.block_cipher params (s ()))
        (Permutation.block_cipher params (s ())))

[%%endif]

module Legacy = struct
  module Input = Random_oracle_input.Legacy

  let params : Field.t Sponge.Params.t =
    Sponge.Params.(map pasta_p_legacy ~f:Field.of_string)

  module Rounds = struct
    let rounds_full = 63

    let initial_ark = true

    let rounds_partial = 0
  end

  module Inputs = struct
    module Field = Field
    include Rounds

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

  [%%ifdef consensus_mechanism]

  module Checked = struct
    let pack_input =
      Input.pack_to_fields ~size_in_bits:Field.size_in_bits ~pack:Field.Var.pack

    module Digest = Checked.Digest

    module Inputs = struct
      include Rounds
      module Impl = Pickles.Impls.Step
      open Impl
      module Field = Field

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

  [%%endif]
end
