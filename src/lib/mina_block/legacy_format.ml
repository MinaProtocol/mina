open Core_kernel

module Helper = struct
  open Mina_base

  let to_yojson ~body_to_yojson ~proof_to_yojson tx =
    let update_to_yojson =
      Account_update.Poly.to_yojson body_to_yojson
        (Control.Poly.to_yojson proof_to_yojson Signature.to_yojson)
    in
    User_command.Poly.to_yojson Signed_command.to_yojson
      (Zkapp_command.with_forest_to_yojson update_to_yojson
         Zkapp_command.Digest.Account_update.to_yojson
         Zkapp_command.Digest.Forest.to_yojson )
      tx

  let of_yojson ~body_of_yojson ~proof_of_yojson ~reset_aux =
    let update_of_yojson t =
      Ppx_deriving_yojson_runtime.(
        Account_update.Poly.of_yojson body_of_yojson
          (Control.Poly.of_yojson proof_of_yojson Signature.of_yojson)
          t
        >|= reset_aux)
    in
    User_command.Poly.of_yojson Signed_command.of_yojson
    @@ Zkapp_command.with_forest_of_yojson update_of_yojson
         Zkapp_command.Digest.Account_update.of_yojson
         Zkapp_command.Digest.Forest.of_yojson

  (** The JSON of a stable command, whose account updates have bodies that
      [body_to_yojson] encodes and that [hash_account_update] hashes. *)
  let stable_to_yojson ~body_to_yojson ~hash_account_update = function
    | User_command.Poly.Signed_command _ as tx ->
        (* ~proof_to_yojson is unused when Helper.to_yojson is applied to a
           Signed_command; the unreachable_code function (which takes a value
           of the uninhabited Nothing.t type) is a compile-time proof of this
           fact through the type system. *)
        to_yojson ~body_to_yojson ~proof_to_yojson:Nothing.unreachable_code tx
    | User_command.Poly.Zkapp_command
        { Zkapp_command.Poly.fee_payer; memo; account_updates } ->
        to_yojson ~body_to_yojson ~proof_to_yojson:Proof.to_yojson
          (Zkapp_command
             { Zkapp_command.Poly.fee_payer
             ; memo
             ; account_updates =
                 Zkapp_command.Call_forest.accumulate_hashes
                   ~hash_account_update account_updates
             } )

  (** The inverse of {!stable_to_yojson}. *)
  let stable_of_yojson ~body_of_yojson json =
    match
      of_yojson ~body_of_yojson ~proof_of_yojson:Proof.of_yojson
        ~reset_aux:Fn.id json
    with
    | Ok (Signed_command tx) ->
        Ppx_deriving_yojson_runtime.Result.Ok
          (User_command.Poly.Signed_command tx)
    | Ok (Zkapp_command { Zkapp_command.Poly.fee_payer; memo; account_updates })
      ->
        Ok
          (Zkapp_command
             { Zkapp_command.Poly.fee_payer
             ; memo
             ; account_updates =
                 Zkapp_command.Call_forest.forget_hashes account_updates
             } )
    | Error e ->
        Error e
end

module User_command = struct
  open Mina_base

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V3 = struct
      type t = User_command.Stable.V4.t [@@deriving sexp]

      let to_yojson : t -> Yojson.Safe.t =
        let signature_kind = Mina_signature_kind.t_DEPRECATED in
        Helper.stable_to_yojson ~body_to_yojson:Account_update.Body.to_yojson
          ~hash_account_update:
            (Zkapp_command.Digest.Account_update.create ~signature_kind)

      let of_yojson =
        Helper.stable_of_yojson ~body_of_yojson:Account_update.Body.of_yojson

      let to_latest = Fn.id
    end

    module V2 = struct
      type t = User_command.Stable.V3.t [@@deriving sexp]

      let to_yojson : t -> Yojson.Safe.t =
        let signature_kind = Mina_signature_kind.t_DEPRECATED in
        Helper.stable_to_yojson
          ~body_to_yojson:Account_update.Body.Stable.V2.to_yojson
          ~hash_account_update:(fun account_update ->
            Zkapp_command.Digest.Account_update.create ~signature_kind
              (Account_update.Stable.V2.to_latest account_update) )

      let of_yojson =
        Helper.stable_of_yojson
          ~body_of_yojson:Account_update.Body.Stable.V2.of_yojson

      let to_latest = User_command.Stable.V3.to_latest
    end
  end]

  type nonrec t = User_command.t

  let proof_cache_db = Proof_cache_tag.create_identity_db ()

  let proof_to_yojson proof =
    Proof_cache_tag.read_proof_from_disk proof |> Proof.to_yojson

  let proof_of_yojson json =
    match Proof.of_yojson json with
    | Ok proof ->
        Ppx_deriving_yojson_runtime.Result.Ok
          (Proof_cache_tag.write_proof_to_disk proof_cache_db proof)
    | Error e ->
        Ppx_deriving_yojson_runtime.Result.Error e

  let to_yojson =
    Helper.to_yojson ~body_to_yojson:Account_update.Body.to_yojson
      ~proof_to_yojson

  let of_yojson =
    Helper.of_yojson ~body_of_yojson:Account_update.Body.of_yojson
      ~proof_of_yojson ~reset_aux:Account_update.reset_aux
end

module Staged_ledger_diff = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V3 = struct
      type t = Staged_ledger_diff.Stable.V4.t =
        { diff :
            ( Transaction_snark_work.Stable.V3.t
            , User_command.Stable.V3.t Mina_base.With_status.Stable.V2.t )
            Staged_ledger_diff.Pre_diff_two.Stable.V2.t
            * ( Transaction_snark_work.Stable.V3.t
              , User_command.Stable.V3.t Mina_base.With_status.Stable.V2.t )
              Staged_ledger_diff.Pre_diff_one.Stable.V2.t
              option
        }
      [@@deriving sexp, yojson]

      let to_latest = ident
    end

    module V2 = struct
      type t = Staged_ledger_diff.Stable.V3.t =
        { diff :
            ( Transaction_snark_work.Stable.V2.t
            , User_command.Stable.V2.t Mina_base.With_status.Stable.V2.t )
            Staged_ledger_diff.Pre_diff_two.Stable.V2.t
            * ( Transaction_snark_work.Stable.V2.t
              , User_command.Stable.V2.t Mina_base.With_status.Stable.V2.t )
              Staged_ledger_diff.Pre_diff_one.Stable.V2.t
              option
        }
      [@@deriving sexp, yojson]

      let to_latest = Staged_ledger_diff.Stable.V3.to_latest
    end
  end]
end
