open Types

(* Free monads: technique for implementing DSLs *)

(* Goal *)
(*
let protocol x =
  let a = sample () in
  send_to_prover a;
  let r =
    receive_from_prover (
      sqrt (a * x)
    )
  in
  assert (r * r = a * x)

*)
module F 
    (Randomness : T2)
    (Interaction : F2) (Computation : F2) = struct
  type ('a, 'e) t =
    | Sample : ('r, 'e) Randomness.t * ('r -> 'k) -> ('k, 'e) t
    | Interact : ('a, 'e) Interaction.t -> ('a, 'e) t
    | Compute : ('a, 'e) Computation.t -> ('a, 'e) t

  let map : type a b s. (a, s) t -> f:(a -> b) -> (b, s) t =
   fun t ~f ->
    match t with
    | Sample (t, k) ->
        Sample (t, fun x -> f (k x))
    | Interact x ->
        Interact (Interaction.map x ~f)
    | Compute x ->
        Compute (Computation.map x ~f)

end

module type S = sig
  module Randomness : T2
  module Interaction : F2
  module Computation : F2

  type ('a, 'x) t =
        ('a, 'x) Free_monad.Make2(F(Randomness)(Interaction)(Computation)).t =
    | Pure of 'a
    | Free of (('a, 'x) t, 'x) F(Randomness)(Interaction)(Computation).t

  include Monad_let.S2 with type ('a, 'b) t := ('a, 'b) t

  val interact : (('a, 'e) t, 'e) Interaction.t -> ('a, 'e) t

  val compute : (('a, 'e) t, 'e) Computation.t -> ('a, 'e) t

  val lift_compute : (('a, 'e) Free_monad.Make2(Computation).t) -> ('a, 'e) t

  val sample :
    ('a, 'e) Randomness.t ->
    ('a, 'e) t
end

module T
    (Randomness : T2)
    (Interaction : F2)
    (Computation : F2) :
  S
  with module Interaction := Interaction
   and module Computation := Computation 
   and module Randomness := Randomness 
= struct
  include Free_monad.Make2 (F (Randomness) (Interaction) (Computation))

  let interact x = Free (Interact x)

  let compute x = Free (Compute x)

  let sample t = Free (Sample (t, return))

  let rec lift_compute
    : type a e. 
        (a, e) Free_monad.Make2(Computation).t
      -> (a, e) t
    =
    fun t ->
      match t with
      | Pure x -> Pure x
      | Free c ->
        Free (Compute (Computation.map c ~f:lift_compute))
end

(*
type message =
  | Quit
  | Move of { x : int; y : int; }
  | Write of string
  | Change_color of int * int * int

let message_to_string message =
  match message with
  | Quit -> "quit"
  | Move {x; y} -> sprintf "move (%d, %d)" x y
  | Write s -> sprintf "write %s" s
  | Change_color (r, g, b) -> sprintf "change_color (%d %d %d)" r g b
*)

module Computation = struct
  module Bind
      (R : T2)
      (I : F2)
      (C1 : F2)
      (C2 : F2) (Eta : sig
          val f : ('a, 'e) C1.t -> ('a, 'e) T(R)(I)(C2).t
      end) : sig
    val f : ('a, 'e) T(R)(I)(C1).t -> ('a, 'e) T(R)(I)(C2).t
  end = struct
    module IP2 = T (R)(I) (C2)

    let rec f : type a e. (a, e) T(R)(I)(C1).t -> (a, e) T(R)(I)(C2).t =
    fun t ->
      match t with
      | Pure x ->
          Pure x
      | Free t -> (
        match t with
        | Sample (t, k) ->
            Free (Sample (t, fun x -> f (k x)))
        | Interact i ->
            Free (Interact (I.map i ~f))
        | Compute c ->
            let ip = Eta.f c in
            IP2.bind ip ~f )
  end
end

module Interaction = struct
module Map
    (R : T2)
    (C : F2)
    (I1 : F2)
    (I2 : F2) (Eta : sig
        val f : ('a, 'e) I1.t -> ('a, 'e) I2.t
    end) =
struct
  let rec f : type a e. (a, e) T(R)(I1)(C).t -> (a, e) T(R)(I2)(C).t =
   fun t ->
    match t with
    | Pure x ->
        Pure x
    | Free t ->
        Free
          ( match t with
          | Sample (t, k) ->
              Sample (t, fun x -> f (k x))
          | Compute c ->
              Compute (C.map c ~f)
          | Interact i ->
              Interact (I2.map (Eta.f i) ~f) )
end
end

