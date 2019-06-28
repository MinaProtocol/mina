open Core_kernel
open Snark_params
open Fold_lib

module Group = struct
  include Tick.Inner_curve

  (*  module Checked = struct
   *    let scale_generator shifted s ~init =
   *    scale_known shifted one s ~init
   *  end
   *)
end

module Message = struct

  let gen =
    let open Quickcheck.Let_syntax in
    let%map state_hash = Coda_base.State_hash.gen in
    {state_hash}

    (*
  module Checked = struct
    let var_to_triples {state_hash} =
      Coda_base.State_hash.var_to_triples state_hash

    let hash_to_group msg =
      let open Snark_params.Tick in
      let%bind msg_triples = var_to_triples msg in
      Pedersen.Checked.hash_triples ~init:Coda_base.Hash_prefix.vrf_message
        msg_triples
  end
*)
end

module Schnorr =
Checked.Schnorr (Tick) (Group) (Message)

  let gen =
    let open Quickcheck.Let_syntax in
    let%map pk = Private_key.gen and msg = Message.gen in
    (pk, msg)

let%test_unit "schnorr unchecked vs. checked equality" =
  Quickcheck.test ~trials:10 gen
    ~f:
      (Tick.Test.test_equal ~sexp_of_t:[%sexp_of: Output_hash.value]
         ~equal:Output_hash.equal_value
         Tick.Typ.(Scalar.typ * Message.typ)
         Output_hash.typ
         (fun (private_key, msg) ->
           let open Tick.Checked in
           let%bind (module Shifted) = Group.Checked.Shifted.create () in
           Schnorr.Checked.sign (module Shifted) ~private_key msg )
         (fun (private_key, msg) -> Schnorr.sign ~private_key msg))

let%test_unit "schnorr unchecked" =
Quickcheck.test ~trials:5 gen ~f:(fun s ->
 [%test_eq: bool] true ( Schnorr.verify (Schnorr.sign s)) )

let%test_unit "checked schnorr" =
Quickcheck.test ~trials:5 gen ~f:(fun s ->
 [%test_eq: bool] true ( Schnorr.Checked.verifies (Schnorr.Checked.sign s)) )
