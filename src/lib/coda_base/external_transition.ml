open Core

module type Base_intf = sig
  (* TODO: delegate forget here *)
  type t [@@deriving sexp, bin_io, compare, eq]

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
    type t [@@deriving bin_io, sexp]
  end

  include
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

  val to_verified : t -> [`I_swear_this_is_safe_see_my_comment of Verified.t]

  val of_verified : Verified.t -> t
end

module Make (Staged_ledger_diff : sig
  type t [@@deriving bin_io, sexp]
end)
(Protocol_state : Protocol_state.S) :
  S
  with module Staged_ledger_diff = Staged_ledger_diff
   and module Protocol_state = Protocol_state = struct
  module Staged_ledger_diff = Staged_ledger_diff
  module Protocol_state = Protocol_state
  module Blockchain_state = Protocol_state.Blockchain_state

  module T = struct
    type t =
      { protocol_state: Protocol_state.value
      ; protocol_state_proof: Proof.Stable.V1.t sexp_opaque
      ; staged_ledger_diff: Staged_ledger_diff.t }
    [@@deriving sexp, fields, bin_io]

    (* TODO: Important for bkase to review *)
    let compare t1 t2 =
      Protocol_state.compare t1.protocol_state t2.protocol_state

    let equal t1 t2 =
      Protocol_state.equal_value t1.protocol_state t2.protocol_state
  end

  include T
  module Verified = T

  let to_verified x = `I_swear_this_is_safe_see_my_comment x

  let of_verified = Fn.id

  let create ~protocol_state ~protocol_state_proof ~staged_ledger_diff =
    {protocol_state; protocol_state_proof; staged_ledger_diff}

  let timestamp {protocol_state; _} =
    Protocol_state.blockchain_state protocol_state
    |> Blockchain_state.timestamp
end
