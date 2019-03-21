open Core_kernel
open Async
open Module_version

type ('work, 'priced_proof) diff = Add_solved_work of 'work * 'priced_proof
[@@deriving bin_io, sexp, yojson]

module Make (Proof : sig
  type t [@@deriving bin_io, yojson]
end) (Fee : sig
  type t [@@deriving bin_io, sexp, yojson]
end) (Work : sig
  type t [@@deriving sexp, yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io, yojson]
      end
    end
    with type V1.t = t
end)
(Transition_frontier : T)
(Pool : Snark_pool.S
        with type work := Work.t
         and type proof := Proof.t
         and type fee := Fee.t
         and type transition_frontier := Transition_frontier.t) =
struct
  module Priced_proof = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          let version = 1

          (* TODO : version Proof and Fee *)
          type t = {proof: Proof.t sexp_opaque; fee: Fee.t}
          [@@deriving bin_io, sexp]

          let to_yojson {proof; fee} =
            `Assoc
              [("proof", Proof.to_yojson proof); ("fee", Fee.to_yojson fee)]

          let of_yojson (json : Yojson.Safe.json) =
            match json with
            | `Assoc attrs ->
                let open Result.Let_syntax in
                let%bind proof_json, fee_json =
                  Result.of_option ~error:"missing keys"
                    (let open Option.Let_syntax in
                    let%bind proof_json =
                      List.Assoc.find attrs ~equal:String.equal "proof"
                    in
                    let%map fee_json =
                      List.Assoc.find attrs ~equal:String.equal "fee"
                    in
                    (proof_json, fee_json))
                in
                let%bind proof_val = Proof.of_yojson proof_json in
                let%map fee_val = Fee.of_yojson fee_json in
                {proof= proof_val; fee= fee_val}
            | _ -> Error "expected `Assoc"
        end

        include T
        include Registration.Make_latest_version (T)
      end

      module Latest = V1

      module Module_decl = struct
        let name = "snark_pool_diff_priced_proof"

        type latest = Latest.t
      end

      module Registrar = Registration.Make (Module_decl)
      module Registered_V1 = Registrar.Register (V1)
    end

    (* bin_io omitted *)
    type t = Stable.Latest.t = {proof: Proof.t sexp_opaque; fee: Fee.t}
    [@@deriving sexp]

    let to_yojson = Stable.Latest.to_yojson

    let of_yojson = Stable.Latest.of_yojson
  end

  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        type t = (Work.Stable.V1.t, Priced_proof.Stable.V1.t) diff
        [@@deriving bin_io, sexp, yojson]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "snark_pool_diff"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted *)
  type t = Stable.Latest.t [@@deriving sexp, yojson]

  let summary = function
    | Add_solved_work (_, Priced_proof.({proof= _; fee})) ->
        Printf.sprintf !"Snark_pool_diff add with fee %{sexp: Fee.t}" fee

  let apply (pool : Pool.t) (t : t Envelope.Incoming.t) :
      t Or_error.t Deferred.t =
    let t = Envelope.Incoming.data t in
    let to_or_error = function
      | `Don't_rebroadcast ->
          Or_error.error_string "Worse fee or already in pool"
      | `Rebroadcast -> Ok t
    in
    ( match t with Add_solved_work (work, {proof; fee}) ->
        Pool.add_snark pool ~work ~proof ~fee )
    |> to_or_error |> Deferred.return
end
