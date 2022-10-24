open Core_kernel
open Snark_params
open Signature_lib

module Scalar = struct
  include Step.Inner_curve.Scalar

  type value = t
end

module Group = struct
  type value = Step.Inner_curve.t

  type var = Step.Inner_curve.var

  let scale = Step.Inner_curve.scale

  module Checked = struct
    include Step.Inner_curve.Checked

    let scale_generator shifted s ~init =
      scale_known shifted Step.Inner_curve.one s ~init
  end
end

module Message = struct
  type 'state_hash t = { state_hash : 'state_hash } [@@deriving hlist]

  type value = Mina_base.State_hash.t t

  type var = Mina_base.State_hash.var t

  let typ =
    Step.Typ.of_hlistable
      [ Mina_base.State_hash.typ ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  let gen =
    let open Quickcheck.Let_syntax in
    let%map state_hash = Mina_base.State_hash.gen in
    { state_hash }

  let hash_to_group ~constraint_constants:_ msg =
    Group_map.to_group
      (Random_oracle.hash ~init:Mina_base.Hash_prefix.vrf_message
         [| msg.state_hash |] )
    |> Step.Inner_curve.of_affine

  module Checked = struct
    let hash_to_group msg =
      Step.make_checked (fun () ->
          Group_map.Checked.to_group
            (Random_oracle.Checked.hash ~init:Mina_base.Hash_prefix.vrf_message
               (Random_oracle.Checked.pack_input
                  (Mina_base.State_hash.var_to_input msg.state_hash) ) ) )
  end
end

module Output_hash = struct
  type value = Snark_params.Step.Field.t [@@deriving equal, sexp]

  type t = value [@@deriving equal, sexp]

  type var = Random_oracle.Checked.Digest.t

  let typ : (var, value) Snark_params.Step.Typ.t = Snark_params.Step.Field.typ

  let hash ~constraint_constants:_ ({ Message.state_hash } : Message.value) g =
    let x, y = Snark_params.Step.Inner_curve.to_affine_exn g in
    Random_oracle.hash [| (state_hash :> Snark_params.Step.Field.t); x; y |]

  module Checked = struct
    let hash ({ state_hash } : Message.var) g =
      Snark_params.Step.make_checked (fun () ->
          let x, y = g in
          Random_oracle.Checked.hash
            [| Mina_base.State_hash.var_to_hash_packed state_hash; x; y |] )
  end
end

module Vrf =
  Vrf_lib.Integrated.Make (Step) (Scalar) (Group) (Message) (Output_hash)

let%test_unit "eval unchecked vs. checked equality" =
  let constraint_constants =
    Genesis_constants.Constraint_constants.for_unit_tests
  in
  let gen =
    let open Quickcheck.Let_syntax in
    let%map pk = Private_key.gen and msg = Message.gen in
    (pk, msg)
  in
  Quickcheck.test ~trials:10 gen
    ~f:
      (Step.Test.test_equal ~sexp_of_t:[%sexp_of: Output_hash.value]
         ~equal:Output_hash.equal_value
         Step.Typ.(Scalar.typ * Message.typ)
         Output_hash.typ
         (fun (private_key, msg) ->
           let open Step.Checked in
           let%bind (module Shifted) = Group.Checked.Shifted.create () in
           Vrf.Checked.eval (module Shifted) ~private_key msg )
         (fun (private_key, msg) ->
           Vrf.eval ~constraint_constants ~private_key msg ) )

let%bench_module "vrf bench module" =
  ( module struct
    let constraint_constants =
      Genesis_constants.Constraint_constants.for_unit_tests

    let gen =
      let open Quickcheck.Let_syntax in
      let%map pk = Private_key.gen and msg = Message.gen in
      (pk, msg)

    let%bench_fun "vrf eval unchecked" =
      let private_key, msg = Quickcheck.random_value gen in
      fun () -> Vrf.eval ~constraint_constants ~private_key msg

    let%bench_fun "vrf eval checked" =
      let private_key, msg = Quickcheck.random_value gen in
      fun () ->
        Step.Test.checked_to_unchecked
          Step.Typ.(Scalar.typ * Message.typ)
          Output_hash.typ
          (fun (private_key, msg) ->
            let open Step.Checked in
            let%bind (module Shifted) = Group.Checked.Shifted.create () in
            Vrf.Checked.eval (module Shifted) ~private_key msg )
          (private_key, msg)
  end )
