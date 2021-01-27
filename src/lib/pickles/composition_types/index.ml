open Core_kernel
open Pickles_types

[%%versioned
module Stable = struct
  module V1 = struct
    type t = char [@@deriving sexp, sexp, compare, yojson, hash, eq]

    let to_latest = Fn.id
  end
end]

let of_int = Char.of_int

let to_int = Char.to_int

let of_int_exn = Char.of_int_exn

let of_bits bits =
  List.foldi bits ~init:0 ~f:(fun i acc b ->
      if b then acc lor (1 lsl i) else acc )
  |> Char.of_int_exn

module Checked (Impl : Snarky_backendless.Snark_intf.Run) = struct
  type t = (Impl.Boolean.var, Nat.N8.n) Vector.t
end

let of_field (type f)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = f) x :
    Checked(Impl).t =
  let open Impl in
  Vector.of_list_and_length_exn (Field.unpack x ~length:8) Nat.N8.n

let typ bool : (('bvar, Nat.N8.n) Vector.t, t, 'f) Snarky_backendless.Typ.t =
  let open Snarky_backendless.Typ in
  transport (Vector.typ bool Nat.N8.n)
    ~there:(fun (x : char) ->
      let x = Char.to_int x in
      Vector.init Nat.N8.n ~f:(fun i -> (x lsr i) land 1 = 1) )
    ~back:(fun bits -> of_bits (Vector.to_list bits))

let packed_typ (type f)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = f) :
    (f Snarky_backendless.Cvar.t, t, f) Snarky_backendless.Typ.t =
  let open Impl in
  Typ.field
  |> Typ.transport
       ~there:(fun (x : char) -> Field.Constant.of_int (Char.to_int x))
       ~back:(fun x -> of_bits (List.take (Field.Constant.unpack x) 8))
