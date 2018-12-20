open Core

module type Base_intf = sig
  (* TODO: delegate forget here *)
  type t [@@deriving sexp, bin_io, compare, eq]

  type protocol_state

  type protocol_state_proof

  type staged_ledger_diff

  val create :
       protocol_state:protocol_state
    -> protocol_state_proof:protocol_state_proof
    -> staged_ledger_diff:staged_ledger_diff
    -> t

  val protocol_state : t -> protocol_state

  val protocol_state_proof : t -> protocol_state_proof

  val staged_ledger_diff : t -> staged_ledger_diff
end

module type Valid_base_intf = sig
  include Base_intf

  type t_unverified

  val forget : t -> t_unverified
end

module type S = sig
  module Protocol_state : Protocol_state.S

  module Staged_ledger_diff : sig
    type t [@@deriving bin_io, sexp]

    module Verified : sig
      type t [@@deriving sexp, bin_io]
    end
  end

  module T :
    Base_intf
    with type protocol_state := Protocol_state.value
     and type protocol_state_proof := Proof.t
     and type staged_ledger_diff := Staged_ledger_diff.t

  include
    Base_intf
    with type protocol_state := Protocol_state.value
     and type protocol_state_proof := Proof.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type t = T.t

  module With_valid_protocol_state :
    Valid_base_intf
    with type protocol_state := Protocol_state.value
     and type protocol_state_proof := Proof.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type t_unverified := T.t

  module Verified :
    Valid_base_intf
    with type protocol_state := Protocol_state.value
     and type protocol_state_proof := Proof.t
     and type staged_ledger_diff := Staged_ledger_diff.Verified.t
     and type t_unverified := T.t

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

  module Make_record (Protocol_state : sig
    type value [@@deriving sexp, bin_io, compare, eq]

    val compare : value -> value -> int
  end) (Protocol_state_proof : sig
    type t [@@deriving bin_io]
  end) (Staged_ledger_diff : sig
    type t [@@deriving sexp, bin_io]
  end) =
  struct
    type t =
      { protocol_state: Protocol_state.value
      ; protocol_state_proof: Protocol_state_proof.t sexp_opaque
      ; staged_ledger_diff: Staged_ledger_diff.t }
    [@@deriving fields, sexp, bin_io]

    (* TODO: Important for bkase to review *)
    let compare t1 t2 =
      Protocol_state.compare t1.protocol_state t2.protocol_state

    let equal t1 t2 =
      Protocol_state.equal_value t1.protocol_state t2.protocol_state

    let create ~protocol_state ~protocol_state_proof ~staged_ledger_diff =
      {protocol_state; protocol_state_proof; staged_ledger_diff}
  end

  module Proof = Proof.Stable.V1
  module T = Make_record (Protocol_state) (Proof) (Staged_ledger_diff)
  include T

  module With_valid_protocol_state = struct
    include Make_record (Protocol_state) (Proof) (Staged_ledger_diff)

    let forget = Fn.id
  end

  module Verified = struct
    include Make_record (Protocol_state) (Proof) (Staged_ledger_diff.Verified)

    let forget verified =
      let staged_ledger_diff =
        Staged_ledger_diff.forget_verified verified.staged_ledger_diff
      in
      { T.protocol_state= verified.protocol_state
      ; protocol_state_proof= verified.protocol_state_proof
      ; staged_ledger_diff }
  end

  let timestamp {protocol_state; _} =
    Protocol_state.blockchain_state protocol_state
    |> Blockchain_state.timestamp
end
