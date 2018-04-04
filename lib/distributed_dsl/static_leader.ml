open Core_kernel
open Async_kernel

type leader_nonce = int [@@deriving eq, sexp]
type node_nonce = int [@@deriving eq, sexp]
type round = int [@@deriving eq, sexp]
module Message = struct
  type t =
    | New_round of node_nonce list * leader_nonce * round
    | One_nonce of node_nonce * leader_nonce * round
  [@@deriving eq, sexp]
  let is_new_round = function
    | New_round _ -> true
    | _ -> false
  let is_one_nonce = function
    | One_nonce _ -> true
    | _ -> false
end

module State = struct
  type t =
    | Waiting
    | Processing of
      { round : round
      ; leader_nonce : leader_nonce
      ; other_nonces : node_nonce list
      }
  [@@deriving eq, sexp]
end

module Message_label = struct
  type label = Got_new_round | Got_one_nonce [@@deriving eq, enum, sexp, compare, hash]
  module T = struct
    type t = label [@@deriving compare, hash, sexp]
  end
  include T
  include Hashable.Make(T)
end

module Timer_label = struct
  type label = Response [@@deriving enum, sexp, compare, hash]
  module T = struct
    type t = label [@@deriving compare, hash, sexp]
  end
  include T
  include Hashable.Make(T)
end

module Condition_label = struct
  type label = Todo [@@deriving enum, sexp, compare, hash]
  module T = struct
    type t = label [@@deriving compare, hash, sexp]
  end
  include T
  include Hashable.Make(T)
end

module Message_delay = struct
  type message = Message.t
  let delay _ = Time.Span.of_ms 500.
end

module Machine = Simulator.Make(State)(Message)(Message_delay)(Message_label)(Timer_label)(Condition_label)

let spec i =
  let open State in
  let open Message_label in
  let open Condition_label in
  let open Timer_label in
  let open Message in
  let open Machine.MyNode in
  ()
  (*[ msg Got_new_round (fun m _ -> Message.is_new_round m) ~f:(fun t m state ->*)
      (*match m with*)
      (*| New_round *)
    (*)*)
 

