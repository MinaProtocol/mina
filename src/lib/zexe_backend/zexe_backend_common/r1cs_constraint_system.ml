module type Constraint_matrix_intf = sig
  type field_vector

  type t

  val create : unit -> t

  val append_row : t -> Snarky_bn382.Usize_vector.t -> field_vector -> unit
end

type 'a abc = {a: 'a; b: 'a; c: 'a} [@@deriving sexp]

module Weight = struct
  open Core

  type t = int abc [@@deriving sexp]

  let ( + ) t1 (a, b, c) = {a= t1.a + a; b= t1.b + b; c= t1.c + c}

  let norm {a; b; c} = Int.(max a (max b c))
end

module Triple = struct
  type 'a t = 'a * 'a * 'a
end

module Hash_state = struct
  open Core_kernel
  module H = Digestif.SHA256

  type t = H.ctx

  let digest t = Md5.digest_string H.(to_raw_string (get t))
end

module Hash = Core.Md5

type 'a t =
  { m: 'a abc
  ; mutable hash: Hash_state.t
  ; mutable constraints: int
  ; mutable weight: Weight.t
  ; mutable public_input_size: int
  ; mutable auxiliary_input_size: int }

let digest (t : _ t) = Hash_state.digest t.hash

module Make (Fp : sig
  include Field.S

  val to_bigint_raw_noalloc : t -> Bigint.t
end)
(Mat : Constraint_matrix_intf with type field_vector := Fp.Vector.t) =
struct
  open Core

  module Hash_state = struct
    include Hash_state

    let feed_constraint t (a, b, c) =
      let n = Fp.Bigint.length_in_bytes in
      let buf = Bytes.init (n + 8) ~f:(fun _ -> '\000') in
      let one x t =
        List.fold x ~init:t ~f:(fun acc (x, index) ->
            let limbs = Fp.Bigint.to_ptr (Fp.to_bigint_raw_noalloc x) in
            for i = 0 to n - 1 do
              Bytes.set buf i Ctypes.(!@(limbs +@ i))
            done ;
            for i = 0 to 7 do
              Bytes.set buf (n + i)
                (Char.of_int_exn ((index lsr (8 * i)) land 255))
            done ;
            H.feed_bytes acc buf )
      in
      t |> one a |> one b |> one c

    let empty = H.feed_string H.empty "r1cs_constraint_system"
  end

  type nonrec t = Mat.t t

  let create () =
    { public_input_size= 0
    ; hash= Hash_state.empty
    ; constraints= 0
    ; auxiliary_input_size= 0
    ; weight= {a= 0; b= 0; c= 0}
    ; m= {a= Mat.create (); b= Mat.create (); c= Mat.create ()} }

  (* TODO *)
  let to_json _ = `List []

  let get_auxiliary_input_size t = t.auxiliary_input_size

  let get_primary_input_size t = t.public_input_size

  let set_auxiliary_input_size t x = t.auxiliary_input_size <- x

  let set_primary_input_size t x = t.public_input_size <- x

  let digest = digest

  let finalize = ignore

  let merge_terms xs0 ys0 ~init ~f =
    let rec go acc xs ys =
      match (xs, ys) with
      | [], [] ->
          acc
      | [], (y, iy) :: ys ->
          go (f acc iy (`Right y)) [] ys
      | (x, ix) :: xs, [] ->
          go (f acc ix (`Left x)) xs []
      | (x, ix) :: xs', (y, iy) :: ys' ->
          if ix < iy then go (f acc ix (`Left x)) xs' ys
          else if ix = iy then go (f acc ix (`Both (x, y))) xs' ys'
          else go (f acc iy (`Right y)) xs ys'
    in
    go init xs0 ys0

  let sub_terms xs ys =
    merge_terms ~init:[]
      ~f:(fun acc i t ->
        let c =
          match t with
          | `Left x ->
              x
          | `Right y ->
              Fp.negate y
          | `Both (x, y) ->
              Fp.sub x y
        in
        (c, i) :: acc )
      xs ys
    |> List.rev
    |> List.filter ~f:(fun (c, _) -> not (Fp.equal c Fp.zero))

  let decr_constant_term = function
    | (c, 0) :: terms ->
        (Fp.(sub c one), 0) :: terms
    | (_, _) :: _ as terms ->
        (Fp.(sub zero one), 0) :: terms
    | [] ->
        [(Fp.(sub zero one), 0)]

  let canonicalize x =
    let c, terms =
      Fp.(
        Snarky.Cvar.to_constant_and_terms ~add ~mul ~zero:(of_int 0) ~equal
          ~one:(of_int 1))
        x
    in
    let terms =
      List.sort terms ~compare:(fun (_, i) (_, j) -> Int.compare i j)
    in
    let has_constant_term = Option.is_some c in
    let terms = match c with None -> terms | Some c -> (c, 0) :: terms in
    match terms with
    | [] ->
        Some ([], 0, false)
    | (c0, i0) :: terms ->
        let acc, i, ts, n =
          Sequence.of_list terms
          |> Sequence.fold ~init:(c0, i0, [], 0)
               ~f:(fun (acc, i, ts, n) (c, j) ->
                 if Int.equal i j then (Fp.add acc c, i, ts, n)
                 else (c, j, (acc, i) :: ts, n + 1) )
        in
        Some (List.rev ((acc, i) :: ts), n + 1, has_constant_term)

  let _choose_best base opts terms =
    let ( +. ) = Weight.( + ) in
    let best f xs =
      List.min_elt xs ~compare:(fun (_, wt1) (_, wt2) ->
          Int.compare
            (Weight.norm (base +. f wt1))
            (Weight.norm (base +. f wt2)) )
      |> Option.value_exn
    in
    let swap_ab (a, b, c) = (b, a, c) in
    let best_unswapped, d_unswapped = best Fn.id opts in
    let best_swapped, d_swapped = best swap_ab opts in
    let w_unswapped, w_swapped = (base +. d_unswapped, base +. d_swapped) in
    if Weight.(norm w_swapped < norm w_unswapped) then
      (swap_ab (terms best_swapped), w_swapped)
    else (terms best_unswapped, w_unswapped)

  let choose_best base opts terms =
    let ( +. ) = Weight.( + ) in
    let best xs =
      Sequence.min_elt xs ~compare:(fun (_, wt1) (_, wt2) ->
          Int.compare (Weight.norm (base +. wt1)) (Weight.norm (base +. wt2))
      )
      |> Option.value_exn
    in
    let swap_ab (a, b, c) = (b, a, c) in
    let opts =
      let s = Sequence.of_list opts in
      Sequence.append
        (Sequence.map s ~f:(fun (x, w) -> ((`unswapped, x), w)))
        (Sequence.map s ~f:(fun (x, w) -> ((`swapped, x), swap_ab w)))
    in
    let (swap, best), delta = best opts in
    let terms =
      let terms = terms best in
      match swap with `unswapped -> terms | `swapped -> swap_ab terms
    in
    (terms, base +. delta)

  let add_r1cs t (a, b, c) =
    let append m v =
      let indices = Snarky_bn382.Usize_vector.create () in
      let coeffs = Fp.Vector.create () in
      List.iter v ~f:(fun (x, i) ->
          Snarky_bn382.Usize_vector.emplace_back indices
            (Unsigned.Size_t.of_int i) ;
          Fp.Vector.emplace_back coeffs x ) ;
      Mat.append_row m indices coeffs ;
      Snarky_bn382.Usize_vector.delete indices ;
      Fp.Vector.delete coeffs
    in
    t.constraints <- t.constraints + 1 ;
    append t.m.a a ;
    append t.m.b b ;
    append t.m.c c

  let add_constraint ?label:_ t
      (constr : Fp.t Snarky.Cvar.t Snarky.Constraint.basic) =
    let var = canonicalize in
    let var_exn t = Option.value_exn (var t) in
    let choose_best opts terms =
      let constr, new_weight = choose_best t.weight opts terms in
      t.hash <- Hash_state.feed_constraint t.hash constr ;
      t.weight <- new_weight ;
      add_r1cs t constr
    in
    let open Snarky.Constraint in
    match constr with
    | Snarky.Constraint.Boolean x ->
        let x, x_weight, x_has_constant_term = var_exn x in
        let x_minus_1_weight =
          x_weight + if x_has_constant_term then 0 else 1
        in
        choose_best
          (* x * x = x
             x * (x - 1) = 0 *)
          [ (`x_x_x, (x_weight, x_weight, x_weight))
          ; (`x_xMinus1_0, (x_weight, x_minus_1_weight, 0)) ]
          (function
            | `x_x_x ->
                (x, x, x)
            | `x_xMinus1_0 ->
                (x, decr_constant_term x, []) )
    | Snarky.Constraint.Equal (x, y) ->
        (* x * 1 = y
           y * 1 = x
           (x - y) * 1 = 0
        *)
        let x_terms, x_weight, _ = var_exn x in
        let y_terms, y_weight, _ = var_exn y in
        let x_minus_y_weight =
          merge_terms ~init:0 ~f:(fun acc _ _ -> acc + 1) x_terms y_terms
        in
        let options =
          [ (`x_1_y, (x_weight, 1, y_weight))
          ; (`y_1_x, (y_weight, 1, x_weight))
          ; (`x_minus_y_1_zero, (x_minus_y_weight, 1, 0)) ]
        in
        let one = [(Fp.one, 0)] in
        choose_best options (function
          | `x_1_y ->
              (x_terms, one, y_terms)
          | `y_1_x ->
              (y_terms, one, x_terms)
          | `x_minus_y_1_zero ->
              (sub_terms x_terms y_terms, one, []) )
    | Snarky.Constraint.Square (x, z) ->
        let x, x_weight, _ = var_exn x in
        let z, z_weight, _ = var_exn z in
        choose_best [((), (x_weight, x_weight, z_weight))] (fun () -> (x, x, z))
    | Snarky.Constraint.R1CS (a, b, c) ->
        let a, a_weight, _ = var_exn a in
        let b, b_weight, _ = var_exn b in
        let c, c_weight, _ = var_exn c in
        choose_best [((), (a_weight, b_weight, c_weight))] (fun () -> (a, b, c))
    | constr ->
        failwithf "Unhandled constraint %s"
          Obj.(extension_name (extension_constructor constr))
          ()
end
