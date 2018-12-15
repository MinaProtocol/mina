open Core

module type S = sig
  module Protocol_state : Protocol_state.S

  module Staged_ledger_diff : sig
    type t [@@deriving bin_io, sexp]

    module Verified : sig
      type t [@@deriving sexp, bin_io]
    end
  end

  type t [@@deriving sexp, bin_io, compare, eq]

  module Verified : sig
    type t [@@deriving sexp, bin_io, compare, eq]

    val create :
         protocol_state:Protocol_state.value
      -> protocol_state_proof:Proof.t
      -> staged_ledger_diff:Staged_ledger_diff.Verified.t
      -> t

    val protocol_state : t -> Protocol_state.value

    val protocol_state_proof : t -> Proof.t

    val staged_ledger_diff : t -> Staged_ledger_diff.Verified.t
  end

  val forget : Verified.t -> t

  val create :
       protocol_state:Protocol_state.value
    -> protocol_state_proof:Proof.t
    -> staged_ledger_diff:Staged_ledger_diff.t
    -> t

  val protocol_state : t -> Protocol_state.value

  val protocol_state_proof : t -> Proof.t

  val staged_ledger_diff : t -> Staged_ledger_diff.t

  val timestamp : t -> Block_time.t
end

module Make (Staged_ledger_diff : sig
  type t [@@deriving bin_io, sexp]

  module Verified : sig
    type t [@@deriving bin_io, sexp]
  end

  val forget_verified : Verified.t -> t
end)
(Protocol_state : Protocol_state.S) :
  S
  with module Staged_ledger_diff = Staged_ledger_diff
   and module Protocol_state = Protocol_state = struct
  module Staged_ledger_diff = Staged_ledger_diff
  module Protocol_state = Protocol_state
  module Blockchain_state = Protocol_state.Blockchain_state

  type t =
    { protocol_state: Protocol_state.value
    ; protocol_state_proof: Proof.Stable.V1.t sexp_opaque
    ; staged_ledger_diff: Staged_ledger_diff.t }
  [@@deriving sexp, fields, bin_io]

  module Verified = struct
    type t =
      { protocol_state: Protocol_state.value
      ; protocol_state_proof: Proof.Stable.V1.t
      ; staged_ledger_diff: Staged_ledger_diff.Verified.t }
    [@@deriving sexp, fields, bin_io]

    let compare t1 t2 =
      Protocol_state.compare t1.protocol_state t2.protocol_state

    let equal t1 t2 =
      Protocol_state.equal_value t1.protocol_state t2.protocol_state

    let create ~protocol_state ~protocol_state_proof ~staged_ledger_diff =
      {protocol_state; protocol_state_proof; staged_ledger_diff}
  end

  let forget (verified : Verified.t) =
    let staged_ledger_diff =
      Staged_ledger_diff.forget_verified verified.staged_ledger_diff
    in
    { protocol_state= verified.protocol_state
    ; protocol_state_proof= verified.protocol_state_proof
    ; staged_ledger_diff }

  (* TODO: Important for bkase to review *)
  let compare t1 t2 =
    Protocol_state.compare t1.protocol_state t2.protocol_state

  let equal t1 t2 =
    Protocol_state.equal_value t1.protocol_state t2.protocol_state

  let create ~protocol_state ~protocol_state_proof ~staged_ledger_diff =
    {protocol_state; protocol_state_proof; staged_ledger_diff}

  let timestamp {protocol_state; _} =
    Protocol_state.blockchain_state protocol_state
    |> Blockchain_state.timestamp
end
