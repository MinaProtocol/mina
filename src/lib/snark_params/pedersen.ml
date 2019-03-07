[%%import
"../../config.mlh"]

open Core_kernel
open Snark_bits
open Fold_lib
open Tuple_lib

[%%if
fake_hash]

open Coda_digestif

[%%endif]

module type S = sig
  type curve

  type window_table

  type scalar_field

  module Digest : sig
    type t [@@deriving bin_io, sexp, eq, hash, compare]

    val size_in_bits : int

    val fold : t -> bool Triple.t Fold.t

    val ( = ) : t -> t -> bool

    module Bits : Bits_intf.S with type t := t

    module Snarkable (Impl : Snark_intf.S) :
      Impl.Snarkable.Bits.Lossy
      with type Packed.var = Impl.Field.Var.t
       and type Packed.value = Impl.Field.t
       and type Unpacked.value = Impl.Field.t
  end

  module Params : sig
    type t = curve array
  end

  module State : sig
    [%%if fake_hash]

    type t = {triples_consumed: int; acc: curve; ctx: Digestif.SHA256.ctx}

    [%%else]

    type t

    [%%endif]

    val create : ?triples_consumed:int -> ?init:curve -> unit -> t

    val update_fold_chunked : t -> bool Triple.t Fold.t -> t

    val update_fold_unchunked : t -> bool Triple.t Fold.t -> t

    val update_fold : t -> bool Triple.t Fold.t -> t

    val set_chunked_fold : bool -> unit

    val digest : t -> Digest.t

    val triples_consumed : t -> int

    val acc : t -> curve

    val salt : string -> t

    val acc_of_sections :
         [`Acc of curve * int | `Data of bool Triple.t Fold.t | `Skip of int]
         list
      -> curve
  end

  val hash_fold : State.t -> bool Triple.t Fold.t -> State.t

  val digest_fold : State.t -> bool Triple.t Fold.t -> Digest.t
end

module Make (Inputs : Pedersen_inputs_intf.S) :
  S
  with type curve := Inputs.Curve.t
   and type window_table := Inputs.Curve.Window_table.t
   and type scalar_field := Inputs.Scalar_field.t
   and type Digest.t = Inputs.Field.t = struct
  open Inputs

  module Digest = struct
    type t = Field.t [@@deriving sexp, bin_io, compare, hash, eq]

    let size_in_bits = Field.size_in_bits

    let ( = ) = equal

    module Snarkable = Bits.Snarkable.Field
    module Bits = Bits.Make_field (Field) (Bigint)

    let fold t = Fold.group3 ~default:false (Bits.fold t)
  end

  let scalar_size_in_triples =
    (* value is an integer c such that

       4 * 2^{4*c} / 15 < (Scalar_field.size - 1) / 2

       taking lgs yields

       2 + 4c - lg(15) <= Scalar_field.size_in_bits - 1
       4c <= Scalar_field.size_in_bits + lg(15) - 3

       lg(15) ~= 3.9 > 3  so if
       4c <= Scalar_field.size_in_bits
       then
       4c <= Scalar_field.size_in_bits + lg(15) - 3

       Hence we can take c = floor(Scalar_field.size_in_bits / 4)
    *)
    Scalar_field.size_in_bits / 4

  module Params = struct
    type t = Curve.t array
  end

  module State = struct
    [%%if
    fake_hash]

    type t = {triples_consumed: int; acc: Curve.t; ctx: Digestif.SHA256.ctx}

    let create ?(triples_consumed = 0) ?(init = Curve.zero) () =
      {acc= init; triples_consumed; ctx= Digestif.SHA256.init ()}

    let update_fold (t : t) (fold : bool Triple.t Fold.t) =
      O1trace.measure "pedersen fold" (fun () ->
          let params = Inputs.params in
          let max_num_params = Array.length params in
          (* As much space as we could need: we can only have up to [length params] triples before we overflow that, and each triple is packed into a single byte *)
          let bs = Bigstring.init max_num_params ~f:(fun _ -> '0') in
          let triples_consumed_here =
            fold.fold ~init:0 ~f:(fun i (b0, b1, b2) ->
                Bigstring.set_uint8 bs ~pos:i
                  ((4 * Bool.to_int b2) + (2 * Bool.to_int b1) + Bool.to_int b0) ;
                i + 1 )
          in
          let ctx = Digestif.SHA256.feed_bigstring t.ctx bs in
          let bit_at s i =
            (Char.to_int s.[i / 8] lsr (7 - (i % 8))) land 1 = 1
          in
          let dgst = (Digestif.SHA256.get ctx :> string) in
          O1trace.trace_event "about to make field element" ;
          let bits = List.init 256 ~f:(bit_at dgst) in
          let x = Field.project bits in
          { t with
            acc= Curve.point_near_x x
          ; ctx
          ; triples_consumed= t.triples_consumed + triples_consumed_here } )

    let set_chunked_fold _ = ()

    let update_fold_chunked = update_fold

    let update_fold_unchunked = update_fold

    let acc t = t.acc

    [%%else]

    type t =
      { acc: Curve.t
      ; mutable acc_finalized: Curve.t option
      ; scalar_chunks_consumed: int
      ; scalar_triples_consumed: int
      ; scalar_coefficient: Scalar_field.t
      ; scalar_acc: Scalar_field.t }

    let sixteen_times ~add x =
      let ( + ) = add in
      let x2 = x + x in
      let x4 = x2 + x2 in
      let x8 = x4 + x4 in
      x8 + x8

    let%test_unit "sixteen_times" =
      let module F = struct
        include Scalar_field

        let compare x y = if equal x y then 0 else 1
      end in
      let x = F.random () in
      [%test_eq: F.t] F.(mul (of_int 16) x) (sixteen_times ~add:F.add x)

    let local_function ~negate ~add (sign, b0, b1) c =
      let ( + ) = add in
      let x =
        match Four.of_bits_lsb (b0, b1) with
        | Zero -> c
        | One -> c + c
        | Two -> c + c + c
        | Three -> c + c + c + c
      in
      if sign then negate x else x

    let update ~(scale : int -> Scalar_field.t -> Curve.t) (t : t) triple =
      let term =
        local_function ~negate:Scalar_field.negate ~add:Scalar_field.add triple
          t.scalar_coefficient
      in
      let new_scalar_acc = Scalar_field.add t.scalar_acc term in
      let ( acc
          , scalar_acc
          , scalar_chunks_consumed
          , scalar_triples_consumed
          , scalar_coefficient ) =
        let chunk_complete =
          t.scalar_triples_consumed = scalar_size_in_triples - 1
        in
        if chunk_complete then
          ( Curve.(add t.acc (scale t.scalar_chunks_consumed new_scalar_acc))
          , Scalar_field.zero
          , t.scalar_chunks_consumed + 1
          , 0
          , Scalar_field.one )
        else
          ( t.acc
          , new_scalar_acc
          , t.scalar_chunks_consumed
          , t.scalar_triples_consumed + 1
          , sixteen_times ~add:Scalar_field.add t.scalar_coefficient )
      in
      { acc
      ; acc_finalized= None
      ; scalar_acc
      ; scalar_chunks_consumed
      ; scalar_triples_consumed
      ; scalar_coefficient }

    let pow2 k =
      let rec go acc i =
        if i = 0 then acc else go (Scalar_field.add acc acc) (i - 1)
      in
      go Scalar_field.one k

    let create ?(triples_consumed = 0) ?(init = Curve.zero) () =
      let scalar_triples_consumed =
        triples_consumed mod scalar_size_in_triples
      in
      let scalar_coefficient = pow2 (4 * scalar_triples_consumed) in
      { acc= init
      ; acc_finalized= None
      ; scalar_acc= Scalar_field.zero
      ; scalar_chunks_consumed= triples_consumed / scalar_size_in_triples
      ; scalar_triples_consumed
      ; scalar_coefficient }

    let update_fold_chunked t0 (fold : bool Triple.t Fold.t) : t =
      O1trace.measure "pedersen fold" (fun () ->
          let tables = Lazy.force Inputs.window_tables in
          let scale i x = Curve.Window_table.scale_field tables.(i) x in
          fold.fold ~f:(update ~scale) ~init:t0 )

    let update_fold_unchunked (t0 : t) (fold : bool Triple.t Fold.t) =
      let params = Inputs.params in
      let scale i x = Curve.scale_field params.(i) x in
      fold.fold ~f:(update ~scale) ~init:t0

    let update_fold_fun_ref = ref update_fold_unchunked

    let set_chunked_fold b =
      if b then update_fold_fun_ref := update_fold_chunked
      else update_fold_fun_ref := update_fold_unchunked

    let update_fold t fold = !update_fold_fun_ref t fold

    let acc t =
      match t.acc_finalized with
      | Some acc -> acc
      | None ->
          let result =
            let scale =
              if Lazy.is_val Inputs.window_tables then fun i x ->
                Curve.Window_table.scale_field
                  (Lazy.force Inputs.window_tables).(i)
                  x
              else fun i x -> Curve.scale_field Inputs.params.(i) x
            in
            if t.scalar_triples_consumed > 0 then
              Curve.add t.acc (scale t.scalar_chunks_consumed t.scalar_acc)
            else t.acc
          in
          t.acc_finalized <- Some result ;
          result

    let triples_consumed t =
      t.scalar_triples_consumed
      + (scalar_size_in_triples * t.scalar_chunks_consumed)

    [%%endif]

    let digest t =
      let x, _y = Curve.to_affine_coordinates (acc t) in
      x

    let acc_of_sections =
      let module Acc = struct
        type t = {triples_consumed: int; acc: Curve.t}
      end in
      let get_acc = acc in
      fun secs ->
        let open Acc in
        let {acc; _} =
          List.fold secs ~init:{triples_consumed= 0; acc= Curve.zero}
            ~f:(fun acc sec ->
              match sec with
              | `Acc (acc', n) ->
                  { acc= Curve.add acc' acc.acc
                  ; triples_consumed= acc.triples_consumed + n }
              | `Skip n -> {acc with triples_consumed= acc.triples_consumed + n}
              | `Data ts ->
                  let t =
                    update_fold
                      (create ~triples_consumed:acc.triples_consumed
                         ~init:acc.acc ())
                      ts
                  in
                  { acc= get_acc t
                  ; triples_consumed=
                      t.scalar_triples_consumed
                      + (scalar_size_in_triples * t.scalar_chunks_consumed) }
          )
        in
        acc

    let gen_input max_length =
      let open Quickcheck.Generator in
      let open Let_syntax in
      let%bind n = Int.gen_incl 0 max_length in
      List.gen_with_length n (tuple3 bool bool bool)

    let%test_unit "scalar_acc computed correctly" =
      let scalar_of_triples ts =
        List.mapi ts ~f:(fun i t ->
            Scalar_field.mul
              (local_function ~negate:Scalar_field.negate ~add:Scalar_field.add
                 t Scalar_field.one)
              (pow2 (4 * i)) )
        |> List.fold ~f:Scalar_field.add ~init:Scalar_field.zero
      in
      Quickcheck.test ~trials:20 (gen_input 500) ~f:(fun input ->
          let t = update_fold (create ()) (Fold.of_list input) in
          let n = List.length input in
          [%test_eq: int] t.scalar_chunks_consumed (n / scalar_size_in_triples) ;
          [%test_eq: int] t.scalar_triples_consumed
            (n mod scalar_size_in_triples) ;
          let remainder =
            List.drop input (scalar_size_in_triples * t.scalar_chunks_consumed)
          in
          let module F = struct
            include Scalar_field

            let compare x y = if equal x y then 0 else 1
          end in
          [%test_eq: F.t] t.scalar_acc (scalar_of_triples remainder) )

    let%test_unit "params-windows consistency" =
      let tables = Lazy.force Inputs.window_tables in
      let module G = struct
        include Curve

        let compare x y = if equal x y then 0 else 1
      end in
      Array.iter2_exn tables Inputs.params ~f:(fun t p ->
          [%test_eq: G.t] p (G.Window_table.scale_field t Scalar_field.one) )

    let%test_unit "chunked-is-correct" =
      let max_length = 300 in
      let naive_params =
        let scalars_needed =
          (max_length + scalar_size_in_triples - 1) / scalar_size_in_triples
        in
        List.init scalars_needed ~f:(fun i ->
            (*
          let rec go pt acc k =
            if k = scalar_size_in_triples
            then List.rev acc
            else go
                  (sixteen_times ~add:Curve.add pt) (pt :: acc) ( k + 1)
          in
             go Inputs.params.(i) [] 0 *)
            List.init scalar_size_in_triples ~f:(fun j ->
                Curve.scale_field Inputs.params.(i) (pow2 (4 * j)) ) )
        |> List.concat |> Array.of_list
      in
      let naive triples =
        List.foldi triples ~init:Curve.zero ~f:(fun i acc triple ->
            Curve.add acc
              (local_function ~negate:Curve.negate ~add:Curve.add triple
                 naive_params.(i)) )
      in
      let gen =
        let open Quickcheck.Generator in
        let open Let_syntax in
        let%bind n = Int.gen_incl 0 max_length in
        let n = (0 * n) + 1 in
        List.gen_with_length n (tuple3 bool bool bool)
      in
      let module G = struct
        include Curve

        let compare x y = if equal x y then 0 else 1
      end in
      Quickcheck.test gen ~f:(fun ts ->
          [%test_eq: G.t] (naive ts)
            (acc (update_fold_chunked (create ()) (Fold.of_list ts))) )

    let salt s = update_fold_unchunked (create ()) (Fold.string_triples s)
  end

  let hash_fold s fold = State.update_fold s fold

  let digest_fold s fold = State.digest (hash_fold s fold)
end
