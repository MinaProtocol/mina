open Core_kernel
open Pickles_types

module Constant = struct
  type t = int
end

module T (Impl : Snarky.Snark_intf.Run) = struct
  (* TODO: Optimization. Have this have length n - 1 since the last one is
   determined by the remaining ones. *)
  type 'n t = (Impl.Boolean.var, 'n) Vector.t
end

module Make (Impl : Snarky.Snark_intf.Run with type prover_state = unit) =
struct
  module Constant = Constant
  open Impl
  include T (Impl)

  let of_index i ~length =
    let v = Vector.init length ~f:(fun j -> Field.equal (Field.of_int j) i) in
    Boolean.Assert.any (Vector.to_list v) ;
    v

  let typ (n : 'n Nat.t) : ('n t, Constant.t) Typ.t =
    let typ = Vector.typ Boolean.typ n in
    let typ =
      { typ with
        check=
          (fun x ->
            Snarky.Checked.bind (typ.check x) ~f:(fun () ->
                make_checked (fun () ->
                    Boolean.Assert.exactly_one (Vector.to_list x) ) ) ) }
    in
    Typ.transport typ
      ~there:(fun i -> Vector.init n ~f:(( = ) i))
      ~back:(fun v ->
        let i, _ =
          List.findi (Vector.to_list v) ~f:(fun _ b -> b) |> Option.value_exn
        in
        i )
end
