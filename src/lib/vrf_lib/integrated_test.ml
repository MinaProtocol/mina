open Core_kernel
open Snark_params
open Fold_lib
open Signature_lib

module Scalar = struct
  include Tick.Inner_curve.Scalar

  type value = t
end

module Group = struct
  type value = Tick.Inner_curve.t

  type var = Tick.Inner_curve.var

  let scale = Tick.Inner_curve.scale

  module Checked = struct
    include Tick.Inner_curve.Checked

    let scale_generator shifted s ~init =
      scale_known shifted Tick.Inner_curve.one s ~init
  end
end

module Message = struct
  type 'state_hash t = {state_hash: 'state_hash}

  type value = Coda_base.State_hash.t t

  type var = Coda_base.State_hash.var t

  let to_hlist {state_hash} = Coda_base.H_list.[state_hash]

  let of_hlist :
      (unit, 'state_hash -> unit) Coda_base.H_list.t -> 'state_hash t =
   fun Coda_base.H_list.([state_hash]) -> {state_hash}

  let data_spec = Tick.Data_spec.[Coda_base.State_hash.typ]

  let typ =
    Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let fold {state_hash} = Coda_base.State_hash.fold state_hash

  let gen =
    let open Quickcheck.Let_syntax in
    let%map state_hash = Coda_base.State_hash.gen in
    {state_hash}

  let hash_to_group msg =
    let msg_hash_state =
      Snark_params.Tick.Pedersen.hash_fold Coda_base.Hash_prefix.vrf_message
        (fold msg)
    in
    msg_hash_state.acc

  module Checked = struct
    let var_to_triples {state_hash} =
      Coda_base.State_hash.var_to_triples state_hash

    let hash_to_group msg =
      let open Snark_params.Tick in
      let%bind msg_triples = var_to_triples msg in
      Pedersen.Checked.hash_triples ~init:Coda_base.Hash_prefix.vrf_message
        msg_triples
  end
end

module Output_hash = struct
  type value = Random_oracle.Digest.t [@@deriving eq, sexp]

  type var = Random_oracle.Digest.Checked.t

  let typ : (var, value) Snark_params.Tick.Typ.t = Random_oracle.Digest.typ

  let hash msg g =
    let open Fold in
    let compressed_g =
      Non_zero_curve_point.(g |> of_inner_curve_exn |> compress)
    in
    let digest =
      Snark_params.Tick.Pedersen.digest_fold Coda_base.Hash_prefix.vrf_output
        (Message.fold msg +> Non_zero_curve_point.Compressed.fold compressed_g)
    in
    Random_oracle.digest_field digest

  module Checked = struct
    let hash msg g =
      let open Snark_params.Tick.Checked in
      let%bind msg_triples = Message.Checked.var_to_triples msg in
      let%bind g_triples =
        Non_zero_curve_point.(compress_var g >>= Compressed.var_to_triples)
      in
      let%bind pedersen_digest =
        Snark_params.Tick.Pedersen.Checked.digest_triples
          ~init:Coda_base.Hash_prefix.vrf_output (msg_triples @ g_triples)
        >>= Snark_params.Tick.Pedersen.Checked.Digest.choose_preimage
      in
      Random_oracle.Checked.digest_bits
        (pedersen_digest :> Snark_params.Tick.Boolean.var list)
  end
end

module Vrf =
  Vrf_lib.Integrated.Make (Tick) (Scalar) (Group) (Message) (Output_hash)

let%test_unit "eval unchecked vs. checked equality" =
  let gen =
    let open Quickcheck.Let_syntax in
    let%map pk = Private_key.gen and msg = Message.gen in
    (pk, msg)
  in
  Quickcheck.test ~trials:10 gen
    ~f:
      (Tick.Test.test_equal ~sexp_of_t:[%sexp_of: Output_hash.value]
         ~equal:Output_hash.equal_value
         Tick.Typ.(Scalar.typ * Message.typ)
         Output_hash.typ
         (fun (private_key, msg) ->
           let open Tick.Checked in
           let%bind (module Shifted) = Group.Checked.Shifted.create () in
           Vrf.Checked.eval (module Shifted) ~private_key msg )
         (fun (private_key, msg) -> Vrf.eval ~private_key msg))
