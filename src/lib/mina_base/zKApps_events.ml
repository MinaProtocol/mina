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
