open Core
open Util
open Snark_params.Tick

module Chain_hash = struct
  include Data_hash.Make_full_size()

  let empty =
    of_hash
      (Pedersen.(State.salt params "CodaReceiptEmpty") |> Pedersen.State.digest)

  let cons payload t =
    Pedersen.digest_fold Hash_prefix.receipt_chain
      (Transaction.Payload.fold payload +> fold t)
    |> of_hash

  module Checked = struct
    let constant (t:t) = var_of_hash_packed (Field.Checked.constant (t :> Field.t))

    type t = var

    let if_ = if_

    let cons ~payload t =
      let open Let_syntax in
      let init =
        Pedersen_hash.Section.create
          ~acc:(`Value Hash_prefix.receipt_chain.acc)
          ~support:(Interval_union.of_interval (0, Hash_prefix.length_in_bits))
      in
      let%bind with_t =
        let%bind bs = var_to_bits t in
        Pedersen_hash.Section.extend init bs
          ~start:(Hash_prefix.length_in_bits
                  + Transaction.Payload.length_in_bits)
      in
      let%map s = Pedersen_hash.Section.disjoint_union_exn payload with_t in
      let (digest, _) =
        Pedersen_hash.Section.to_initial_segment_digest s |> Or_error.ok_exn
      in
      var_of_hash_packed digest
  end

  let%test_unit "checked-unchecked equivalence" =
    let open Quickcheck in
    test ~trials:20 (Generator.tuple2 gen Transaction_payload.gen) ~f:(fun (base, payload) ->
      let unchecked = cons payload base in
      let checked =
        let comp =
          let open Snark_params.Tick.Let_syntax in
          let%bind payload =
            Schnorr.Message.var_of_payload
              (Transaction_payload.var_of_t payload)
          in
          let%map res = Checked.cons ~payload (var_of_t base) in
          As_prover.read typ res
        in
        let ((), x) =
          Or_error.ok_exn (run_and_check comp ())
        in
        x
      in
      assert (equal unchecked checked))
end
