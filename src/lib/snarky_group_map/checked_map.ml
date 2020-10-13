open Core_kernel

module Aux (Impl : Snarky_backendless.Snark_intf.Run) = struct
  open Impl

  let non_residue : Field.Constant.t Lazy.t =
    let open Field.Constant in
    let rec go i = if not (is_square i) then i else go (i + one) in
    lazy (go (of_int 2))

  let sqrt_exn x =
    let y =
      exists Field.typ ~compute:(fun () ->
          Field.Constant.sqrt (As_prover.read_var x) )
    in
    assert_square y x ; y

  (* let sqrt_flagged : Field.t -> Field.t * Boolean.var = *)
  let sqrt_flagged x =
    (*
       imeckler: I learned this trick from Dan Boneh

       m a known non residue

       exists is_square : bool, y.
       if is_square then assert y*y = x else assert y*y = m * x

       <=>

       assert (y*y = if is_square then x else m * x)
    *)
    let is_square =
      exists Boolean.typ ~compute:(fun () ->
          Field.Constant.is_square (As_prover.read_var x) )
    in
    let m = Lazy.force non_residue in
    ( sqrt_exn (Field.if_ is_square ~then_:x ~else_:(Field.scale x m))
    , is_square )
end

let wrap (type f) ((module Impl) : f Snarky_backendless.Snark0.m) ~potential_xs
    ~y_squared =
  let open Impl in
  let module A = Aux (Impl) in
  let open A in
  stage (fun x ->
      let x1, x2, x3 = potential_xs x in
      let y1, b1 = sqrt_flagged (y_squared ~x:x1)
      and y2, b2 = sqrt_flagged (y_squared ~x:x2)
      and y3, b3 = sqrt_flagged (y_squared ~x:x3) in
      Boolean.Assert.any [b1; b2; b3] ;
      let x1_is_first = (b1 :> Field.t)
      and x2_is_first = (Boolean.((not b1) && b2) :> Field.t)
      and x3_is_first = (Boolean.((not b1) && (not b2) && b3) :> Field.t) in
      ( Field.((x1_is_first * x1) + (x2_is_first * x2) + (x3_is_first * x3))
      , Field.((x1_is_first * y1) + (x2_is_first * y2) + (x3_is_first * y3)) )
  )

module Make
    (M : Snarky_backendless.Snark_intf.Run) (P : sig
        val params : M.field Group_map.Params.t
    end) =
struct
  open P
  include Group_map.Make (M.Field.Constant) (M.Field) (P)
  open M

  let to_group =
    let {Group_map.Spec.a; b} = Group_map.Params.spec params in
    unstage
      (wrap
         (module M)
         ~potential_xs
         ~y_squared:Field.(fun ~x -> (x * x * x) + scale x a + constant b))
end
