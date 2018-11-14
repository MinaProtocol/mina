open Core_kernel

module Make
    (Field : Field_intf.Extended) (Var : sig
        include Comparable.S

        include Sexpable.S with type t := t
    end) =
struct
  type t =
    | Constant of Field.t
    | Var of Var.t
    | Add of t * t
    | Scale of Field.t * t
  [@@deriving sexp]

  let length _ = failwith "TODO"

  module Unsafe = struct
    let of_var v = Var v
  end

  let eval context t0 =
    let res = ref Field.zero in
    let rec go scale = function
      | Constant c -> res := Field.add !res (Field.mul scale c)
      | Var v -> res := Field.add !res (Field.mul scale (context v))
      | Scale (s, t) -> go (Field.mul s scale) t
      | Add (t1, t2) -> go scale t1 ; go scale t2
    in
    go Field.one t0 ; !res

  let constant c = Constant c

  let to_constant_and_terms =
    let rec go scale constant terms = function
      | Constant c -> (Field.add constant (Field.mul scale c), terms)
      | Var v -> (constant, (scale, v) :: terms)
      | Scale (s, t) -> go (Field.mul s scale) constant terms t
      | Add (x1, x2) ->
          let c1, terms1 = go scale constant terms x1 in
          go scale c1 terms1 x2
    in
    fun t ->
      let c, ts = go Field.one Field.zero [] t in
      (Some c, ts)

  let add x y = Add (x, y)

  let scale x s = Scale (s, x)

  let neg_one = Field.(sub zero one)

  let sub t1 t2 = add t1 (scale t2 neg_one)

  let linear_combination (terms : (Field.t * t) list) : t =
    List.fold terms ~init:(constant Field.zero) ~f:(fun acc (c, t) ->
        add acc (scale t c) )

  let sum vs = linear_combination (List.map vs ~f:(fun v -> (Field.one, v)))

  module Infix = struct
    let ( + ) = add

    let ( - ) = sub

    let ( * ) c x = scale x c
  end
end
