open Core_kernel

(* open Mina_base *)

(* TODO: abstract stackdriver specific log details *)

(* TODO: Monad_ext *)
(* let or_error_list_fold ls ~init ~f =
  let open Or_error.Let_syntax in
  List.fold ls ~init:(return init) ~f:(fun acc_or_error el ->
      let%bind acc = acc_or_error in
      f acc el)

let bad_parse = Or_error.error_string "bad parse" *)

module type Event_type_puppeteer_intf = sig
  type t [@@deriving to_yojson]

  val name : string

  val puppeteer_event_type : string option

  val parse : Puppeteer_message.t -> t Or_error.t
end

module Log_error = struct
  let name = "Log_error"

  let puppeteer_event_type = None

  type t = Puppeteer_message.t [@@deriving to_yojson]

  let parse = Or_error.return
end

(* NOTE: the daemon does not emit a node offline event organically.  it is the repsonsibility of the test execution engine to emit, in whatever way, the Node offline event.  this can be achived with the wrapping script emitting printouts, or by checking whatever systems tools, and so on-- the best way will depend on the engine *)
module Node_offline = struct
  let name = "Node_offline"

  let puppeteer_event_type = Some "node_offline"

  type t = unit [@@deriving to_yojson]

  let parse = Fn.const (Or_error.return ())
end

type 'a t = Log_error : Log_error.t t | Node_offline : Node_offline.t t

type existential = Event_type_puppeteer : 'a t -> existential

let existential_to_string = function
  | Event_type_puppeteer Log_error ->
      "Log_error"
  | Event_type_puppeteer Node_offline ->
      "Node_offline"

let to_string e = existential_to_string (Event_type_puppeteer e)

let existential_of_string_exn = function
  | "Log_error" ->
      Event_type_puppeteer Log_error
  | "Node_offline" ->
      Event_type_puppeteer Node_offline
  | _ ->
      failwith "invalid puppeteer event type string"

let existential_to_yojson t = `String (existential_to_string t)

let existential_of_sexp = function
  | Sexp.Atom string ->
      existential_of_string_exn string
  | _ ->
      failwith "invalid sexp"

let sexp_of_existential t = Sexp.Atom (existential_to_string t)

module Existentially_comparable = Comparable.Make (struct
  type t = existential [@@deriving sexp]

  (* We can't derive a comparison for the GADTs in ['a t], so fall back to
     polymorphic comparison. This should be safe to use here as the variants in
     ['a t] are shallow.
  *)
  let compare = Poly.compare
end)

module Map = Existentially_comparable.Map

type event = Event : 'a t * 'a -> event

let type_of_event (Event (t, _)) = Event_type_puppeteer t

(* needs to contain each type in event_types *)
let all_event_types =
  [ Event_type_puppeteer Log_error; Event_type_puppeteer Node_offline ]

let event_type_puppeteer_module :
    type a. a t -> (module Event_type_puppeteer_intf with type t = a) = function
  | Log_error ->
      (module Log_error)
  | Node_offline ->
      (module Node_offline)

let event_to_yojson event =
  let (Event (t, d)) = event in
  let (module Type) = event_type_puppeteer_module t in
  `Assoc [ (to_string t, Type.to_yojson d) ]

let parse_event (message : Puppeteer_message.t) =
  let open Or_error.Let_syntax in
  match message.puppeteer_event_type with
  | Some puppeteer_ev_type ->
      let (Event_type_puppeteer ev_type) =
        existential_of_string_exn puppeteer_ev_type
      in
      let (module Ty) = event_type_puppeteer_module ev_type in
      let%map data = Ty.parse message in
      Event (ev_type, data)
  | None ->
      (* TODO: check log level to ensure it matches error log level *)
      let%map data = Log_error.parse message in
      Event (Log_error, data)

let dispatch_exn : type a b c. a t -> a -> b t -> (b -> c) -> c =
 fun t1 e t2 h ->
  match (t1, t2) with
  | Log_error, Log_error ->
      h e
  | Node_offline, Node_offline ->
      h e
  | _ ->
      failwith "TODO: better error message :)"

(* TODO: tests on sexp and dispatch (etc) against all_event_types *)
