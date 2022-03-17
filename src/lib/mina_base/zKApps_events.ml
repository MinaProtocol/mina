(** Auxiliary information exposed by zkApp smart contract execution.

    The format of this data is opaque to the Mina protocol, and is defined by
    each individual smart contract. A smart contract may emit zero or more
    'events', which are communicated with the transaction when it is broadcast
    over the Mina network.

    These 'events' are collapsed into a single hash for the purposes of the
    zero-knowledge proofs, and this hash is unused by the transaction logic.

    An event may be used to expose information that is useful or important to
    make publically available, but without storing the data in accounts
    on-chain.

    Nodes may make this data available for transactions in their pool or from
    within blocks. Archive nodes and similar services may make older historical
    event data available.

    # Example

    A zkApp smart contract could use a
    [merkle tree](https://en.wikipedia.org/wiki/Merkle_tree) to store more data
    than it can fit in its 8 general purpose registers. Usually, when a snap
    account updates the root of its merkle tree, there will be no way to know
    what the new contents of the merkle tree are; only the cryptographic 'root
    hash' is publically available.

    In order to update the merkle tree while making the new contents publically
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
  (* Arbitrary hash input, encoding determined by the snapp's developer. *)
  type t = Field.t array

  let hash (x : t) = Random_oracle.hash ~init:Hash_prefix_states.snapp_event x

  [%%ifdef consensus_mechanism]

  type var = Field.Var.t array

  let hash_var (x : Field.Var.t array) =
    Random_oracle.Checked.hash ~init:Hash_prefix_states.snapp_event x

  [%%endif]
end

type t = Event.t list

let empty_hash = lazy Random_oracle.(salt "MinaSnappEventsEmpty" |> digest)

let push_hash acc hash =
  Random_oracle.hash ~init:Hash_prefix_states.snapp_events [| acc; hash |]

let push_event acc event = push_hash acc (Event.hash event)

let hash (x : t) = List.fold ~init:(Lazy.force empty_hash) ~f:push_event x

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
