open Core_kernel
open Async_kernel
open Module_version

module Make (Ledger_proof : sig
  type t [@@deriving bin_io, sexp, yojson, version]
end) (Work : sig
  type t [@@deriving sexp]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io, yojson, version, hash]

        val compact_json : t -> Yojson.Safe.json
      end
    end
    with type V1.t = t

  include Hashable.S with type t := t
end)
(Transition_frontier : T)
(Pool : Intf.Snark_resource_pool_intf
        with type work := Work.t
         and type transition_frontier := Transition_frontier.t
         and type ledger_proof := Ledger_proof.t) :
  Intf.Snark_pool_diff_intf
  with type ledger_proof := Ledger_proof.t
   and type work := Work.t
   and type resource_pool := Pool.t = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          | Add_solved_work of
              Work.Stable.V1.t * Ledger_proof.t list Priced_proof.Stable.V1.t
        [@@deriving bin_io, sexp, yojson, version]
      end

      include T
      include Registration.Make_latest_version (T)

      let compact_json = function
        | Add_solved_work (work, {proof= _; fee= {fee; prover}}) ->
            `Assoc
              [ ("work_ids", Work.Stable.V1.compact_json work)
              ; ("fee", Currency.Fee.Stable.V1.to_yojson fee)
              ; ( "prover"
                , Signature_lib.Public_key.Compressed.Stable.V1.to_yojson
                    prover ) ]
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

  [%%define_locally
  Stable.Latest.(compact_json)]

  let summary = function
    | Stable.V1.Add_solved_work (_, {proof= _; fee}) ->
        Printf.sprintf
          !"Snark_pool_diff add with fee %{sexp: Coda_base.Fee_with_prover.t}"
          fee

  let apply (pool : Pool.t) (t : t Envelope.Incoming.t) :
      t Or_error.t Deferred.t =
    let t = Envelope.Incoming.data t in
    let to_or_error = function
      | `Don't_rebroadcast ->
          Or_error.error_string "Worse fee or already in pool"
      | `Rebroadcast ->
          Ok t
    in
    ( match t with
    | Stable.V1.Add_solved_work (work, {proof; fee}) ->
        Pool.add_snark pool ~work ~proof ~fee )
    |> to_or_error |> Deferred.return
end
