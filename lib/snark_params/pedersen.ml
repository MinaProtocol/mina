open Core_kernel
open Snark_bits
open Pedersen_types

module type S = sig
  type curve

  type ('s, 'b) fold = init:'s -> f:('s -> 'b -> 's) -> 's
  
  module Digest : sig
    type t [@@deriving bin_io, sexp, eq]

    val size_in_bits : int

    val ( = ) : t -> t -> bool

    module Bits : Bits_intf.S with type t := t

    module Snarkable (Impl : Snark_intf.S) :
      Impl.Snarkable.Bits.Lossy
      with type Packed.var = Impl.Field.Checked.t
       and type Packed.value = Impl.Field.t
       and type Unpacked.value = Impl.Field.t
  end

  module Bits_params : sig
    type t = curve array

    val random : max_input_length:int -> t
  end

  module Bits_state : sig
    type t = {bits_consumed: int; acc: curve; params: Bits_params.t}

    val create : ?bits_consumed:int -> ?init:curve -> Bits_params.t -> t

    val update_bit_bigstring : t -> Bigstring.t -> t

    val update_bit_string : t -> string -> t

    val update_bit_fold : t -> ((curve * int), bool) fold -> t

    val update_iter : t -> (f:(bool -> unit) -> unit) -> t

    val digest : t -> Digest.t

    val salt : Bits_params.t -> string -> t
  end

  val hash_bit_fold : Bits_state.t -> ((curve * int), bool) fold -> Bits_state.t

  val digest_bit_fold : Bits_state.t -> ((curve * int), bool) fold -> Digest.t


  module Params : sig
    type t = curve Quadruple.t array

    val of_curve : curve -> curve Quadruple.t

 (*   val random : max_input_length:int -> t 
 *)
  end

  module State : sig
    type t = {triples_consumed: int; acc: curve; params: Params.t}

    val create : ?triples_consumed:int -> ?init:curve -> Params.t -> t

    val update_bigstring : t -> Bigstring.t -> t

    val update_string : t -> string -> t

    val update_fold : t -> ((curve * int), bool Triple.t) fold -> t
(*
    val update_iter : t -> (f:(bool -> unit) -> unit) -> t
*)
    val digest : t -> Digest.t
(* 
    val salt : Triple_params.t -> string -> t
*)
  end

  val hash_fold : State.t -> ((curve * int), bool Triple.t) fold -> State.t

  val digest_fold : State.t -> ((curve * int), bool Triple.t) fold -> Digest.t

end

