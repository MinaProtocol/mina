open Async
open Core
open Stdint

module Fragment_view = struct
  type t = { fragments : bytes list; start_offset : int; end_offset : int }

  type ('result, 'state) decode_f =
       buf:bytes
    -> start:int
    -> end_:int
    -> 'state
    -> [ `Finished of 'result | `Incomplete of 'state ]

  type 'result decoder =
    | Decoder :
        { size : int
        ; initial_state : 'state
        ; read : ('result, 'state) decode_f
        }
        -> 'result decoder

  let decoder_size (Decoder { size; _ }) = size

  let map_decoder (Decoder d) ~f =
    let read ~buf ~start ~end_ s =
      match d.read ~buf ~start ~end_ s with
      | `Incomplete s' ->
          `Incomplete s'
      | `Finished x ->
          `Finished (f x)
    in
    Decoder { d with read }

  let unsafe_decode (Decoder d) t =
    let fail s = failwithf "Fragment_view.unsafe_decode: %s" s () in
    let decode_from_this_fragment ~start ~end_ ~remaining_bytes ~state fragment
        =
      let finish_expected = end_ - start + 1 >= remaining_bytes in
      match d.read ~buf:fragment ~start ~end_ state with
      | `Finished result when finish_expected ->
          Ok result
      | `Finished result ->
          fail "unexpected completion"
      | `Incomplete st when finish_expected ->
          fail "expected completion"
      | `Incomplete st ->
          Error st
    in
    let rec decode_from_next_fragment ~start ~remaining_bytes ~state
        remaining_fragments =
      let fragment, remaining_fragments' =
        match remaining_fragments with
        | h :: t ->
            (h, t)
        | [] ->
            failwith "Fragment_view.unsafe_decode: invariant broken"
      in
      let is_last_fragment = List.is_empty remaining_fragments' in
      let len = Bytes.length fragment in
      let end_ = if is_last_fragment then t.end_offset else len - 1 in
      match
        decode_from_this_fragment ~start ~end_ ~remaining_bytes ~state fragment
      with
      | Ok result ->
          result
      | Error state' ->
          let remaining_bytes' = remaining_bytes - (end_ - start + 1) in
          decode_from_next_fragment ~start:0 ~remaining_bytes:remaining_bytes'
            ~state:state' remaining_fragments'
    in
    decode_from_next_fragment ~start:t.start_offset ~remaining_bytes:d.size
      ~state:d.initial_state t.fragments
end

module Decoders = struct
  open Fragment_view

  let align (Decoder d) alignment =
    let size = alignment * ((d.size + alignment - 1) / alignment) in
    Decoder { d with size }

  let unit : unit decoder =
    Decoder
      { size = 0
      ; initial_state = ()
      ; read = (fun ~buf:_ ~start:_ ~end_:_ () -> `Finished ())
      }

  (* unfortunatley requires copying of bytes, which sucks... *)
  let bytes size : bytes decoder =
    let open struct
      type state =
        { bytes_read : int
        ; accumulator : (bytes * [ `Full | `Slice of int * int ]) list
        }
    end in
    let initial_state = { bytes_read = 0; accumulator = [] } in
    let extract_result slices =
      let result = Bytes.create size in
      assert (
        List.fold_right slices ~init:0 ~f:(fun (buf, slice_view) i ->
            let start, len =
              match slice_view with
              | `Full ->
                  (0, Bytes.length buf)
              | `Slice (start, end_) ->
                  (start, end_ - start + 1)
            in
            Bytes.unsafe_blit ~src:buf ~src_pos:start ~dst:result ~dst_pos:i
              ~len ;
            i + len)
        = size ) ;
      result
    in
    let rec read ~buf ~start ~end_ s =
      if s.bytes_read = size then `Finished (extract_result s.accumulator)
      else
        let required = size - s.bytes_read in
        let available = end_ - start + 1 in
        let slice_size = min required available in
        let slice_end = start + slice_size - 1 in
        let slice_view =
          if start = 0 && slice_end = Bytes.length buf - 1 then `Full
          else `Slice (start, slice_end)
        in
        let bytes_read' = s.bytes_read + slice_size in
        let accumulator' = (buf, slice_view) :: s.accumulator in
        if bytes_read' = size then `Finished (extract_result accumulator')
        else
          `Incomplete { bytes_read = bytes_read'; accumulator = accumulator' }
    in
    Decoder { size; initial_state; read }

  let uint32 : Uint32.t decoder =
    let open struct
      type state = { bytes_read : int; accumulator : Uint32.t }
    end in
    let size = 4 in
    let initial_state = { bytes_read = 0; accumulator = Uint32.zero } in
    (* read uint32 byte-by-byte for X-fragment solution *)
    let rec read_bytes ~buf ~start ~end_ s =
      if s.bytes_read = size then `Finished s.accumulator
      else
        let b = Bytes.unsafe_get buf start |> Char.to_int |> Uint32.of_int in
        let s' =
          let accumulator =
            Uint32.logor s.accumulator (Uint32.shift_left b (8 * s.bytes_read))
          in
          let bytes_read = s.bytes_read + 1 in
          { bytes_read; accumulator }
        in
        if start = end_ then `Incomplete s'
        else read_bytes ~buf ~start:(start + 1) ~end_ s'
    in
    let read ~buf ~start ~end_ state =
      (* select and optimized solution if possible *)
      if state.bytes_read = 0 && start + size - 1 <= end_ then
        `Finished (Uint32.of_bytes_little_endian buf start)
      else read_bytes ~buf ~start ~end_ state
    in
    Decoder { size; initial_state; read }

  let monomorphic_list (element : 'elt decoder) (count : int) :
      'elt list decoder =
    let (Decoder
          { size = elt_size
          ; initial_state = elt_initial_state
          ; read = read_elt
          }) =
      element
    in
    let open struct
      type ('elt, 'elt_state) state =
        { elements_read : int
        ; element_state : 'elt_state
        ; accumulator : 'elt list
        }
    end in
    let size = elt_size * count in
    let rec read ~buf ~start ~end_ s =
      match read_elt ~buf ~start ~end_ s.element_state with
      | `Incomplete element_state ->
          `Incomplete { s with element_state }
      | `Finished elt ->
          let elements_read = s.elements_read + 1 in
          let accumulator = elt :: s.accumulator in
          if elements_read = count then `Finished (List.rev accumulator)
          else
            let start' = start + elt_size in
            let state' =
              { element_state = elt_initial_state; elements_read; accumulator }
            in
            if start' <= end_ then
              read ~buf ~start:(start + elt_size) ~end_ state'
            else `Incomplete state'
    in
    let initial_state =
      { elements_read = 0; element_state = elt_initial_state; accumulator = [] }
    in
    Decoder { size; initial_state; read }

  let polymorphic_list (elements : 'elt decoder list) : 'elt list decoder =
    let open struct
      type 'elt state =
        | State :
            { current_elt_size : int
            ; read_current_elt : ('elt, 'elt_state) decode_f
            ; current_elt_state : 'elt_state
            ; remaining_elements : 'elt decoder list
            ; accumulator : 'elt list
            }
            -> 'elt state
    end in
    let advance remaining_elements accumulator =
      match remaining_elements with
      | [] ->
          None
      | Decoder
          { size = current_elt_size
          ; initial_state = current_elt_state
          ; read = read_current_elt
          }
        :: remaining_elements ->
          Some
            (State
               { current_elt_size
               ; read_current_elt
               ; current_elt_state
               ; remaining_elements
               ; accumulator
               })
    in
    match advance elements [] with
    | None ->
        map_decoder unit ~f:(Fn.const [])
    | Some initial_state ->
        let size =
          List.sum (module Int) elements ~f:(fun (Decoder { size; _ }) -> size)
        in
        let rec read ~buf ~start ~end_ (State s) =
          match s.read_current_elt ~buf ~start ~end_ s.current_elt_state with
          | `Incomplete current_elt_state ->
              `Incomplete (State { s with current_elt_state })
          | `Finished elt -> (
              let accumulator = elt :: s.accumulator in
              match advance s.remaining_elements accumulator with
              | None ->
                  `Finished (List.rev accumulator)
              | Some s' ->
                  let start' = start + s.current_elt_size in
                  if start' <= end_ then read ~buf ~start:start' ~end_ s'
                  else `Incomplete s' )
        in
        Decoder { size; initial_state; read }
end

let%test_module "decoder tests" =
  ( module struct
    open Fragment_view
    open Decoders

    let gen_bytes ?n () =
      let open Quickcheck.Generator.Let_syntax in
      let%bind n =
        Option.map n ~f:return |> Option.value ~default:(Int.gen_incl 1 1024)
      in
      Bytes.gen_with_length n Char.quickcheck_generator

    let gen_slices buf =
      let open Quickcheck.Generator.Let_syntax in
      let rec slice_list ~num_slices ~slice_chance ~start ~index src =
        let get () = Bytes.sub src ~pos:start ~len:(index - start + 1) in
        let new_slice () =
          slice_list ~num_slices:(num_slices - 1) ~slice_chance
            ~start:(index + 1) ~index:(index + 1) src
        in
        let continue_slice () =
          slice_list ~num_slices ~slice_chance ~start ~index:(index + 1) src
        in
        if index >= Bytes.length src - 1 then return [ get () ]
        else if num_slices >= Bytes.length src - 1 - index then
          new_slice () >>| List.cons (get ())
        else
          let%bind roll = Float.gen_incl 0.0 1.0 in
          if Float.(roll <= slice_chance) then
            new_slice () >>| List.cons (get ())
          else continue_slice ()
      in
      let size = Bytes.length buf in
      let%bind num_slices = Int.gen_incl 0 (size - 1) in
      let slice_chance =
        Float.of_int (size - 1 - num_slices) /. Float.of_int size
      in
      slice_list ~num_slices ~slice_chance ~start:0 ~index:0 buf

    let gen_fragment_view buf =
      let open Quickcheck.Generator.Let_syntax in
      let gen_garbage =
        let%bind n = Int.gen_incl 0 255 in
        gen_bytes ~n ()
      in
      let add_prefix p ls =
        Stdlib.Bytes.cat p (List.hd_exn ls) :: List.tl_exn ls
      in
      let add_suffix s ls =
        List.take ls (List.length ls - 1)
        @ [ Stdlib.Bytes.cat (List.last_exn ls) s ]
      in
      let%bind slices = gen_slices buf in
      let%map prefix = gen_garbage and suffix = gen_garbage in
      { fragments = slices |> add_prefix prefix |> add_suffix suffix
      ; start_offset = Bytes.length prefix
      ; end_offset =
          ( Bytes.length (List.last_exn slices)
          + if List.length slices = 1 then Bytes.length prefix else 0 )
      }

    let%test_unit "bytes decoder" =
      Quickcheck.test
        (Quickcheck.Generator.bind (gen_bytes ()) ~f:gen_fragment_view)
        ~f:(fun view ->
          let size =
            List.sum (module Int) view.fragments ~f:Bytes.length
            - view.start_offset
            - (Bytes.length (List.last_exn view.fragments) - view.end_offset)
          in
          let expected =
            view.fragments
            |> List.map ~f:Stdlib.Bytes.unsafe_to_string
            |> String.concat
            |> String.sub ~pos:view.start_offset ~len:size
            |> Stdlib.Bytes.unsafe_of_string
          in
          let result = unsafe_decode (bytes size) view in
          [%test_eq: bytes] result expected)

    let%test_unit "uint32 decoder" =
      let gen_serialized_uint32 =
        let open Quickcheck.Generator.Let_syntax in
        let%map n = Core.Int64.(gen_incl zero (of_int 2 ** of_int 32)) in
        let buf = Bytes.create 4 in
        Uint32.(to_bytes_little_endian (of_int64 n) buf 0) ;
        buf
      in
      Quickcheck.test
        (Quickcheck.Generator.bind gen_serialized_uint32 ~f:gen_fragment_view)
        ~f:(fun view ->
          let size =
            List.sum (module Int) view.fragments ~f:Bytes.length
            - view.start_offset
            - (Bytes.length (List.last_exn view.fragments) - view.end_offset)
          in
          let expected =
            view.fragments
            |> List.map ~f:Stdlib.Bytes.unsafe_to_string
            |> String.concat
            |> String.sub ~pos:view.start_offset ~len:size
            |> Stdlib.Bytes.unsafe_of_string
          in
          let result = unsafe_decode (bytes size) view in
          [%test_eq: bytes] result expected)
  end )

module Fragment_stream = struct
  type t =
    { buffered_fragments : bytes Queue.t
    ; mutable buffered_size : int
    ; mutable first_fragment_offset : int
    ; mutable outstanding_read_request : (int * unit Ivar.t) option
    }

  let create () =
    { buffered_fragments = Queue.create ()
    ; buffered_size = 0
    ; first_fragment_offset = 0
    ; outstanding_read_request = None
    }

  let add_fragment t fragment =
    let len = Bytes.length fragment in
    Queue.enqueue t.buffered_fragments fragment ;
    t.buffered_size <- t.buffered_size + len ;
    Option.iter t.outstanding_read_request ~f:(fun (remaining, signal) ->
        let remaining' = remaining - len in
        if remaining' <= 0 then (
          t.outstanding_read_request <- None ;
          Ivar.fill signal () )
        else t.outstanding_read_request <- Some (remaining', signal))

  let read_now_exn t amount_to_read =
    (* IMPORTANT: maintain tail recursion *)
    let rec dequeue_fragments acc amount_read =
      let frag = Queue.peek_exn t.buffered_fragments in
      let len = Bytes.length frag - t.first_fragment_offset in
      let delta_read = min len (amount_to_read - amount_read) in
      let amount_read' = amount_read + delta_read in
      t.buffered_size <- t.buffered_size - delta_read ;
      t.first_fragment_offset <-
        ( if delta_read = len then (
          ignore (Queue.dequeue_exn t.buffered_fragments : bytes) ;
          0 )
        else t.first_fragment_offset + delta_read ) ;
      let acc' = frag :: acc in
      if amount_read' = amount_to_read then acc'
      else dequeue_fragments acc' amount_read'
    in
    assert (t.buffered_size >= amount_to_read) ;
    let start_offset = t.first_fragment_offset in
    let fragments, last_fragment =
      let rev_fragments = dequeue_fragments [] 0 in
      (List.rev rev_fragments, List.hd_exn rev_fragments)
    in
    let end_offset =
      ( if t.first_fragment_offset = 0 then Bytes.length last_fragment
      else t.first_fragment_offset )
      - 1
    in
    { Fragment_view.fragments; start_offset; end_offset }

  let read t amount =
    assert (Option.is_none t.outstanding_read_request) ;
    if t.buffered_size >= amount then return (read_now_exn t amount)
    else
      let amount_required = amount - t.buffered_size in
      let wait_signal = Ivar.create () in
      t.outstanding_read_request <- Some (amount_required, wait_signal) ;
      let%map () = Ivar.read wait_signal in
      read_now_exn t amount

  let read_and_decode t decoder =
    let open Fragment_view in
    read t (decoder_size decoder) >>| unsafe_decode decoder
end

include Monad.Make (struct
  type 'a t = Fragment_stream.t -> 'a Deferred.t

  let return x = Fn.const (Deferred.return x)

  let map =
    `Custom (fun m ~f stream -> Deferred.map (m stream) ~f:(fun x -> f x))

  let bind m ~f stream = Deferred.bind (m stream) ~f:(fun x -> f x stream)
end)

let parse decoder stream = Fragment_stream.read_and_decode stream decoder
