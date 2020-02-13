open Coda_base
open Async_kernel
open Core_kernel

(** This is a useful helper for breaking recursion in records. *)
module Set_once : sig
  type 'a t

  val create : unit -> 'a t

  val set : 'a t -> 'a -> unit

  val get : 'a t -> 'a
end = struct
  type 'a t = 'a option ref

  let create () = ref None

  let set t x =
    match !t with
    | None ->
        t := Some x
    | Some _ ->
        failwith "Set_once.set: cannot set a value twice"

  let get t =
    match !t with
    | None ->
        failwith "Set_once.get: value was not previously set"
    | Some x ->
        x
end

module type Rules_intf = sig
  val max_latency : Block_time.Span.t

  val flush_capacity : int

  val max_capacity : int
end

module Check_rules_invariants (Rules : Rules_intf) = struct
  let () = assert (Rules.max_capacity >= Rules.flush_capacity)
end

module type Accumulator_intf = sig
  type t

  type data

  type emission

  type 'a creator

  val create_map : (t -> 'a) -> 'a creator

  val create : t creator

  val size : t -> int

  val add : t -> data -> unit

  val flush : t -> emission
end

module type Worker_intf = sig
  type t

  type input

  val dispatch : t -> input -> unit Deferred.t
end

module Make_sequential_accumulator (T : sig
  type t
end) :
  Accumulator_intf
  with type data = T.t
   and type emission = T.t list
   and type 'a creator = unit -> 'a = struct
  open DynArray

  type nonrec t = T.t t

  type data = T.t

  type emission = T.t list

  type 'a creator = unit -> 'a

  let create_map f () = f (create ())

  let create = create_map Fn.id

  let add = add

  let size = length

  let flush t =
    let emission = to_list t in
    clear t ; compact t ; emission
end

module type Intf = sig
  type t

  type data

  type worker

  type 'a accumulator_creator

  type 'a creator =
    (time_controller:Block_time.Controller.t -> worker:worker -> 'a)
    accumulator_creator

  val create_map : (t -> 'a) -> 'a creator

  val create : t creator

  val send : t -> data -> unit

  val close_gracefully : t -> unit Deferred.t
end

module Make
    (Rules : Rules_intf)
    (Accumulator : Accumulator_intf)
    (Worker : Worker_intf with type input = Accumulator.emission) :
  Intf
  with type data := Accumulator.data
   and type worker := Worker.t
   and type 'a accumulator_creator := 'a Accumulator.creator = struct
  include Check_rules_invariants (Rules)

  type t =
    { accumulator: Accumulator.t
    ; worker: Worker.t
          (* timer unfortunately needs to be mutable to break recursion *)
    ; timer: Block_time.Timer.t Set_once.t
    ; mutable flush_job: unit Deferred.t option
    ; mutable closed: bool }

  type 'a creator =
    (time_controller:Block_time.Controller.t -> worker:Worker.t -> 'a)
    Accumulator.creator

  let check_for_overflow t =
    if Accumulator.size t.accumulator > Rules.max_capacity then
      failwith "TODO: encode overflow handling logic into Rules"

  let should_flush t = Accumulator.size t.accumulator >= Rules.flush_capacity

  let flush t =
    let rec flush_job t =
      Block_time.Timer.reset (Set_once.get t.timer) ;
      let emission = Accumulator.flush t.accumulator in
      let%bind () = Worker.dispatch t.worker emission in
      if should_flush t then flush_job t
      else (
        t.flush_job <- None ;
        Deferred.unit )
    in
    assert (t.flush_job = None) ;
    if Accumulator.size t.accumulator > 0 then
      t.flush_job <- Some (flush_job t)

  let create_map f =
    Accumulator.create_map (fun accumulator ~time_controller ~worker ->
        let t =
          { accumulator
          ; worker
          ; timer= Set_once.create ()
          ; flush_job= None
          ; closed= false }
        in
        Set_once.set t.timer
        @@ Block_time.Timer.create time_controller Rules.max_latency
             ~f:(fun () -> if t.flush_job = None then flush t) ;
        f t )

  let create = create_map Fn.id

  let send t data =
    if t.closed then
      failwith "attempt to write to batch supervisor after closed" ;
    Accumulator.add t.accumulator data ;
    if should_flush t && t.flush_job = None then flush t
    else check_for_overflow t

  let close_gracefully t =
    Block_time.Timer.stop (Set_once.get t.timer) ;
    t.closed <- true ;
    let%bind () = Option.value t.flush_job ~default:Deferred.unit in
    flush t ;
    Option.value t.flush_job ~default:Deferred.unit
end
