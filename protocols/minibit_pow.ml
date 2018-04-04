open Core_kernel
open Async_kernel

module type Hash_intf = sig
  type 'a t [@@deriving compare, hash, sexp]

  val hash : 'a -> 'a t
end

(* This sig could probably be improved *)
module type Proof_intf = sig
  type t
  type ('a, 'b) prog

  val create : ('a, 'b) prog -> 'a * 'b -> t

  val verify : t -> ('a, 'b) prog -> 'b -> bool
end

module type Ledger_intf = sig
  type t
end

module type Body_intf  = sig
  type t
  type ledger
  type 'a hash

  val create : ledger hash -> t

  val ledger_hash : t -> ledger hash
end

module type Nonce_intf = sig
  type t
end

module type Strength_intf = sig
  type t
  type difficulty

  val increase : t -> by:difficulty -> t
end

module type Difficulty_intf = sig
  type t

  val next : t -> last:Time.t -> this:Time.t -> t
end

module type Header_intf  = sig
  type t
  type 'a hash
  type nonce
  type strength
  type difficulty
  type body

  val create : prev_timestamp : Time.t ->
    timestamp : Time.t ->
    length : int ->
    most_recent_strength : strength ->
    most_recent_difficulty : difficulty ->
    nonce : nonce ->
    prev_header_hash : t hash ->
    body_hash : body hash ->
    t

  val prev_timestamp : t -> Time.t
  val timestamp : t -> Time.t
  val length : t -> int
  val most_recent_strength : t -> strength
  val most_recent_difficulty : t -> difficulty
  val nonce : t -> nonce
  val prev_header_hash : t -> t hash
  val body_hash : t -> body hash
end

module type Chain_state_intf  = sig
  type t
  type 'a hash
  type body
  type header

  val create : body:body -> header:header -> header_hash:header hash -> t

  val body : t -> body
  val header : t -> header
  val header_hash : t -> header hash
end

module type Chain_transition_intf  = sig
  type t
  type 'a hash
  type ledger
  type proof
  type nonce

  val new_ledger_hash : t -> ledger hash
  val ledger_proof : t -> proof
  val new_timestamp : t -> Time.t
  val nonce : t -> nonce
end

module type Machine_intf  = sig
  type t
  type state
  type transition
  type event =
    | Found of transition
    | New_state of state

  val create : initial:state -> t
  val step : t -> transition -> t
  val drive : t -> scan:(init:'b -> f:('b -> 'a -> 'b Deferred.t) -> ('b -> unit)) -> ('b -> unit)
end

module Make
  (Hash : Hash_intf)
  (Proof : Proof_intf)
  (Ledger : Ledger_intf)
  (Body : Body_intf with type ledger := Ledger.t
                     and type 'a hash := 'a Hash.t)
  (Nonce : Nonce_intf)
  (Difficulty : Difficulty_intf)
  (Strength : Strength_intf with type difficulty := Difficulty.t)
  (Header : Header_intf with type 'a hash := 'a Hash.t
                         and type nonce := Nonce.t
                         and type strength := Strength.t
                         and type difficulty := Difficulty.t
                         and type body := Body.t)
  (State0 : Chain_state_intf with type 'a hash := 'a Hash.t
                              and type body := Body.t
                              and type header := Header.t)
  (Transition : Chain_transition_intf with type 'a hash := 'a Hash.t
                                       and type ledger := Ledger.t
                                       and type proof := Proof.t
                                       and type nonce := Nonce.t)
  = struct

    module State = struct
      include State0
      module With_proof = struct
        type nonrec t = { state : t
                        ; proof : Proof.t
                        }
        let bind ~proof ~state =
          { state
          ; proof
          }

        let create ~body ~header ~header_hash ~proof =
          { state = State0.create ~body ~header ~header_hash
          ; proof
          }

        let body {state} = body state
        let header {state} = header state
        let header_hash {state} = header_hash state
      end
    end

    type t =
      { state : State.With_proof.t
      }
    type event =
      | Found of Transition.t
      | New_state of State.With_proof.t

      (* SNARK "zk_state_valid" proving that, for new_state:
        - all old values came from a chain_state with valid proof
        - transition.ledger_proof proves a valid sequence of transactions moved the ledger from state.body.ledger_hash to new_ledger_hash 
        - prev_timestamp is the old state.header.timestamp
        - timestamp is a newer timestamp than the prev timestamp
        - length is one greater than the old length
        - a "current difficulty" is computed correctly from (most_recent_difficulty, timestamp, new_timestamp)
        - the most recent strength is computed correctly from the most_recent_strength and the "current difficulty"
        - most_recent_difficulty is current difficulty
        - body hash is a hash of the new body
        - prev_header_hash is the old state.header_hash
        - header_hash is a hash of the new header
        - header_hash meets current difficulty
        *)
    let zk_state_valid : ((* old *)State.With_proof.t * Transition.t, State.t) Proof.prog = failwith "zk_snark_proof"

    let step t transition : t =
      let header =
        t.state |> State.With_proof.header
      in
      let difficulty = 
        Difficulty.next
          (Header.most_recent_difficulty header)
          ~last:(Header.timestamp header)
          ~this:(Transition.new_timestamp transition)
      in
      let new_body = Body.create (Transition.new_ledger_hash transition) in
      let new_header =
        Header.create
          ~prev_timestamp:(Header.timestamp header)
          ~timestamp:(Transition.new_timestamp transition)
          ~length:((Header.length header) + 1)
          ~most_recent_strength:(Strength.increase (Header.most_recent_strength header) ~by:difficulty)
          ~most_recent_difficulty:difficulty
          ~nonce:(Transition.nonce transition)
          ~prev_header_hash:(State.With_proof.header_hash t.state)
          ~body_hash:(Hash.hash new_body)
      in
      let header_hash = Hash.hash new_header in
      let new_state =
        State.create
          ~body:new_body
          ~header:new_header
          ~header_hash:header_hash
      in
      let proof = Proof.create zk_state_valid ((t.state, transition), new_state) in
      { state = State.With_proof.bind ~proof ~state:new_state }

    let create ~initial : t =
      { state = initial }

    let check_state (old_state : State.With_proof.t) (new_state : State.With_proof.t) =
      let new_strength = new_state.state |> State.header |> Header.most_recent_strength in
      let old_strength = old_state.state |> State.header |> Header.most_recent_strength in
      new_strength > old_strength &&
      Proof.verify new_state.proof zk_state_valid new_state.state

    let drive (t : t) ~scan =
      scan ~init:t ~f:(fun t -> function
        | Found transition ->
            step t transition
        | New_state state ->
            if check_state t.state state then
              { state }
            else
              t
      )
  end
