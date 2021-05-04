[%%import
"/src/config.mlh"]

module Input = Random_oracle_input

(* include the right inupts based on consensus or not *)
[%%ifdef
consensus_mechanism]

module Field = Pickles.Impls.Step.Internal_Basic.Field
module Inputs = Pickles.Tick_field_sponge.Inputs

module Config = struct
  type boolean = bool

  module Field = Field

  let rounds_full = Inputs.rounds_full

  let rounds_partial = Inputs.rounds_partial

  (* Computes x^5 *)
  let to_the_alpha = Inputs.to_the_alpha

  module Operations = Inputs.Operations
end

[%%else]

open Core_kernel
module Field = Snark_params_nonconsensus.Field

module Inputs = struct
  module Field = Field

  let rounds_full = 63

  let rounds_partial = 0

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

module Config = struct
  type boolean = bool

  include Inputs
end

[%%endif]

(* make the random oracle based on inputs *)

include Random_oracle_to_extract.Make (Config)
