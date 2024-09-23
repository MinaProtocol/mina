open Core_kernel

type field = Pickles.Impls.Step.Internal_Basic.field

(* Alias to distinguish hashes from inputs *)
type hash = field

type input_t = [ `State of field Oracle.State.t ] * field array

(* start_ix is inclusive, end_ix is exclusive *)
type 'v cont_t = start_ix:int -> hash array -> 'v

(* Let's find a way to get rid of Freer *)
(* Please commit the code *)

(** Defines a batching hash monad, it's basically a specialized variant of Freer monad
    See: Oleg Kiselyov, and Hiromi Ishii. “Freer Monads, More Extensible Effects.”
    https://okmij.org/ftp/Haskell/extensible/more.pdf
*)
type 'a t =
  | Pure of 'a
  | Impure :
      { (* request is a non-empty sequence *)
        request : input_t Sequence.t
      ; cont : 'a t cont_t
      ; request_len : int
      }
      -> 'a t

module M_basic = struct
  let rec bind t ~f =
    match t with
    | Pure a ->
        f a
    | Impure areq ->
        let cont ~start_ix hashes = bind ~f (areq.cont ~start_ix hashes) in
        Impure { areq with cont }

  let return a = Pure a

  let rec map v ~f =
    match v with
    | Pure a ->
        Pure (f a)
    | Impure req ->
        Impure
          { req with
            cont = (fun ~start_ix -> Fn.compose (map ~f) (req.cont ~start_ix))
          }
end

let rec lift2 f = function
  | Pure a ->
      M_basic.map ~f:(f a)
  | Impure a as at -> (
      function
      | Pure b ->
          M_basic.map ~f:(Fn.flip f b) at
      | Impure b ->
          let cont ~start_ix hashes =
            let mid_ix = start_ix + a.request_len in
            lift2 f (a.cont hashes ~start_ix) @@ b.cont hashes ~start_ix:mid_ix
          in
          Impure
            { request = Sequence.append a.request b.request
            ; request_len = a.request_len + b.request_len
            ; cont
            } )

let ( <*> ) a b = lift2 (fun f a -> f a) a b

let request_len = function
  | Pure _ ->
      0
  | Impure { request_len; _ } ->
      request_len

let request = function
  | Pure _ ->
      Sequence.empty
  | Impure { request; _ } ->
      request

let unwrap_pure_exn = function
  | Pure a ->
      a
  | Impure _ ->
      failwith "unwrap_pure_exn: impure"

module M : Core_kernel.Monad.S with type 'a t := 'a t = struct
  include M_basic

  module Monad_infix = struct
    let ( >>= ) t f = bind t ~f

    let ( >>| ) t f = map t ~f
  end

  include Monad_infix

  module Let_syntax = struct
    let return = return

    include Monad_infix

    module Let_syntax = struct
      include M_basic

      let both a b = lift2 Tuple2.create a b

      module Open_on_rhs = struct end
    end
  end

  let join t = t >>= ident

  let ignore_m t = map ~f:(const ()) t

  (* Rewrite more efficiently, map and then reduce *)
  let all_impl ~all lst =
    let request_len =
      List.fold ~init:0 ~f:(fun acc el -> acc + request_len el) lst
    in
    let request =
      List.fold
        ~init:(Sequence.empty : input_t Sequence.t)
        ~f:Sequence.(fun acc el -> append (request el) acc)
        lst
    in
    if Sequence.is_empty request then
      (* All are pure *)
      Pure (List.map ~f:unwrap_pure_exn lst)
    else
      let cont ~start_ix hashes =
        List.fold_map ~init:start_ix lst ~f:(fun ix -> function
          | Impure { request_len; cont; _ } ->
              (ix + request_len, cont hashes ~start_ix:ix)
          | pure ->
              (ix, pure) )
        |> snd |> all
      in
      Impure { request; request_len; cont }

  let rec all lst = all_impl ~all lst

  let rec all_unit_impl lst =
    let lst' =
      List.filter ~f:(function Impure _ -> true | Pure () -> false) lst
    in
    all_impl ~all:all_unit_impl lst'

  let all_unit lst = ignore_m (all_unit_impl lst)
end

include M

let rec evaluate = function
  | Pure a ->
      a
  | Impure { request; cont; _ } ->
      let request = Sequence.(to_list request) in
      let response = Oracle.hash_batch request |> Array.of_list in
      evaluate @@ cont ~start_ix:0 response

let hash ~init data =
  Impure
    { request = Sequence.return (`State init, data)
    ; request_len = 1
    ; cont = (fun ~start_ix hashes -> Pure (Array.get hashes start_ix))
    }

let hash_batch data =
  let request_len = List.length data in
  if request_len = 0 then Pure []
  else
    Impure
      { request = Sequence.of_list data
      ; request_len
      ; cont =
          (fun ~start_ix hashes ->
            Pure
              (List.init request_len ~f:(fun i ->
                   Array.get hashes @@ (i + start_ix) ) ) )
      }

let map_list ~f = Fn.compose all @@ List.map ~f

let fold_right ~f ~init =
  List.fold_right ~init:(Pure init) ~f:(fun el acc -> acc >>= f el)
