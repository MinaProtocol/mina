module type F2 = Free_monad.Functor.S2

module F (Interaction : F2) (Computation : F2) = struct
  type ('a, 'e) t =
    | Sample : ('field -> 'k) -> ('k, < field: 'field ; .. >) t
    | Interact : ('a, 'e) Interaction.t -> ('a, 'e) t
    | Compute : ('a, 'e) Computation.t -> ('a, 'e) t

  let map : type a b s. (a, s) t -> f:(a -> b) -> (b, s) t =
   fun t ~f ->
    match t with
    | Sample k ->
        Sample (fun x -> f (k x))
    | Interact x ->
        Interact (Interaction.map x ~f)
    | Compute x ->
        Compute (Computation.map x ~f)

end

module type S = sig
  module Interaction : F2

  module Computation : F2

  type ('a, 'x) t =
        ('a, 'x) Free_monad.Make2(F(Interaction)(Computation)).t =
    | Pure of 'a
    | Free of (('a, 'x) t, 'x) F(Interaction)(Computation).t

  include Monad_let.S2 with type ('a, 'b) t := ('a, 'b) t

  val interact : (('a, 'e) t, 'e) Interaction.t -> ('a, 'e) t

  val compute : (('a, 'e) t, 'e) Computation.t -> ('a, 'e) t

  val lift_compute : (('a, 'e) Free_monad.Make2(Computation).t) -> ('a, 'e) t

  val sample : ('field, < field: 'field ; .. >) t
end

module T
    (Interaction : Free_monad.Functor.S2)
    (Computation : Free_monad.Functor.S2) :
  S
  with module Interaction := Interaction
   and module Computation := Computation = struct
  include Free_monad.Make2 (F (Interaction) (Computation))

  let interact x = Free (Interact x)

  let compute x = Free (Compute x)

  let sample = Free (Sample return)

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

module Computation = struct
  module Bind
      (I : F2)
      (C1 : F2)
      (C2 : F2) (Eta : sig
          val f : ('a, 'e) C1.t -> ('a, 'e) T(I)(C2).t
      end) : sig
    val f : ('a, 'e) T(I)(C1).t -> ('a, 'e) T(I)(C2).t
  end = struct
    module IP2 = T (I) (C2)

    let rec f : type a e. (a, e) T(I)(C1).t -> (a, e) T(I)(C2).t =
    fun t ->
      match t with
      | Pure x ->
          Pure x
      | Free t -> (
        match t with
        | Sample k ->
            Free (Sample (fun x -> f (k x)))
        | Interact i ->
            Free (Interact (I.map i ~f))
        | Compute c ->
            let ip = Eta.f c in
            IP2.bind ip ~f )
  end
end

module Interaction = struct
module Map
    (C : F2)
    (I1 : F2)
    (I2 : F2) (Eta : sig
        val f : ('a, 'e) I1.t -> ('a, 'e) I2.t
    end) =
struct
  let rec f : type a e. (a, e) T(I1)(C).t -> (a, e) T(I2)(C).t =
   fun t ->
    match t with
    | Pure x ->
        Pure x
    | Free t ->
        Free
          ( match t with
          | Sample k ->
              Sample (fun x -> f (k x))
          | Compute c ->
              Compute (C.map c ~f)
          | Interact i ->
              Interact (I2.map (Eta.f i) ~f) )
end
end

