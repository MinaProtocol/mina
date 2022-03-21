(** Auxiliary information exposed by zkApp smart contract execution.

    The format of this data is opaque to the Mina protocol, and is defined by
    each individual smart contract. A smart contract may emit zero or more
    'events', which are communicated with the transaction when it is broadcast
    over the Mina network.

    These 'events' are collapsed into a single hash for the purposes of the
    zero-knowledge proofs, and this hash is unused by the transaction logic.

    An event may be used to expose information that is useful or important to
    make publicly available, but without storing the data in accounts on-chain.

    Nodes may make this data available for transactions in their pool or from
    within blocks. Archive nodes and similar services may make older historical
    event data available.

    # Example

    A zkApp smart contract could use a
    [merkle tree](https://en.wikipedia.org/wiki/Merkle_tree) to store more data
    than it can fit in its 8 general purpose registers. Usually, when a zkApp
    account updates the root of its merkle tree, there will be no way to know
    what the new contents of the merkle tree are; only the cryptographic 'root
    hash' is publicly available.

    In order to update the merkle tree while making the new contents publicly
    known, a zkApp developer can emit an event containing the new data and its
    position as an event, and any other member of the network can look at this
    event to discover the new contents.

    Consider for example the tree containing 8 values `A, B, C, D, E, F, G, H`.
    ```text
                                H7=Hash(H5, H6)
                               /               \
                H5=Hash(H1, H2)                 H6=Hash(H3, H4)
               /               \               /               \
      H1=Hash(A, B)     H2=Hash(C, D)     H3=Hash(E, F)     H4=Hash(G, H)
     /             \   /             \   /             \   /             \
    A               B C               D E               F G               H
    ```
    `H7` is used as the 'root hash' of the tree.

    A zkApp might update the tree at the 5th position (0-indexed, replacing `F`
    with `I`), generating the resulting tree
    ```text
                               H7'=Hash(H5, H6')
                               /               \
                H5=Hash(H1, H2)                 H6'=Hash(H3', H4)
               /               \               /                 \
      H1=Hash(A, B)     H2=Hash(C, D)     H3'=Hash(E, I)     H4=Hash(G, H)
     /             \   /             \   /             \   /             \
    A               B C               D E               I G               H
    ```
    and storing its new 'root hash' `H7'` in its `app_state`.

    The zkApp can emit an event that encodes the new data to be placed in the
    tree, for example as `{data: I, position: 5}`, and then any user who
    previously knew the contents of the tree can update their local copy to
    match, and can continue to interact with the zkApp's data by
    querying/updating the new tree.
*)

[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params.Tick

module Event = struct
  (** A single event emitted by a zkApp.

      Represented as an array of field elements.
  *)
  type t = Field.t array

  (** Compute the hash of an event.

      The hash input is constructed using
      [`Random_oracle_input.Chunked.field_elements`].
      The hash is computed using the Mina poseidon hash with initial state
      [`Hash_prefix_states.snapp_event`].
  *)
  let hash (x : t) = Random_oracle.hash ~init:Hash_prefix_states.snapp_event x

  [%%ifdef consensus_mechanism]

  type var = Field.Var.t array

  let hash_var (x : Field.Var.t array) =
    Random_oracle.Checked.hash ~init:Hash_prefix_states.snapp_event x

  [%%endif]
end

(** A list of zero or more events, which may be emitted by a zkApp. *)
type t = Event.t list

(** The hash representing the empty list of events.

    This is computed by passing the string `MinaSnappEventsEmpty` to
    [`Random_oracle.salt`] and returning the resulting
    [`Random_oracle.digest`].
*)
let empty_hash = lazy Random_oracle.(salt "MinaSnappEventsEmpty" |> digest)

(** `push_hash events_commitment event_hash` returns the commitment formed by
    hash-consing `event_hash` to `events_commitment.

    This computes a cryptographic commitment to the list `event :: events`,
    where `event_hash = hash(event)`.

    The hash input is constructed using
    [`Random_oracle_input.Chunked.field_elements`] on the list of values
```
[events_commitment, event_hash]
```
    The hash is computed using the Mina poseidon hash with initial state
    [`Hash_prefix_states.snapp_events`].
*)
let push_hash events_commitment event_hash =
  Random_oracle.hash ~init:Hash_prefix_states.snapp_events
    [| events_commitment; event_hash |]

(** `push_event events_commitment event` returns the commitment formed by
    hash-consing `event` to `events_commitment`.

    This computes [`Event.hash`] on `event` and then [`push_hash`] on
    `events_commitment` and the returned hash.
*)
let push_event events_commitment event =
  push_hash events_commitment (Event.hash event)

(** Returns the commitment formed by calling `push_event` on each value in the
    list of events.
*)
let hash (x : t) =
  List.fold ~init:(Lazy.force empty_hash) ~f:push_event x

(** Returns the [Random_oracle_input.t] to be used when hashing larger
    structures containing events.

    This is computed by calling `hash` on the events, then forming an input
    with `Random_oracle_input.Chunked.field`.
*)
let to_input (x : t) = Random_oracle_input.Chunked.field (hash x)

[%%ifdef consensus_mechanism]

type var = t Data_as_hash.t

let var_to_input (x : var) = Data_as_hash.to_input x

let typ = Data_as_hash.typ ~hash

let is_empty_var (e : var) =
  Snark_params.Tick.Field.(
    Checked.equal (Data_as_hash.hash e) (Var.constant (Lazy.force empty_hash)))

let pop_checked (events : var) : Event.t Data_as_hash.t * var =
  let open Run in
  let hd, tl =
    exists
      Typ.(Data_as_hash.typ ~hash:Event.hash * typ)
      ~compute:(fun () ->
        match As_prover.read typ events with
        | [] ->
            failwith "Attempted to pop an empty stack"
        | event :: events ->
            (event, events))
  in
  Field.Assert.equal
    (Random_oracle.Checked.hash ~init:Hash_prefix_states.snapp_events
       [| Data_as_hash.hash tl; Data_as_hash.hash hd |])
    (Data_as_hash.hash events) ;
  (hd, tl)

let push_checked (events : var) (e : Event.var) : var =
  let open Run in
  let res =
    exists typ ~compute:(fun () ->
        let tl = As_prover.read typ events in
        let hd =
          As_prover.read (Typ.array ~length:(Array.length e) Field.typ) e
        in
        hd :: tl)
  in
  Field.Assert.equal
    (Random_oracle.Checked.hash ~init:Hash_prefix_states.snapp_events
       [| Data_as_hash.hash events; Event.hash_var e |])
    (Data_as_hash.hash res) ;
  res

[%%endif]
