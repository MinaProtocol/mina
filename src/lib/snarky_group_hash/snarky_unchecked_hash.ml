(* Points on elliptic curves over finite fields by M. SKALBA
 * found at eg https://www.impan.pl/pl/wydawnictwa/czasopisma-i-serie-wydawnicze/acta-arithmetica/all/117/3/82159/points-on-elliptic-curves-over-finite-fields
 *
 * Thm 1.
 * have f(X1)f(X2)f(X3) = U^2 => one on f(X1), f(X2) or f(X3) is square.
 * take that Xi as the x coordinate and solve for y ( which can be done
 * because f(Xi) is square :) )
 *
 * Thm 2.
 * if we take map(t) = (Xj(t^2), sqrt(f(Xj(t^2)),
 * with j = min{1 <= i <= 3 | f(Xi(t^2)) in F_q^2}, then map(t)
 * is well defined for at least |T| - 25 values of t and |Im(map| > (|T|-25)/26
 *)

open Core

module Make_snarky_unchecked_hash
  (F : Snarky.Field_intf.Extended)
  (Params : sig
    val a : F.t
    val b : F.t
  end)
  = struct

  module Hash_key = struct
    module T = struct
      type t = int * int [@@deriving compare, hash, sexp]
      let equal = (=)
    end
    include T
    include Comparable.Make(T)
    include Hashable.Make (T)
  end

  let n1_tuples =
    [(0, 0), "212";
     (0, 1), "-208";
     (3, 0), "-161568";
     (0, 2), "-264";
     (3, 1), "441408";
     (0, 3), "304";
     (6, 0), "-92765376";
     (3, 2), "-127776";
     (0, 4), "-44"
    ]

  let d1_tuples =
    [(0, 0), "-1";
     (0, 1), "5";
     (3, 0), "10536";
     (0, 2), "-10";
     (3, 1), "9480";
     (0, 3), "10";
     (6, 0), "4024944";
     (3, 2), "-4488";
     (0, 4), "-5";
     (6, 1), "2108304";
     (3, 3), "2904";
     (0, 5), "1"
    ]

  let n2_tuples =
    [(0, 0), "-1";
     (0, 1), "6";
     (3, 0), "-4356";
     (0, 2), "-15";
     (3, 1), "-424944";
     (0, 3), "20";
     (6, 0), "-6324912";
     (3, 2), "-26136";
     (0, 4), "-15";
     (6, 1), "12649824";
     (3, 3), "17424";
     (0, 5), "6";
     (9, 0), "-3061257408";
     (6, 2), "-6324912";
     (3, 4), "-4356";
     (0, 6), "-6"
    ]

  let d2_tuples =
    [(0, 0), "1";
     (0, 1), "-4";
     (3, 0), "5976";
     (0, 2), "6";
     (3, 1), "-5808";
     (0, 3), "-4";
     (6, 0), "2108304";
     (3, 2), "2904";
     (0, 4), "1"
    ]

  let n3_tuples =
   [(0, 1), "1";
    (3, 0), "0";
    (0, 2), "-15";
    (3, 1), "-31608";
    (0, 3), "105";
    (6, 0), "-2382032";
    (3, 2), "287640";
    (0, 4), "-455";
    (6, 1), "327958320";
    (3, 3), "-1124496";
    (0, 5), "1365";
    (9, 0), "5446134144";
    (6, 2), "-949378416";
    (3, 4), "2369808";
    (0, 6), "-3003";
    (9, 1), "-940697745408";
    (6, 3), "-185899568";
    (3, 5), "-2531880";
    (0, 7), "5005";
    (2, 0), "-1023635467008";
    (9, 2), "-4041852271488";
    (6, 4), "3844905120";
    (3, 6), "-14904";
    (0, 8), "6435";
    (2, 1), "-1271178606627072";
    (9, 3), "-557953136640";
    (6, 5), "-5637798432";
    (3, 7), "4402080";
    (0, 9), "6435";
    (5, 0), "-3711755775062016";
    (2, 2), "-3365703371771136";
    (9, 4), "1809225932544";
    (6, 6), "2558454048";
    (3, 8), "-7401888";
    (0, 10), "-5005";
    (15, 1), "-502999567986972672";
    (12, 3), "-924766944152832";
    (9, 5), "-3401013749760";
    (6, 7), "1784103840";
    (3, 9), "7013304";
    (0, 11), "3003";
    (18, 0), "447914759358173184";
    (15, 2), "-981669643253544960";
    (12, 4), "329477012308224";
    (9, 6), "913161021696";
    (6, 8), "-3372070032";
    (3, 10), "-4408920";
    (0, 12), "-1365";
    (18, 1), "-73786028437373497344";
    (15, 3), "-459570852044992512";
    (12, 5), "-977913669655296";
    (9, 7), "439245379584";
    (6, 9), "2438317040";
    (3, 11), "1904112";
    (0, 13), "455";
    (21, 0), "1042769766152244658176";
    (18, 2), "-84332284536876355584";
    (15, 4), "5961076345331712";
    (12, 6), "-43484326592256";
    (9, 8), "-707241693312";
    (6, 10), "-1030036656";
    (3, 12), "-555120";
    (0, 14), "-105";
    (21, 1), "-2848874263082603053056";
    (18, 3), "-63482146340076490752";
    (15, 5), "-101522561076541440";
    (12, 7), "69490543161600";
    (9, 9), "280657428480";
    (6, 11), "255430032";
    (3, 13), "100584";
    (0, 15), "15";
    (24, 0), "199571139166470771769344";
    (21, 2), "824674128787069304832";
    (18, 4), "-7951403445605351424";
    (15, 6), "-37420516674680832";
    (12, 8), "-66000709716480";
    (9, 10), "-61039617408";
    (6, 12), "-31603264";
    (3, 14), "-8712";
    (1, 16), "-1"
    ]

  let d31_tuples =
    [(0, 0), "-1";
     (0, 1), "5";
     (3, 0), "10536";
     (0, 2), "-10";
     (3, 1), "9480";
     (0, 3), "10";
     (6, 0), "4024944";
     (3, 2), "-4488";
     (0, 4), "-5";
     (6, 1), "2108304";
     (3, 3), "2904";
     (0, 5), "1"
    ]

  let d32_tuples =
    [(0, 0), "1";
     (0, 1), "-10";
     (3, 0), "12636";
     (0, 2), "45";
     (3, 1), "20256";
     (0, 3), "-120";
     (6, 0), "51578784";
     (3, 2), "-158448";
     (0, 4), "210";
     (6, 1), "426572352";
     (3, 3), "149472";
     (0, 5), "-252";
     (9, 0), "74892394368";
     (6, 2), "-178487712";
     (3, 4), "146472";
     (0, 6), "210";
     (9, 1), "42705805824";
     (6, 3), "-194173056";
     (3, 5), "-328224";
     (0, 7), "-120";
     (12, 0), "38682048607488";
     (9, 2), "217678171392";
     (6, 4), "339663456";
     (3, 6), "208656";
     (0, 8), "45";
     (12, 1), "-44449457564160";
     (9, 3), "-122450296320";
     (6, 5), "-126498240";
     (3, 7), "-58080";
     (0, 9), "10";
     (15, 0), "6454061238316032";
     (12, 2), "22224728782080";
     (9, 4), "30612574080";
     (6, 6), "21083040";
     (3, 8), "7260";
     (0, 10), "1"
    ]

  let field_of_string s =
    let s' =
      if s.[0] = '-' then String.sub s ~pos:1 ~len:(String.length s - 1)
      else s
    in
    Sexp.of_string_conv_exn s' F.t_of_sexp

  let field_map = List.map ~f:(fun (a, b) -> (a, field_of_string b))

  let n1tbl = Hashtbl.of_alist_exn (module Hash_key) (field_map n1_tuples)
  let d1tbl = Hashtbl.of_alist_exn (module Hash_key) (field_map d1_tuples)
  let n2tbl = Hashtbl.of_alist_exn (module Hash_key) (field_map n2_tuples)
  let d2tbl = Hashtbl.of_alist_exn (module Hash_key) (field_map d2_tuples)
  let n3tbl = Hashtbl.of_alist_exn (module Hash_key) (field_map n3_tuples)
  let d31tbl = Hashtbl.of_alist_exn (module Hash_key) (field_map d31_tuples)
  let d32tbl = Hashtbl.of_alist_exn (module Hash_key) (field_map d32_tuples)

  let sum (xs : F.t list) =
    List.fold ~init:F.zero ~f:(fun x y -> F.Infix.(x + y)) xs

  let product (xs : F.t list) =
    List.fold ~init:F.one ~f:(fun x y -> F.Infix.(x * y)) xs

  let powers (v : F.t) (k : int) : F.t list =
    let rec make_powers acc prev x =
      if x = k
      then acc
      else
        let prev' = F.Infix.(prev * v) in
        let acc' = prev' :: acc in
        make_powers acc' prev' (x + 1)
    in
    List.rev (make_powers [F.one] F.one 0)

  (* highest power of A is 24, of B is 16 *)
  let a_powers = powers Params.a 24
  let b_powers = powers Params.b 16

  (*
   * Xi(t) = Ni(t)/Di(t)  for i = 1, 2, 3
   * N1(t) = A^2 . t . sum from j = 0 to j = 4 of [
   *    sum for 2a+3b=3j of ( n1_(a,b) A^a . B^b ) . t^j ]
   * D1(t) = sum from j = 0 to j = 5 of [
   *    sum for 2a+3b=3j of ( d1_(a,b) A^a . B^b ) . t^j ]
   *
   * N2(t) = sum from j = 0 to j = 6 of [
   *    sum for 2a+3b=3j of ( n2_(a,b) A^a . B^b ) . t^j ]
   * D2(t) = 144At . sum from j = 0 to j = 4 of [
   *    sum for 2a+3b=3j of ( d2_(a,b) A^a . B^b ) . t^j ]
   *
   * N3(t) = sum from j = 0 to j = 15 of [
   *    sum for 2a+3b=3j+3 of ( n3_(a,b) A^a . B^b ) . t^j ]
   * D3(t) = A . sum from j = 0 to j = 5 of [
   *    sum for 2a+3b=3j of ( d31_(a,b) A^a . B^b ) . t^j ]
   *    .
   *    sum from j = 0 to j = 10 of [
   *    sum for 2a+3b=3j of ( d32_(a,b) A^a . B^b ) . t^j ]
   *)

  let check x =
    match x with
    | Some x -> x
    | None -> failwith "trying to mulitply by index not in powers lists"

  let mul ~a ~b ~tbl =
    F.Infix.(Hashtbl.find_exn tbl (a, b) * check (List.nth a_powers a) * check (List.nth b_powers b))

  let t_mul (sum : F.t) (t_power : int) (t_powers : F.t list) =
    F.Infix.(sum * check (List.nth t_powers t_power))

  let rec iter_a s a j acc tbl =
    (* 2a + 3b = 3j -> b = 3j - 2a / 3 *)
    (* 2a + 3b = 3j + 3 -> b = 3 + 3j - 2a / 3 *)
    let b = if s = 0 then (3*j - 2*a)/3 else (3 + 3*j - 2*a)/3 in
    let acc' = F.Infix.(acc + mul ~a ~b ~tbl) in
    (* start with a_max and decrement until a = 0 *)
    if a > 0 then
      let a' = a - 1 in
      iter_a s a' j acc' tbl
    else acc'

  let rec iter_j s j max acc t_powers tbl =
    let a = if s = 0 then 3*j/2 else (3*j + 3)/2 in
      let acc' = iter_a s a j acc tbl in
      let acc'' = t_mul acc' j t_powers in
      if j < max then let j' = j + 1 in iter_j s j' max acc'' t_powers tbl
      else acc''

  let make_sum i t_var =
    let t_powers = powers t_var 15 in
    let j = 0 and acc = F.zero in
    match i with
    | 1 -> let nt = iter_j 0 j 4 acc t_powers n1tbl in
      let dt = iter_j 0 j 5 acc t_powers d1tbl in
      F.Infix.( (Params.a * (t_mul (F.of_int 2) 1 t_powers)) * nt / dt )
    | 2 -> let nt = iter_j 0 j 6 acc t_powers n2tbl in
      let dt = iter_j 0 j 4 acc t_powers d2tbl in
      F.Infix.( nt / (( t_mul ((F.of_int 144) * Params.a) 1 t_powers ) * dt) )
    | 3 -> let nt = iter_j 1 j 15 acc t_powers n3tbl in
      let dt1 = iter_j 0 j 5 acc t_powers d31tbl in
      let dt2 = iter_j 0 j 10 acc t_powers d32tbl in
      F.Infix.(nt / (Params.a * dt1 * dt2) )
    | _ -> failwith "i supplied that no Xi(t) exists for"

end
