open Core_kernel

module type S = sig
  module Impl : Snarky_backendless.Snark_intf.S

  open Impl

  type t = Boolean.var array

  module Unchecked = Unsigned.UInt32

  val length_in_bits : int

  val constant : Unsigned.UInt32.t -> t

  val zero : t

  val xor : t -> t -> (t, _) Checked.t

  val sum : t list -> (t, _) Checked.t

  val rotr : t -> int -> t

  val typ : (t, Unchecked.t) Typ.t
end

module Make (Impl : Snarky_backendless.Snark_intf.S) :
  S with module Impl := Impl = struct
  module B = Bigint
  open Impl
  open Let_syntax
  module Unchecked = Unsigned.UInt32

  type t = Boolean.var array

  let length_in_bits = 32

  let length = length_in_bits

  let get_bit x i =
    let open Unsigned.UInt32 in
    let open Infix in
    Int.equal 0 (compare ((x lsr i) land one) one)

  let constant x =
    Array.init length ~f:(Fn.compose Boolean.var_of_value (get_bit x))

  let typ =
    let open Unsigned.UInt32 in
    let open Infix in
    Typ.transport
      (Typ.array ~length Boolean.typ)
      ~there:(fun x -> Array.init length ~f:(get_bit x))
      ~back:(fun arr ->
        Array.foldi arr ~init:zero ~f:(fun i acc b ->
            if b then acc lor (one lsl i) else acc ) )

  let xor t1 t2 =
    let res = Array.create ~len:length Boolean.false_ in
    let rec go i =
      if i < 0 then return res
      else
        let%bind ri = Boolean.( lxor ) t1.(i) t2.(i) in
        res.(i) <- ri ;
        go (i - 1)
    in
    go (length - 1)

  let zero = Array.init length ~f:(fun _ -> Boolean.false_)

  let to_constant (t : t) =
    try
      let open Unchecked in
      let open Infix in
      Some
        (Array.foldi t ~init:zero ~f:(fun i acc b ->
             let b =
               Field.equal
                 (Option.value_exn (Field.Var.to_constant (b :> Field.Var.t)))
                 Field.one
             in
             if b then acc lor (one lsl i) else acc ))
    with _ -> None

  let pack (t : t) =
    let _, acc =
      Array.fold t
        ~init:(Field.one, Field.Var.constant Field.zero)
        ~f:(fun (x, acc) b ->
          (Field.(x + x), Field.Checked.(acc + (x * (b :> Field.Var.t)))) )
    in
    acc

  let sum (xs : t list) =
    assert (List.length xs < 30) ;
    let c, vars =
      List.fold xs ~init:(0, []) ~f:(fun (c, vs) t ->
          match to_constant t with
          | Some x ->
              (Unchecked.to_int x + c, vs)
          | None ->
              (c, t :: vs) )
    in
    match vars with
    | [] ->
        return (constant (Unchecked.of_int (c mod (1 lsl 32))))
    | _ ->
        let max_length =
          Int.(
            ceil_log2
              ( c
              + (List.length vars * Unchecked.to_int Unsigned.UInt32.max_int)
              ))
        in
        let%map bits =
          Field.Checked.choose_preimage_var ~length:max_length
            (Field.Var.sum
               (Field.Var.constant (Field.of_int c) :: List.map vars ~f:pack))
        in
        Array.of_list
          ( List.take bits 32
          @
          if max_length < 32 then
            List.init (32 - max_length) ~f:(fun _ -> Boolean.false_)
          else [] )

  let rotr t by = Array.init length ~f:(fun i -> t.((i + by) mod length))
end
