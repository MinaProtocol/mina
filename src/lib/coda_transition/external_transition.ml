open Core_kernel
open Coda_base
open Coda_state
open Module_version

module type Base_intf = sig
  (* TODO: delegate forget here *)
  type t [@@deriving sexp, compare, to_yojson]

  include Comparable.S with type t := t

  type staged_ledger_diff

  val protocol_state : t -> Protocol_state.Value.t

  val protocol_state_proof : t -> Proof.t

  val staged_ledger_diff : t -> staged_ledger_diff

  val parent_hash : t -> State_hash.t

  val consensus_state : t -> Consensus.Data.Consensus_state.Value.t

  val proposer : t -> Signature_lib.Public_key.Compressed.t

  val user_commands : t -> User_command.t list

  val payments : t -> User_command.t list
end

module type S = sig
  type staged_ledger_diff

  include Base_intf with type staged_ledger_diff := staged_ledger_diff

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, eq, bin_io, to_yojson, version]
      end

      module Latest = V1
    end
    with type V1.t = t

  module Proof_verified :
    Base_intf with type staged_ledger_diff := staged_ledger_diff

  module Verified :
    Base_intf with type staged_ledger_diff := staged_ledger_diff

  val create :
       protocol_state:Protocol_state.Value.t
    -> protocol_state_proof:Proof.t
    -> staged_ledger_diff:staged_ledger_diff
    -> t

  val timestamp : t -> Block_time.t

  val to_proof_verified :
    t -> [`I_swear_this_is_safe_see_my_comment of Proof_verified.t]

  val to_verified : t -> [`I_swear_this_is_safe_see_my_comment of Verified.t]

  val of_verified : Verified.t -> t

  val of_proof_verified : Proof_verified.t -> t

  val forget_consensus_state_verification : Verified.t -> Proof_verified.t
end

module type Staged_ledger_diff_intf = sig
  type t [@@deriving bin_io, sexp, version]

  val creator : t -> Signature_lib.Public_key.Compressed.t

  val user_commands : t -> User_command.t list
end

module Make (Staged_ledger_diff : Staged_ledger_diff_intf) :
  S with type staged_ledger_diff := Staged_ledger_diff.t = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          { protocol_state: Protocol_state.Value.Stable.V1.t
          ; protocol_state_proof: Proof.Stable.V1.t sexp_opaque
          ; staged_ledger_diff: Staged_ledger_diff.t }
        [@@deriving sexp, fields, bin_io, version]

        let to_yojson
            {protocol_state; protocol_state_proof= _; staged_ledger_diff= _} =
          `Assoc
            [ ("protocol_state", Protocol_state.value_to_yojson protocol_state)
            ; ("protocol_state_proof", `String "<opaque>")
            ; ("staged_ledger_diff", `String "<opaque>") ]

        (* TODO: Important for bkase to review *)
        let compare t1 t2 =
          Protocol_state.Value.Stable.V1.compare t1.protocol_state
            t2.protocol_state

        let consensus_state {protocol_state; _} =
          Protocol_state.consensus_state protocol_state

        let parent_hash {protocol_state; _} =
          Protocol_state.previous_state_hash protocol_state

        let proposer {staged_ledger_diff; _} =
          Staged_ledger_diff.creator staged_ledger_diff

        let user_commands {staged_ledger_diff; _} =
          Staged_ledger_diff.user_commands staged_ledger_diff

        let payments external_transition =
          List.filter
            (user_commands external_transition)
            ~f:
              (Fn.compose User_command_payload.is_payment User_command.payload)
      end

      include T
      include Comparable.Make (T)
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "external_transition"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted *)
  type t = Stable.Latest.t =
    { protocol_state: Protocol_state.Value.Stable.V1.t
    ; protocol_state_proof: Proof.Stable.V1.t sexp_opaque
    ; staged_ledger_diff: Staged_ledger_diff.t }
  [@@deriving sexp, fields]

  include Comparable.Make (Stable.Latest)
  module Proof_verified = Stable.Latest
  module Verified = Stable.Latest

  let to_yojson = Stable.Latest.to_yojson

  let to_proof_verified x = `I_swear_this_is_safe_see_my_comment x

  let to_verified x = `I_swear_this_is_safe_see_my_comment x

  let of_verified = Fn.id

  let of_proof_verified = Fn.id

  let forget_consensus_state_verification = Fn.id

  let create ~protocol_state ~protocol_state_proof ~staged_ledger_diff =
    {protocol_state; protocol_state_proof; staged_ledger_diff}

  let timestamp {protocol_state; _} =
    Protocol_state.blockchain_state protocol_state
    |> Blockchain_state.timestamp

  [%%define_locally
  Stable.Latest.
    (consensus_state, parent_hash, proposer, user_commands, payments)]
end

include Make (struct
  include Staged_ledger_diff.Stable.V1

  [%%define_locally
  Staged_ledger_diff.(creator, user_commands)]
end)
