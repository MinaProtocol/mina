module type S = sig
  module Protocol_state : Protocol_state.S

  type t [@@deriving sexp]

  val create :
    protocol_state:Protocol_state.value -> protocol_state_proof:Proof.t -> t

  val protocol_state : t -> Protocol_state.value

  val protocol_state_proof : t -> Proof.t
end

module Make (Protocol_state : Protocol_state.S) :
  S with module Protocol_state = Protocol_state =
struct
  module Protocol_state = Protocol_state

  type t =
    { protocol_state: Protocol_state.value
    ; protocol_state_proof: Proof.Stable.V1.t }
  [@@deriving sexp, fields]

  let create ~protocol_state ~protocol_state_proof =
    {protocol_state; protocol_state_proof}
end
