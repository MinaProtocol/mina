(* Points on elliptic curves over finite fields by M. SKALBA
 * https://www.impan.pl/pl/wydawnictwa/czasopisma-i-serie-wydawnicze/acta-arithmetica/all/117/3/82159/points-on-elliptic-curves-over-finite-fields
 *
 * Thm 1.
 * have f(X1)f(X2)f(X3) = U^2 => at least one of f(X1), f(X2) or f(X3) 
 * is square. Take that Xi as the x coordinate and solve for y to 
 * find a point on the curve.
 *
 * Thm 2.
 * if we take map(t) = (Xj(t^2), sqrt(f(Xj(t^2)),
 * with j = min{1 <= i <= 3 | f(Xi(t^2)) in F_q^2}, then map(t)
 * is well defined for at least |T| - 25 values of t and |Im(map| > (|T|-25)/26
 *)

open Core

module type Field_intf = sig
  type t

  val ( + ) : t -> t -> t

  val ( * ) : t -> t -> t

  val ( / ) : t -> t -> t

  val t_of_sexp : Sexp.t -> t

  val of_int : int -> t

  val one : t

  val zero : t

  val negate : t -> t
end

module type Unchecked_field_intf = sig
  include Field_intf

  val sqrt : t -> t

  val equal : t -> t -> bool

  val is_square : t -> bool

  val sexp_of_t : t -> Sexp.t
end

module Intf (F : sig
  type t
end) =
struct
  module type S = sig
    val to_group : F.t -> F.t * F.t
  end
end

module Make_group_map
    (F : Field_intf) (Params : sig
        val a : F.t

        val b : F.t
    end) =
struct
  module Hash_key = struct
    module T = struct
      type t = int * int [@@deriving compare, hash, sexp]
    end

    include T
    include Comparable.Make (T)
    include Hashable.Make (T)
  end

  let field_of_string s =
    if s.[0] = '-' then
      let s' = String.sub s ~pos:1 ~len:(String.length s - 1) in
      F.negate (Sexp.of_string_conv_exn s' F.t_of_sexp)
    else Sexp.of_string_conv_exn s F.t_of_sexp

  let field_map = List.map ~f:(fun (a, b) -> (a, field_of_string b))

  let n1tbl =
    Hashtbl.of_alist_exn
      (module Hash_key)
      (field_map
         [ ((0, 0), "212")
         ; ((0, 1), "-208")
         ; ((3, 0), "-161568")
         ; ((0, 2), "-264")
         ; ((3, 1), "441408")
         ; ((0, 3), "304")
         ; ((6, 0), "-92765376")
         ; ((3, 2), "-127776")
         ; ((0, 4), "-44") ])

  let d1tbl =
    Hashtbl.of_alist_exn
      (module Hash_key)
      (field_map
         [ ((0, 0), "-1")
         ; ((0, 1), "5")
         ; ((3, 0), "10536")
         ; ((0, 2), "-10")
         ; ((3, 1), "9480")
         ; ((0, 3), "10")
         ; ((6, 0), "4024944")
         ; ((3, 2), "-4488")
         ; ((0, 4), "-5")
         ; ((6, 1), "2108304")
         ; ((3, 3), "2904")
         ; ((0, 5), "1") ])

  let n2tbl =
    Hashtbl.of_alist_exn
      (module Hash_key)
      (field_map
         [ ((0, 0), "-1")
         ; ((0, 1), "6")
         ; ((3, 0), "-4356")
         ; ((0, 2), "-15")
         ; ((3, 1), "-424944")
         ; ((0, 3), "20")
         ; ((6, 0), "-6324912")
         ; ((3, 2), "-26136")
         ; ((0, 4), "-15")
         ; ((6, 1), "12649824")
         ; ((3, 3), "17424")
         ; ((0, 5), "6")
         ; ((9, 0), "-3061257408")
         ; ((6, 2), "-6324912")
         ; ((3, 4), "-4356")
         ; ((0, 6), "-6") ])

  let d2tbl =
    Hashtbl.of_alist_exn
      (module Hash_key)
      (field_map
         [ ((0, 0), "1")
         ; ((0, 1), "-4")
         ; ((3, 0), "5976")
         ; ((0, 2), "6")
         ; ((3, 1), "-5808")
         ; ((0, 3), "-4")
         ; ((6, 0), "2108304")
         ; ((3, 2), "2904")
         ; ((0, 4), "1") ])

  let n3tbl =
    Hashtbl.of_alist_exn
      (module Hash_key)
      (field_map
         [ ((0, 1), "1")
         ; ((3, 0), "0")
         ; ((0, 2), "-15")
         ; ((3, 1), "-31608")
         ; ((0, 3), "105")
         ; ((6, 0), "-2382032")
         ; ((3, 2), "287640")
         ; ((0, 4), "-455")
         ; ((6, 1), "327958320")
         ; ((3, 3), "-1124496")
         ; ((0, 5), "1365")
         ; ((9, 0), "5446134144")
         ; ((6, 2), "-949378416")
         ; ((3, 4), "2369808")
         ; ((0, 6), "-3003")
         ; ((9, 1), "-940697745408")
         ; ((6, 3), "-185899568")
         ; ((3, 5), "-2531880")
         ; ((0, 7), "5005")
         ; ((2, 0), "-1023635467008")
         ; ((9, 2), "-4041852271488")
         ; ((6, 4), "3844905120")
         ; ((3, 6), "-14904")
         ; ((0, 8), "6435")
         ; ((2, 1), "-1271178606627072")
         ; ((9, 3), "-557953136640")
         ; ((6, 5), "-5637798432")
         ; ((3, 7), "4402080")
         ; ((0, 9), "6435")
         ; ((5, 0), "-3711755775062016")
         ; ((2, 2), "-3365703371771136")
         ; ((9, 4), "1809225932544")
         ; ((6, 6), "2558454048")
         ; ((3, 8), "-7401888")
         ; ((0, 10), "-5005")
         ; ((15, 1), "-502999567986972672")
         ; ((12, 3), "-924766944152832")
         ; ((9, 5), "-3401013749760")
         ; ((6, 7), "1784103840")
         ; ((3, 9), "7013304")
         ; ((0, 11), "3003")
         ; ((18, 0), "447914759358173184")
         ; ((15, 2), "-981669643253544960")
         ; ((12, 4), "329477012308224")
         ; ((9, 6), "913161021696")
         ; ((6, 8), "-3372070032")
         ; ((3, 10), "-4408920")
         ; ((0, 12), "-1365")
         ; ((18, 1), "-73786028437373497344")
         ; ((15, 3), "-459570852044992512")
         ; ((12, 5), "-977913669655296")
         ; ((9, 7), "439245379584")
         ; ((6, 9), "2438317040")
         ; ((3, 11), "1904112")
         ; ((0, 13), "455")
         ; ((21, 0), "1042769766152244658176")
         ; ((18, 2), "-84332284536876355584")
         ; ((15, 4), "5961076345331712")
         ; ((12, 6), "-43484326592256")
         ; ((9, 8), "-707241693312")
         ; ((6, 10), "-1030036656")
         ; ((3, 12), "-555120")
         ; ((0, 14), "-105")
         ; ((21, 1), "-2848874263082603053056")
         ; ((18, 3), "-63482146340076490752")
         ; ((15, 5), "-101522561076541440")
         ; ((12, 7), "69490543161600")
         ; ((9, 9), "280657428480")
         ; ((6, 11), "255430032")
         ; ((3, 13), "100584")
         ; ((0, 15), "15")
         ; ((24, 0), "199571139166470771769344")
         ; ((21, 2), "824674128787069304832")
         ; ((18, 4), "-7951403445605351424")
         ; ((15, 6), "-37420516674680832")
         ; ((12, 8), "-66000709716480")
         ; ((9, 10), "-61039617408")
         ; ((6, 12), "-31603264")
         ; ((3, 14), "-8712")
         ; ((1, 16), "-1") ])

  let d31tbl =
    Hashtbl.of_alist_exn
      (module Hash_key)
      (field_map
         [ ((0, 0), "-1")
         ; ((0, 1), "5")
         ; ((3, 0), "10536")
         ; ((0, 2), "-10")
         ; ((3, 1), "9480")
         ; ((0, 3), "10")
         ; ((6, 0), "4024944")
         ; ((3, 2), "-4488")
         ; ((0, 4), "-5")
         ; ((6, 1), "2108304")
         ; ((3, 3), "2904")
         ; ((0, 5), "1") ])

  let d32tbl =
    Hashtbl.of_alist_exn
      (module Hash_key)
      (field_map
         [ ((0, 0), "1")
         ; ((0, 1), "-10")
         ; ((3, 0), "12636")
         ; ((0, 2), "45")
         ; ((3, 1), "20256")
         ; ((0, 3), "-120")
         ; ((6, 0), "51578784")
         ; ((3, 2), "-158448")
         ; ((0, 4), "210")
         ; ((6, 1), "426572352")
         ; ((3, 3), "149472")
         ; ((0, 5), "-252")
         ; ((9, 0), "74892394368")
         ; ((6, 2), "-178487712")
         ; ((3, 4), "146472")
         ; ((0, 6), "210")
         ; ((9, 1), "42705805824")
         ; ((6, 3), "-194173056")
         ; ((3, 5), "-328224")
         ; ((0, 7), "-120")
         ; ((12, 0), "38682048607488")
         ; ((9, 2), "217678171392")
         ; ((6, 4), "339663456")
         ; ((3, 6), "208656")
         ; ((0, 8), "45")
         ; ((12, 1), "-44449457564160")
         ; ((9, 3), "-122450296320")
         ; ((6, 5), "-126498240")
         ; ((3, 7), "-58080")
         ; ((0, 9), "10")
         ; ((15, 0), "6454061238316032")
         ; ((12, 2), "22224728782080")
         ; ((9, 4), "30612574080")
         ; ((6, 6), "21083040")
         ; ((3, 8), "7260")
         ; ((0, 10), "1") ])

  (* for v, k, powers produces v^0, v^1, ... v^k *)
  let powers v k =
    let rec make_powers acc prev x =
      if x = k then Array.of_list_rev acc
      else
        let prev' = F.(prev * v) in
        let acc' = prev' :: acc in
        make_powers acc' prev' (x + 1)
    in
    make_powers [F.one] F.one 0

  let mul a b tbl =
    (* highest power of A is 24, of B is 16 *)
    let a_powers = powers Params.a 24 and b_powers = powers Params.b 16 in
    F.(Hashtbl.find_exn tbl (a, b) * a_powers.(a) * b_powers.(b))

  let t_mul sum t_power t_powers = F.(sum * t_powers.(t_power))

  (* given j, iter_a starts with the highest value of a possible
   * that satisfies either 2a + 3b = 3j (if in case 0)
   * or 2a + 3b = 3j + 3 (if in case 1)
   * then solves for b using b = 3j - 2a / 3 (if in case 0)
   * or b = 3 + 3j - 2a / 3 (if in case 1)
   * then we decrement a and solve for b again, until we hit a = 0
   * and return what is accumulated (which is A^a . B^b (with y^2 = x^3 + 3A + B)
   * pulling from the table of A and B powers) for each
   * a, b st 2a + 3b = 3j (or each a, b st 2a + 3b = 3j + 3 if in case 1)
   *)

  let iter_a s j tbl =
    let rec go ~a ~acc ~s ~j ~tbl =
      (* if s = 0 then 2a + 3b = 3j -> b = 3j - 2a / 3 *)
      (* if s = 1 then 2a + 3b = 3j + 3 -> b = 3 + 3j - 2a / 3 *)
      let b =
        if s = 0 then ((3 * j) - (2 * a)) / 3
        else if s = 1 then (3 + (3 * j) - (2 * a)) / 3
        else failwith "case specified doesn't exist"
      in
      let acc' =
        if s = 0 && (2 * a) + (3 * b) = 3 * j then F.( + ) acc (mul a b tbl)
        else if s = 1 && (2 * a) + (3 * b) = (3 * j) + 3 then
          F.( + ) acc (mul a b tbl)
        else acc
      in
      (* start with a_max and decrement until a = 0 *)
      if a > 0 then
        let a' = a - 1 in
        go ~a:a' ~acc:acc' ~s ~j ~tbl
      else acc'
    in
    (* this is defining a as the max value it can take
     * for 2a + 3b = 3j, max_a = 3j/2,
     * for 2a + 3b = 3j + 3, max a = (3j + 3)/2 *)
    let a =
      if s = 0 then 3 * j / 2
      else if s = 1 then ((3 * j) + 3) / 2
      else failwith "case specified doesn't exist"
    in
    go ~a ~acc:F.zero ~s ~j ~tbl

  let iter_j s max t_powers tbl =
    let rec go ~j ~acc ~s ~max ~t_powers ~tbl =
      let acc' = iter_a s j tbl in
      let acc'' = F.( + ) acc (t_mul acc' j t_powers) in
      if j < max then
        let j' = j + 1 in
        go ~j:j' ~acc:acc'' ~s ~max ~t_powers ~tbl
      else acc''
    in
    go ~j:0 ~acc:F.zero ~s ~max ~t_powers ~tbl

  (* Xi(t) = Ni(t)/Di(t)  for i = 1, 2, 3
   * N1(t) = A^2 . t . sum from j = 0 to j = 4 of [
   *    sum for 2a+3b=3j of ( n1_(a,b) A^a . B^b ) . t^j ]
   * D1(t) = sum from j = 0 to j = 5 of [
   *    sum for 2a+3b=3j of ( d1_(a,b) A^a . B^b ) . t^j ]
   *)
  let make_x1 t =
    let t_powers = powers t 15 in
    let nt = iter_j 0 4 t_powers n1tbl in
    let dt = iter_j 0 5 t_powers d1tbl in
    F.(Params.a * t_mul (F.of_int 2) 1 t_powers * nt / dt)

  (* N2(t) = sum from j = 0 to j = 6 of [
   *    sum for 2a+3b=3j of ( n2_(a,b) A^a . B^b ) . t^j ]
   * D2(t) = 144At . sum from j = 0 to j = 4 of [
   *    sum for 2a+3b=3j of ( d2_(a,b) A^a . B^b ) . t^j ]
   *)
  let make_x2 t =
    let t_powers = powers t 15 in
    let nt = iter_j 0 6 t_powers n2tbl in
    let dt = iter_j 0 4 t_powers d2tbl in
    F.(nt / (t_mul (F.of_int 144 * Params.a) 1 t_powers * dt))

  (* N3(t) = sum from j = 0 to j = 15 of [
   *    sum for 2a+3b=3j+3 of ( n3_(a,b) A^a . B^b ) . t^j ]
   * D3(t) = A . sum from j = 0 to j = 5 of [
   *    sum for 2a+3b=3j of ( d31_(a,b) A^a . B^b ) . t^j ]
   *    .
   *    sum from j = 0 to j = 10 of [
   *    sum for 2a+3b=3j of ( d32_(a,b) A^a . B^b ) . t^j ]
   *)
  let make_x3 t =
    let t_powers = powers t 15 in
    let nt = iter_j 1 15 t_powers n3tbl in
    let dt1 = iter_j 0 5 t_powers d31tbl in
    let dt2 = iter_j 0 10 t_powers d32tbl in
    F.(nt / (Params.a * dt1 * dt2))
end

module Make_unchecked
    (F : Unchecked_field_intf) (Params : sig
        val a : F.t

        val b : F.t
    end) =
struct
  include Make_group_map (F) (Params)

  let try_decode x =
    let f x = F.((x * x * x) + (Params.a * x) + Params.b) in
    let y = f x in
    if F.is_square y then Some (x, F.sqrt y) else None

  (** NOTE : in case all three of f x1, f x2, f x3 are square
   * and a malicious prover submits the wrong z to sqrt_flagged,
   * meaning it returns 0 instead of 1, the adversary gets 3 chances
   * rather than one. This is solved by ensuring external verifiers                      
   * only accept proofs that use the *first* square in f x1, f x2, f x3                  
   *)
  let to_group t =
    List.find_map [make_x1; make_x2; make_x3] ~f:(fun mk -> try_decode (mk t))
    |> Option.value_exn
end

let%test_unit "foo" =
  let module S = Snarky.Snark.Make (Snarky.Backends.Mnt6.Default) in
  let module C = struct
    type t = S.Field.t

    let ( + ) = S.Field.add

    let ( * ) = S.Field.mul

    let ( / ) = S.Field.Infix.( / )

    let t_of_sexp = S.Field.t_of_sexp

    let of_int = S.Field.of_int

    let one = S.Field.one

    let zero = S.Field.zero

    let negate = S.Field.negate
  end in
  let module U = struct
    include C

    let equal = S.Field.equal

    let sqrt = S.Field.sqrt

    let is_square = S.Field.is_square

    let sexp_of_t = S.Field.sexp_of_t
  end in
  let module M = Make_unchecked (U) (Snarky.Libsnark.Mnt4.G1.Coefficients) in
  ()
