open Core
open Module_version

module type Base_intf = sig
  (* TODO: delegate forget here *)
  type t [@@deriving sexp, compare, eq]

  include Comparable.S with type t := t

  type protocol_state

  type protocol_state_proof

  type staged_ledger_diff

  val protocol_state : t -> protocol_state

  val protocol_state_proof : t -> protocol_state_proof

  val staged_ledger_diff : t -> staged_ledger_diff
end

module type S = sig
  module Protocol_state : Protocol_state.S

  module Staged_ledger_diff : sig
    type t [@@deriving sexp]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving bin_io, sexp]
        end
      end
      with type V1.t = t
  end

  include
    Base_intf
    with type protocol_state := Protocol_state.value
     and type protocol_state_proof := Proof.t
     and type staged_ledger_diff := Staged_ledger_diff.t

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io]
      end

      module Latest = V1
    end
    with type V1.t = t

  module Proof_verified :
    Base_intf
    with type protocol_state := Protocol_state.value
     and type protocol_state_proof := Proof.t
     and type staged_ledger_diff := Staged_ledger_diff.t

  module Verified :
    Base_intf
    with type protocol_state := Protocol_state.value
     and type protocol_state_proof := Proof.t
     and type staged_ledger_diff := Staged_ledger_diff.t

  val create :
       protocol_state:Protocol_state.value
    -> protocol_state_proof:Proof.t
    -> staged_ledger_diff:Staged_ledger_diff.t
    -> t

  val timestamp : t -> Block_time.t

  val to_proof_verified :
    t -> [`I_swear_this_is_safe_see_my_comment of Proof_verified.t]

  val to_verified : t -> [`I_swear_this_is_safe_see_my_comment of Verified.t]

  val of_verified : Verified.t -> t

  val of_proof_verified : Proof_verified.t -> t

  val forget_consensus_state_verification : Verified.t -> Proof_verified.t
end

module Make (Staged_ledger_diff : sig
  type t [@@deriving sexp]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving bin_io, sexp]
      end
    end
    with type V1.t = t
end)
(Protocol_state : Protocol_state.S) :
  S
  with module Staged_ledger_diff = Staged_ledger_diff
   and module Protocol_state = Protocol_state = struct
  module Staged_ledger_diff = Staged_ledger_diff
  module Protocol_state = Protocol_state
  module Blockchain_state = Protocol_state.Blockchain_state

  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        type t =
          { protocol_state: Protocol_state.value
          ; protocol_state_proof: Proof.Stable.V1.t sexp_opaque
          ; staged_ledger_diff: Staged_ledger_diff.Stable.V1.t }
        [@@deriving sexp, fields, bin_io]

        (* TODO: Important for bkase to review *)
        let compare t1 t2 =
          Protocol_state.compare t1.protocol_state t2.protocol_state

        let equal t1 t2 =
          Protocol_state.equal_value t1.protocol_state t2.protocol_state
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
    { protocol_state: Protocol_state.value
    ; protocol_state_proof: Proof.t sexp_opaque
    ; staged_ledger_diff: Staged_ledger_diff.t }
  [@@deriving sexp, fields]

  include Comparable.Make (Stable.Latest)
  module Proof_verified = Stable.Latest
  module Verified = Stable.Latest

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
end
