open Core
open Snark_params.Tick
open Fold_lib

module Chain_hash = struct
  include Data_hash.Make_full_size ()

  let to_string t =
    Binable.to_string (module Stable.Latest) t |> Base64.encode_string

  let of_string s =
    Base64.decode_exn s |> Binable.of_string (module Stable.Latest)

  include Codable.Make_of_string (struct
    type nonrec t = t

    let to_string = to_string

    let of_string = of_string
  end)

  let empty =
    of_hash
      ( Pedersen.(State.salt params ~get_chunk_table "CodaReceiptEmpty")
      |> Pedersen.State.digest )

  let cons payload t =
    Pedersen.digest_fold Hash_prefix.receipt_chain
      Fold.(User_command.Payload.fold payload +> fold t)
    |> of_hash

  module Checked = struct
    let constant (t : t) =
      var_of_hash_packed (Field.Var.constant (t :> Field.t))

    type t = var

    let if_ = if_

    let cons ~payload t =
      let open Let_syntax in
      let init =
        Pedersen.Checked.Section.create
          ~acc:(`Value Hash_prefix.receipt_chain.acc)
          ~support:
            (Interval_union.of_interval (0, Hash_prefix.length_in_triples))
      in
      let%bind with_t =
        let%bind bs = var_to_triples t in
        Pedersen.Checked.Section.extend init bs
          ~start:
            ( Hash_prefix.length_in_triples
            + User_command.Payload.length_in_triples )
      in
      let%map s = Pedersen.Checked.Section.disjoint_union_exn payload with_t in
      let digest, _ =
        Pedersen.Checked.Section.to_initial_segment_digest s |> Or_error.ok_exn
      in
      var_of_hash_packed digest
  end

  let%test_unit "checked-unchecked equivalence" =
    let open Quickcheck in
    test ~trials:20 (Generator.tuple2 gen User_command_payload.gen)
      ~f:(fun (base, payload) ->
        let unchecked = cons payload base in
        let checked =
          let comp =
            let open Snark_params.Tick.Let_syntax in
            let%bind payload =
              Schnorr.Message.var_of_payload
                Transaction_union_payload.(
                  Checked.constant (of_user_command_payload payload))
            in
            let%map res = Checked.cons ~payload (var_of_t base) in
            As_prover.read typ res
          in
          let (), x = Or_error.ok_exn (run_and_check comp ()) in
          x
        in
        assert (equal unchecked checked) )

  let%test_unit "json" =
    Quickcheck.test ~trials:20 gen ~sexp_of:sexp_of_t ~f:(fun t ->
        assert (For_tests.check_encoding ~equal t) )
end
