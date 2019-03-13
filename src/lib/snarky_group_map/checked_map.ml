module Make
    (M : Snarky.Snark_intf.Run) (Params : sig
        val a : M.Field.t

        val b : M.Field.t
    end) =
struct
  module B =
    Group_map.Make_group_map (struct
        include M.Field

        let t_of_sexp x = constant (Constant.t_of_sexp x)

        let negate x = zero - x
      end)
      (Params)

  open M

  (* let sqrt_flagged : Field.t -> Field.t * Boolean.var = *)
  let sqrt_flagged x =
    (* z = sqrt of x (if one exists) *)
    let z =
      exists Field.typ
        ~compute:
          As_prover.(
            map (read_var x) ~f:(fun x ->
                if M.Field.Constant.is_square x then M.Field.Constant.sqrt x
                else M.Field.Constant.one ))
    in
    let z2 = Field.(z * z) in
    let b = Field.equal z2 x in
    (z, b)

  (* with (x1, b1), (x2, b2), (x3, b3), we need to take
   * only the first square. this means we can do
   * x1 * f1 + (x2 * f2 * not f1) + (x3 * f3 * not f1 * not f2)
   *)

  let to_group x =
    let f x = Field.((x * x * x) + (Params.a * x) + Params.b) in
    let x1 = B.make_x1 x in
    let x2 = B.make_x2 x in
    let x3 = B.make_x3 x in
    let y1, b1 = sqrt_flagged (f x1) in
    let y2, b2 = sqrt_flagged (f x2) in
    let y3, b3 = sqrt_flagged (f x3) in
    Boolean.Assert.any [b1; b2; b3] ;
    let x1_is_first = (b1 :> Field.t) in
    let x2_is_first = (Boolean.((not b1) && b2) :> Field.t) in
    let x3_is_first = (b3 :> Field.t) in
    ( Field.((x1_is_first * x1) + (x2_is_first * x2) + (x3_is_first * x3))
    , Field.((x1_is_first * y1) + (x2_is_first * y2) + (x3_is_first * y3)) )
end