module Make (Field : sig
  include Snarky.Field_intf.S

  include Sexpable.S with type t := t
end)
(Bigint : Snarky.Bigint_intf.Extended with type field := Field.t)
(* Why is Curve an Edwards curve? *)
(Curve : Snarky.Curves.Edwards.Basic.S with type field := Field.t) =
struct
  module Digest = struct
    type t = Field.t [@@deriving sexp, eq]

    let size_in_bits = Field.size_in_bits

    let ( = ) = equal

    include Field_bin.Make (Field) (Bigint)
    module Snarkable = Bits.Snarkable.Field
    module Bits = Bits.Make_field (Field) (Bigint)
  end

  type ('s, 'b) fold = init:'s -> f:('s -> 'b -> 's) -> 's

  type 'b poly_fold = { fold : 's. ('s, 'b) fold }

  type bit_fold = bool poly_fold

  type triple_fold = bool Triple.t poly_fold

  let triple_fold_of_bit_fold (fold : bit_fold) : triple_fold =
  { fold =
    fun ~init ~f ->
      let (pt, bs) =
        fold.fold ~init:(init, []) ~f:(fun (pt, bs) b ->
          match bs with 
          | [b2; b1; b0] ->
          let pt' = f pt (b0, b1, b2) in 
          (pt', [])
          | _ ->
            (pt, b :: bs))
      in 
      match bs with
      | [b2; b1; b0] -> f pt (b0, b1, b2)
      | [b1; b0] ->  f pt (b0, b1, false)
      | [b0] -> f pt (b0, false, false)
      | [] -> pt
      | _::_::_ -> pt
  }
      
  module Bits_params = struct
    type t = Curve.t array

    let random_elt () =
      let x = Field.random () in
      let n = Bigint.of_field x in
      let rec go two_to_the_i i acc =
        if i = Field.size_in_bits then acc
        else
          let acc =
            if Bigint.test_bit n i then Curve.add acc two_to_the_i else acc
          in
          go (Curve.double two_to_the_i) (i + 1) acc
      in
      go Curve.generator 0 Curve.identity

    let random ~max_input_length =
      Array.init max_input_length ~f:(fun _ -> random_elt ())

    let max_input_length t = Array.length t
  end

  module Bits_state = struct
    type t = {bits_consumed: int; acc: Curve.t; params: Bits_params.t}

    let create ?(bits_consumed= 0) ?(init= Curve.identity) params =
      {acc= init; bits_consumed; params}

    let ith_bit_int n i = (n lsr i) land 1 = 1

    let update_bit_fold  (t: t)
        (fold: init:'acc -> f:('acc -> bool -> 'acc) -> 'acc) =
      let params = t.params in
      let acc, bits_consumed =
        fold ~init:(t.acc, t.bits_consumed) ~f:(fun (acc, i) b ->
            if b then (Curve.add acc params.(i), i + 1) else (acc, i + 1) )
      in 
      {t with acc; bits_consumed}

    let update_iter (t: t) (iter: f:(bool -> unit) -> unit) =
      let i = ref t.bits_consumed in
      let acc = ref t.acc in
      let params = t.params in
      iter ~f:(fun b ->
          if b then acc := Curve.add !acc params.(!i) ;
          incr i ) ;
          {t with acc= !acc; bits_consumed= !i}
      
    let update_char_fold ({acc; bits_consumed; params}: t) fold_chars =
      let acc, bits_consumed =
        fold_chars ~init:(acc, bits_consumed) ~f:(fun (acc, offset) c ->
            let c = Char.to_int c in
            let cond_add j acc =
              if ith_bit_int c j then Curve.add acc params.(offset + j)
              else acc
            in
            ( acc |> cond_add 0 |> cond_add 1 |> cond_add 2 |> cond_add 3
              |> cond_add 4 |> cond_add 5 |> cond_add 6 |> cond_add 7
            , offset + 8 ) )
      in
      {acc; bits_consumed; params}

    let fold_bit_bigstring s ~init ~f =
      let length = Bigstring.length s in
      let rec go acc i =
        if i = length then acc else go (f acc (Bigstring.get s i)) (i + 1)
      in
      go init 0

    let update_bit_bigstring (t: t) (s: Bigstring.t) =
      let bit_length = 8 * Bigstring.length s in
      assert (bit_length <= Bits_params.max_input_length t.params - t.bits_consumed) ;
      update_char_fold t (fold_bit_bigstring s)

    let update_bit_string (t: t) (s: string) =
      let bit_length = 8 * String.length s in
      assert (bit_length <= Bits_params.max_input_length t.params - t.bits_consumed) ;
      update_char_fold t (String.fold s)

    let digest t =
      let x, _y = t.acc in
      x

    let salt params s = update_bit_string (create params) s
  end

  let hash_bit_fold s fold = Bits_state.update_bit_fold s fold

  let digest_bit_fold s fold = Bits_state.digest (hash_bit_fold s fold)


  module Params = struct
    type t = Curve.t Quadruple.t array

    let of_curve (x : Curve.t) = (x, x, x, x)
(*
    let random_elt () =
      let x = Field.random () in
      let n = Bigint.of_field x in
      let rec go two_to_the_i i acc =
        if i = Field.size_in_bits then acc
        else
          let acc =
            if Bigint.test_bit n i then Curve.add acc two_to_the_i else acc
          in
          go (Curve.double two_to_the_i) (i + 1) acc
      in
      go Curve.generator 0 Curve.identity

    let random ~max_input_length =
      Array.init max_input_length ~f:(fun _ -> random_elt ())
*)
    let max_input_length t = Array.length t
  end

  module State = struct
    type t = {triples_consumed: int; acc: Curve.t; params: Params.t}

    let create ?(triples_consumed= 0) ?(init= Curve.identity) params =
      {acc= init; triples_consumed; params}

    let ith_bit_int n i = (n lsr i) land 1 = 1

    let update_fold (t: t)
        (fold: init:'acc -> f:('acc -> bool Triple.t -> 'acc) -> 'acc) =
            let acc, triples_consumed = 
            fold ~init:(t.acc, t.triples_consumed) ~f:(fun (acc, i) b ->
            let (b0, b1, b2) = b in 
            let index = Triple.get b in
            let (resx, resy) = 
            Quadruple.get (t.params.(i)) index in
            (* why is Field.negate not callable here *)
            if b2 then (Curve.add acc (resx, Field.sub Field.zero resy), i + 1)
              else (Curve.add (resx, resy) acc, i + 1) )
              in {t with acc; triples_consumed}


    let update_char_fold ({acc; triples_consumed; params}: t) fold_chars =
      let acc, triples_consumed =
        fold_chars ~init:(acc, triples_consumed) ~f:(fun (acc, offset) c ->
            let c = Char.to_int c in
            let cond_add j acc =
              if ith_bit_int c j then Curve.add acc params.(offset + j)
              else acc
            in
            ( acc |> cond_add 0 |> cond_add 1 |> cond_add 2 |> cond_add 3
              |> cond_add 4 |> cond_add 5 |> cond_add 6 |> cond_add 7
            , offset + 8 ) )
      in
      {acc; triples_consumed; params}

    let fold_bigstring s ~init ~f =
      let length = Bigstring.length s in
      let rec go acc i =
        if i = length then acc else go (f acc (Bigstring.get s i)) (i + 1)
      in
      go init 0

    let update_bigstring (t: t) (s: Bigstring.t) =
      let bit_length = 8 * Bigstring.length s in
      assert (bit_length <= Bits_params.max_input_length t.params - t.triples_consumed) ;
      update_char_fold t (fold_bigstring s)

    let update_string (t: t) (s: string) =
      let bit_length = 8 * String.length s in
      assert (bit_length <= Bits_params.max_input_length t.params - t.triples_consumed) ;
      update_char_fold t (String.fold s)

    let digest t =
      let x, _y = t.acc in
      x
  end

  let hash_fold s fold = State.update_fold s fold

  let digest_fold s fold = State.digest (hash_fold s fold)

end
