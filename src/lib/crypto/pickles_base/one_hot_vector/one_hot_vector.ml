open Core_kernel
open Pickles_types

module Constant = struct
  type t = int
end

(* TODO: Optimization(?) Have this have length n - 1 since the last one is
    determined by the remaining ones. *)
type ('v, 'n) t = ('v Snarky_backendless.Boolean.t, 'n) Vector.t

module T (Impl : Snarky_backendless.Snark_intf.Run) = struct
  type nonrec 'n t = (Impl.field_var, 'n) t
end

module Make (Impl : Snarky_backendless.Snark_intf.Run) = struct
  module Constant = Constant
  open Impl
  include T (Impl)

  let of_index i ~length =
    let v = Vector.init length ~f:(fun j -> Field.equal (Field.of_int j) i) in
    Boolean.Assert.any (Vector.to_list v) ;
    v

  let of_vector_unsafe = Fn.id

  module Vector_typ = Vector.Make_typ (Impl)

  let typ (n : 'n Nat.t) : ('n t, Constant.t) Typ.t =
    let (Typ typ) = Vector_typ.typ Boolean.typ n in
    let typ : _ Typ.t =
      Typ
        { typ with
          check =
            (fun x ->
              Impl.Internal_Basic.Checked.bind (typ.check x) ~f:(fun () ->
                  make_checked (fun () ->
                      Boolean.Assert.exactly_one (Vector.to_list x) ) ) )
        }
    in
    Typ.transport typ
      ~there:(fun i -> Vector.init n ~f:(( = ) i))
      ~back:(fun v ->
        let i, _ =
          List.findi (Vector.to_list v) ~f:(fun _ b -> b) |> Option.value_exn
        in
        i )
end

module Step = Make (Kimchi_pasta_snarky_backend.Step_impl)
module Wrap = Make (Kimchi_pasta_snarky_backend.Wrap_impl)
