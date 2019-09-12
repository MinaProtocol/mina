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

  module Digest : sig
    type t [@@deriving sexp, eq, hash, compare, yojson]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io, compare, hash, eq, version, yojson]
        end

        module Latest = V1
      end
      with type V1.t = t

    val size_in_bits : int

    val fold : t -> bool Triple.t Fold.t

    val ( = ) : t -> t -> bool

    module Bits : Bits_intf.S with type t := t
  end

  module Params : sig
    type t = curve Quadruple.t array
  end

  (* for the table returned by get_chunk_table, the item at index i, j is the curve element for a chunk
     at position i within a list of chunks, and j is an integer representing the *reversed* chunk considered as bits
  *)
  module State : sig
    [%%if fake_hash]

    type t = {triples_consumed: int; acc: curve; ctx: Digestif.SHA256.ctx}

    [%%else]

    type t = {triples_consumed: int; acc: curve}

    [%%endif]

    val create : ?triples_consumed:int -> ?init:curve -> unit -> t

    val update_fold_chunked : t -> bool Triple.t Fold.t -> t

    val update_fold_unchunked : t -> bool Triple.t Fold.t -> t

    val update_fold : t -> bool Triple.t Fold.t -> t

    val set_chunked_fold : bool -> unit

    val digest : t -> Digest.t

    val salt : string -> t
  end

  val hash_fold : State.t -> bool Triple.t Fold.t -> State.t

  val digest_fold : State.t -> bool Triple.t Fold.t -> Digest.t
end

module Make (Inputs : Pedersen_inputs_intf.S) :
  S with type curve := Inputs.Curve.t and type Digest.t = Inputs.Field.t =
struct
  open Inputs

  module Digest = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = Field.t
          [@@deriving
            sexp, bin_io, compare, hash, eq, version {asserted; unnumbered}]
        end

        include T

        let to_yojson t = `String (Field.to_string t)

        let of_yojson = function
          | `String s -> (
            try Ok (Field.of_string s)
            with exn -> Error Error.(to_string_hum (of_exn exn)) )
          | _ ->
              Error "expected string"
      end

      module Latest = V1
    end

    (* omit bin_io, version *)
    type t = Stable.Latest.t [@@deriving sexp, eq, hash, compare]

    [%%define_locally
    Stable.Latest.(of_yojson, to_yojson)]

    let size_in_bits = Field.size_in_bits

    let ( = ) = equal

    module Snarkable = Bits.Snarkable.Field
    module Bits = Bits.Make_field (Field) (Bigint)

    let fold t = Fold.group3 ~default:false (Bits.fold t)
  end

  module Params = struct
    type t = Curve.t Quadruple.t array
  end

  module State = struct
    [%%if
    fake_hash]

    type t = {triples_consumed: int; acc: Curve.t; ctx: Digestif.SHA256.ctx}

    let create ?(triples_consumed = 0) ?(init = Curve.zero) () =
      {acc= init; triples_consumed; ctx= Digestif.SHA256.init ()}

    let update_fold (t : t) (fold : bool Triple.t Fold.t) =
      O1trace.measure "pedersen fold" (fun () ->
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
          let dgst = Digestif.SHA256.(get ctx |> to_raw_string) in
          O1trace.trace_event "about to make field element" ;
          let bits = List.init 256 ~f:(bit_at dgst) in
          let x = Field.project bits in
          { acc= Curve.point_near_x x
          ; ctx
          ; triples_consumed= t.triples_consumed + triples_consumed_here } )

    let set_chunked_fold _ = ()

    let update_fold_chunked = update_fold

    let update_fold_unchunked = update_fold

    [%%else]

    open Chunked_triples

    type t = {triples_consumed: int; acc: Curve.t}

    let create ?(triples_consumed = 0) ?(init = Curve.zero) () =
      {acc= init; triples_consumed}

    type fold_result =
      { sum: Curve.t
      ; triples_consumed: int
      ; synched: bool (* have we reached a chunk boundary *)
      ; chunk_rev: bool Triple.t list (* reversed chunk, or part of one *)
      ; chunk_rev_len: int (* length of chunk_rev *)
      ; chunk_ndx: int (* index into the chunk table to use *) }

    let update_fold_chunked (t : t) (fold : bool Triple.t Fold.t) =
      O1trace.measure "pedersen fold" (fun () ->
          let chunk_ndx =
            let boundary = t.triples_consumed / Chunk.size in
            if Int.equal (t.triples_consumed mod Chunk.size) 0 then
              (* exactly at chunk boundary *)
              boundary
            else (* next chunk boundary *)
              boundary + 1
          in
          let process_triple i triple =
            Snarky.Pedersen.local_function ~negate:Curve.negate params.(i)
              triple
          in
          let table = Lazy.force chunk_table in
          (* consume a triple at a time until we're at a chunk boundary, then
             use chunk table; after processing all full chunks, consume any
             straggler triples
           *)
          let ({sum; triples_consumed; chunk_rev; _} : fold_result) =
            fold.fold
              ~init:
                { sum= t.acc
                ; triples_consumed= t.triples_consumed
                ; synched= false
                ; chunk_rev= []
                ; chunk_rev_len= 0
                ; chunk_ndx } ~f:(fun accum triple ->
                let synched =
                  accum.synched
                  || Int.equal (t.triples_consumed mod Chunk.size) 0
                in
                if synched then
                  if Int.equal (accum.chunk_rev_len + 1) Chunk.size then
                    (* full chunk; use int value of the reversed chunk as table index *)
                    let n = Chunk.to_int (triple :: accum.chunk_rev) in
                    let g = table.(accum.chunk_ndx).(n) in
                    { sum= Curve.add accum.sum g
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
                    sum=
                      Curve.add accum.sum
                        (process_triple accum.triples_consumed triple)
                  ; triples_consumed= accum.triples_consumed + 1 } )
          in
          let new_state = {acc= sum; triples_consumed} in
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
            {acc; triples_consumed} )

    let update_fold_unchunked (t : t) (fold : bool Triple.t Fold.t) =
      let acc, triples_consumed =
        fold.fold ~init:(t.acc, t.triples_consumed) ~f:(fun (acc, i) triple ->
            let term =
              Snarky.Pedersen.local_function ~negate:Curve.negate params.(i)
                triple
            in
            (Curve.add acc term, i + 1) )
      in
      {acc; triples_consumed}

    let update_fold_fun_ref = ref update_fold_unchunked

    let set_chunked_fold b =
      if b then update_fold_fun_ref := update_fold_chunked
      else update_fold_fun_ref := update_fold_unchunked

    let update_fold t fold = !update_fold_fun_ref t fold

    [%%endif]

    let digest t =
      let x, _y = Curve.to_affine_exn t.acc in
      x

    let salt s = update_fold (create ()) (Fold.string_triples s)
  end

  let hash_fold s fold = State.update_fold s fold

  let digest_fold s fold =
    Coda_metrics.(Counter.inc_one Cryptography.total_pedersen_hashes_computed) ;
    State.digest (hash_fold s fold)
end
