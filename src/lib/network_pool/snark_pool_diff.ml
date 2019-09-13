open Core_kernel
open Async_kernel
open Module_version

module Make (Ledger_proof : sig
  type t [@@deriving bin_io, sexp, to_yojson, version]
end) (Work : sig
  type t [@@deriving sexp]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io, to_yojson, version, hash]
      end
    end
    with type V1.t = t

  include Hashable.S with type t := t

  val compact_json : t -> Yojson.Safe.json
end) (Work_info : sig
  type t [@@deriving sexp]
end)
(Transition_frontier : T)
(Pool : Intf.Snark_resource_pool_intf
        with type work := Work.t
         and type transition_frontier := Transition_frontier.t
         and type ledger_proof := Ledger_proof.t
         and type work_info := Work_info.t) :
  Intf.Snark_pool_diff_intf
  with type ledger_proof := Ledger_proof.t
   and type work := Work.t
   and type resource_pool := Pool.t = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          | Add_solved_work of
              Work.Stable.V1.t
              * Ledger_proof.t One_or_two.Stable.V1.t Priced_proof.Stable.V1.t
        [@@deriving bin_io, sexp, to_yojson, version]
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
  type t = Stable.Latest.t =
    | Add_solved_work of
        Work.Stable.V1.t * Ledger_proof.t One_or_two.t Priced_proof.Stable.V1.t
  [@@deriving sexp, to_yojson]

  let compact_json = function
    | Add_solved_work (work, {proof= _; fee= {fee; prover}}) ->
        `Assoc
          [ ("work_ids", Work.compact_json work)
          ; ("fee", Currency.Fee.to_yojson fee)
          ; ("prover", Signature_lib.Public_key.Compressed.to_yojson prover) ]

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
