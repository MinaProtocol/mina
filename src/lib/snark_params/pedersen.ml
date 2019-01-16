open Core_kernel
open Snark_bits
open Fold_lib
open Tuple_lib
open Chunked_triples

module type S = sig
  type curve

  module Digest : sig
    type t [@@deriving bin_io, sexp, eq, hash, compare]

    val size_in_bits : int

    val fold : t -> bool Triple.t Fold.t

    val ( = ) : t -> t -> bool

    module Bits : Bits_intf.S with type t := t

    module Snarkable (Impl : Snark_intf.S) :
      Impl.Snarkable.Bits.Lossy
      with type Packed.var = Impl.Field.Checked.t
       and type Packed.value = Impl.Field.t
       and type Unpacked.value = Impl.Field.t
  end

  module Params : sig
    type t = curve Quadruple.t array
  end

  (* curve_points_table.(i).(j) is the curve element for a chunk at position i within
     a list of chunks, and j is an integer representing the chunk considered as bits
  *)
  module Curve_chunk_table : sig
    type t = {curve_points_table: curve array array}
  end

  module State : sig
    type t =
      { triples_consumed: int
      ; acc: curve
      ; params: Params.t
      ; chunk_table: Curve_chunk_table.t }

    val create :
         ?triples_consumed:int
      -> ?init:curve
      -> Params.t
      -> Curve_chunk_table.t
      -> t

    val update_fold : t -> bool Triple.t Fold.t -> t

    val digest : t -> Digest.t

    val salt : Params.t -> Curve_chunk_table.t -> string -> t
  end

  val hash_fold : State.t -> bool Triple.t Fold.t -> State.t

  val digest_fold : State.t -> bool Triple.t Fold.t -> Digest.t
end

module Make (Field : sig
  type t [@@deriving sexp, bin_io, compare, hash, eq]

  include Snarky.Field_intf.S with type t := t
end)
(Bigint : Snarky.Bigint_intf.Extended with type field := Field.t) (Curve : sig
    type t

    val to_coords : t -> Field.t * Field.t

    val zero : t

    val add : t -> t -> t

    val negate : t -> t
end) : S with type curve := Curve.t and type Digest.t = Field.t = struct
  module Digest = struct
    type t = Field.t [@@deriving sexp, bin_io, compare, hash, eq]

    let size_in_bits = Field.size_in_bits

    let ( = ) = equal

    module Snarkable = Bits.Snarkable.Field
    module Bits = Bits.Make_field (Field) (Bigint)

    let fold t = Fold.group3 ~default:false (Bits.fold t)
  end

  module Params = struct
    type t = Curve.t Quadruple.t array
  end

  module Curve_chunk_table = struct
    type t = {curve_points_table: Curve.t array array}
  end

  module State = struct
    type t =
      { triples_consumed: int
      ; acc: Curve.t
      ; params: Params.t
      ; chunk_table: Curve_chunk_table.t }

    let create ?(triples_consumed = 0) ?(init = Curve.zero) params chunk_table
        =
      {acc= init; triples_consumed; params; chunk_table}

    type fold_result =
      { acc: Curve.t
      ; triples_consumed: int (* have we reached a chunk boundary *)
      ; synched: bool (* reversed chunk, or part of one *)
      ; chunk_rev: bool Triple.t list (* length of chunk_rev *)
      ; chunk_rev_len: int (* index into the chunk table to use *)
      ; chunk_ndx: int }

    let update_fold (t : t) (fold : bool Triple.t Fold.t) =
      let params = t.params in
      let chunk_ndx =
        let boundary = t.triples_consumed / Chunk.size in
        if Int.equal (t.triples_consumed mod Chunk.size) 0 then
          (* exactly at chunk boundary *)
          boundary
        else (* next chunk boundary *)
          boundary + 1
      in
      let process_triple i triple =
        Snarky.Pedersen.local_function ~negate:Curve.negate params.(i) triple
      in
      let table = t.chunk_table.curve_points_table in
      (* consume a triple at a time until we're at a chunk boundary, then
         use chunk table; after processing all full chunks, consume any
         straggler triples
      *)
      let ({acc; triples_consumed; chunk_rev; _} : fold_result) =
        fold.fold
          ~init:
            { acc= t.acc
            ; triples_consumed= t.triples_consumed
            ; synched= false
            ; chunk_rev= []
            ; chunk_rev_len= 0
            ; chunk_ndx } ~f:(fun accum triple ->
            let synched =
              accum.synched || Int.equal (t.triples_consumed mod Chunk.size) 0
            in
            if synched then
              if Int.equal (accum.chunk_rev_len + 1) Chunk.size then
                (* full chunk *)
                let n = Chunk.to_int (List.rev (triple :: accum.chunk_rev)) in
                let g = table.(accum.chunk_ndx).(n) in
                { acc= Curve.add accum.acc g
                ; triples_consumed= accum.triples_consumed + Chunk.size
                ; synched= true (* stay synched *)
                ; chunk_rev= [] (* new chunk *)
                ; chunk_rev_len= 0
                ; chunk_ndx= accum.chunk_ndx + 1 }
              else
                (* build next chunk *)
                { accum with
                  synched= true
                ; chunk_rev= triple :: accum.chunk_rev
                ; chunk_rev_len= accum.chunk_rev_len + 1 }
            else
              (* not synched, consume one triple *)
              { accum with
                acc=
                  Curve.add accum.acc
                    (process_triple accum.triples_consumed triple)
              ; triples_consumed= accum.triples_consumed + 1 } )
      in
      let new_state = {t with acc; triples_consumed} in
      if List.is_empty chunk_rev then (* no stragglers *)
        new_state
      else
        let stragglers = List.rev chunk_rev in
        let acc, triples_consumed =
          List.fold stragglers
            ~init:(new_state.acc, new_state.triples_consumed)
            ~f:(fun (acc, i) triple ->
              (Curve.add acc (process_triple i triple), i + 1) )
        in
        {new_state with acc; triples_consumed}

    let digest (t : t) =
      let x, _y = Curve.to_coords t.acc in
      x

    let salt params chunk_table s =
      update_fold (create params chunk_table) (Fold.string_triples s)
  end

  let hash_fold s fold = State.update_fold s fold

  let digest_fold s fold = State.digest (hash_fold s fold)
end
