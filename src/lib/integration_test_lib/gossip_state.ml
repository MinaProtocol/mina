open Core_kernel

module By_direction = struct
  type 'a t = {sent: 'a; received: 'a} [@@deriving to_yojson, fields]
end

module type Set = sig
  type 'a t [@@deriving to_yojson]

  val add :
    'a t -> 'a Event_type.Gossip.With_direction.t Event_type.t -> 'a -> unit

  val size : _ t -> int

  val inter : 'a t list -> 'a t

  val union : 'a t list -> 'a t

  val create : unit -> 'a t
end

module Set : Set = struct
  type _ t = Int.Hash_set.t

  let size = Hash_set.length

  let inter = List.reduce_exn ~f:Hash_set.inter

  let union xs =
    let res = Int.Hash_set.create () in
    List.iter xs ~f:(fun s -> Hash_set.iter s ~f:(Hash_set.add res)) ;
    res

  let to_yojson _f t = `Int (Hash_set.length t)

  let create () = Int.Hash_set.create ()

  let add (type a) (t : a t)
      (type_ : a Event_type.Gossip.With_direction.t Event_type.t) (x : a) =
    let h =
      let open Event_type.Gossip in
      match type_ with
      | Block_gossip ->
          Block.hash_r x
      | Transactions_gossip ->
          Transactions.hash_r x
      | Snark_work_gossip ->
          Snark_work.hash_r x
    in
    Hash_set.add t h
end

open Event_type.Gossip

type t =
  { blocks: Block.r Set.t By_direction.t
  ; transactions: Transactions.r Set.t By_direction.t
  ; snark_work: Snark_work.r Set.t By_direction.t }
[@@deriving to_yojson, fields]

let create () : t =
  let f create =
    {By_direction.sent= create (); By_direction.received= create ()}
  in
  {blocks= f Set.create; transactions= f Set.create; snark_work= f Set.create}

let add (t : t) (type a)
    (type_ : a Event_type.Gossip.With_direction.t Event_type.t)
    ((x : a), (dir : Event_type.Gossip.Direction.t)) : unit =
  let f =
    match dir with
    | Sent ->
        By_direction.sent
    | Received ->
        By_direction.received
  in
  let tbls : a Set.t By_direction.t =
    match type_ with
    | Block_gossip ->
        t.blocks
    | Transactions_gossip ->
        t.transactions
    | Snark_work_gossip ->
        t.snark_work
  in
  Set.add (f tbls) type_ x

(* The number of messages seen by some node but not by all nodes. *)
let stats (type a) (type_ : a Event_type.Gossip.With_direction.t Event_type.t)
    (ts : t list) =
  match ts with
  | [] ->
      (`Seen_by_all 0, `Seen_by_some 0)
  | _ :: _ ->
      let ss =
        let f : t -> a Set.t By_direction.t =
          match type_ with
          | Block_gossip ->
              blocks
          | Transactions_gossip ->
              transactions
          | Snark_work_gossip ->
              snark_work
        in
        List.map ts ~f:(fun t ->
            let s = f t in
            Set.union [s.sent; s.received] )
      in
      ( `Seen_by_all (Set.size (Set.inter ss))
      , `Seen_by_some (Set.size (Set.union ss)) )

let consistency_ratio type_ ts =
  let `Seen_by_all inter, `Seen_by_some union = stats type_ ts in
  if union = 0 then 1. else Float.of_int inter /. Float.of_int union
