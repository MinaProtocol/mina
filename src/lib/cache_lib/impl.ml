open Async_kernel
open Core_kernel
open Or_error.Let_syntax

module type Inputs_intf = sig
  val handle_unconsumed_cache_item :
    logger:Logger.t -> cache_name:string -> unit
end

module Make (Inputs : Inputs_intf) : Intf.Main.S = struct
  module rec Cache : sig
    include Intf.Cache.S with module Cached := Cached

    val logger : _ t -> Logger.t

    val remove : 'elt t -> 'elt -> unit Or_error.t
  end = struct
    type 'a t = {name: string; set: 'a Hash_set.t; logger: Logger.t}

    let name {name; _} = name

    let logger {logger; _} = logger

    let create (type elt) ~name ~logger
        (module Elt : Hash_set.Elt_plain with type t = elt) : elt t =
      let set =
        Hash_set.create ~growth_allowed:true ?size:None (module Elt) ()
      in
      let logger = Logger.child logger ("Cache:" ^ name) in
      {name; set; logger}

    let register t x =
      let%map () = Hash_set.strict_add t.set x in
      Cached.create t x

    let mem t x = Hash_set.mem t.set x

    let remove t x = Hash_set.strict_remove t.set x
  end
  
  and Cached : sig
    include Intf.Cached.S

    val create : 'elt Cache.t -> 'elt -> ('elt, 'elt) t
  end = struct
    type (_, _) t =
      | Base :
          { data: 'a
          ; cache: 'a Cache.t
          ; mutable consumed: bool }
          -> ('a, 'a) t
      | Derivative :
          { original: 'a
          ; mutant: 'b
          ; cache: 'a Cache.t
          ; mutable consumed: bool }
          -> ('b, 'a) t
      | Pure : 'a -> ('a, _) t

    let pure x = Pure x

    let cache : type a b. (a, b) t -> b Cache.t = function
      | Base x -> x.cache
      | Derivative x -> x.cache
      | Pure _ -> failwith "cannot access cache of phantom Cached.t"

    let value : type a b. (a, b) t -> a = function
      | Base x -> x.data
      | Derivative x -> x.mutant
      | Pure x -> x

    let original : type a b. (a, b) t -> b = function
      | Base x -> x.data
      | Derivative x -> x.original
      | Pure _ -> failwith "cannot access original of phantom Cached.t"

    let was_consumed : type a b. (a, b) t -> bool = function
      | Base x -> x.consumed
      | Derivative x -> x.consumed
      | Pure _ -> failwith "cannot determine consumption of phantom Cached.t"

    let mark_consumed : type a b. (a, b) t -> unit = function
      | Base x -> x.consumed <- true
      | Derivative x -> x.consumed <- true
      | Pure _ -> failwith "cannot set consumption of phantom Cached.t"

    let attach_finalizer t =
      Gc.Expert.add_finalizer (Heap_block.create_exn t) (fun block ->
          let t = Heap_block.value block in
          if not (was_consumed t) then
            let cache = cache t in
            Inputs.handle_unconsumed_cache_item ~logger:(Cache.logger cache)
              ~cache_name:(Cache.name cache) ) ;
      t

    let create cache data =
      attach_finalizer (Base {data; cache; consumed= false})

    let assert_not_consumed t msg =
      let open Error in
      if was_consumed t then raise (of_string msg)

    let peek (type a b) (t : (a, b) t) : a =
      assert_not_consumed t "cannot peek at consumed Cached.t" ;
      value t

    let consume (type a b) (t : (a, b) t) : unit =
      assert_not_consumed t "cannot consume Cached.t twice" ;
      mark_consumed t

    let transform (type a b) (t : (a, b) t) ~(f : a -> 'c) : ('c, b) t =
      consume t ;
      attach_finalizer
        (Derivative
           { original= original t
           ; mutant= f (value t)
           ; cache= cache t
           ; consumed= false })

    let invalidate (type a b) (t : (a, b) t) : a Or_error.t =
      consume t ;
      let%map () = Cache.remove (cache t) (original t) in
      value t

    let sequence_deferred (type a b) (t : (a Deferred.t, b) t) :
        (a, b) t Deferred.t =
      let open Deferred.Let_syntax in
      let%map x = peek t in
      transform t ~f:(Fn.const x)

    let sequence_result (type a b) (t : ((a, 'e) Result.t, b) t) :
        ((a, b) t, 'e) Result.t =
      match peek t with
      | Ok x -> Ok (transform t ~f:(Fn.const x))
      | Error err ->
          Logger.error
            (Cache.logger (cache t))
            "Cached.sequence_result called on an already consumed Cached.t" ;
          ignore (invalidate t) ;
          Error err
  end

  module Transmuter_cache :
    Intf.Transmuter_cache.F
    with module Cached := Cached
     and module Cache := Cache = struct
    module Make
        (Transmuter : Intf.Transmuter.S)
        (Name : Intf.Constant.S with type t := string) :
      Intf.Transmuter_cache.S
      with module Cached := Cached
       and module Cache := Cache
       and type source = Transmuter.Source.t
       and type target = Transmuter.Target.t = struct
      type source = Transmuter.Source.t

      type target = Transmuter.Target.t

      type t = Transmuter.Target.t Cache.t

      let create ~logger =
        Cache.create ~logger ~name:Name.t (module Transmuter.Target)

      let register t x =
        let%map target = Cache.register t (Transmuter.transmute x) in
        Cached.transform target ~f:(Fn.const x)

      let mem t x = Cache.mem t (Transmuter.transmute x)
    end
  end
end

let%test_module "cache_lib test instance" =
  ( module struct
    let dropped_cache_items = ref 0

    include Make (struct
      let handle_unconsumed_cache_item ~logger:_ ~cache_name:_ =
        incr dropped_cache_items
    end)

    let setup () = dropped_cache_items := 0

    let with_item ~f =
      Bytes.create 10 |> Bytes.to_string
      |> String.map ~f:(fun _ -> Char.of_int_exn (Random.bits () land 0xff))
      |> f

    let with_cache ~logger ~f =
      Cache.create ~name:"test" ~logger (module String) |> f

    let%test_unit "cached objects do not trigger unconsumption hook when \
                   invalidated" =
      setup () ;
      let logger = Logger.create () in
      with_cache ~logger ~f:(fun cache ->
          with_item ~f:(fun data ->
              let x = Or_error.ok_exn (Cache.register cache data) in
              ignore (Cached.invalidate x) ) ;
          Gc.full_major () ;
          assert (!dropped_cache_items = 0) )

    let%test_unit "cached objects are garbage collected independently of caches"
        =
      setup () ;
      let logger = Logger.create () in
      with_cache ~logger ~f:(fun cache ->
          with_item ~f:(fun data ->
              ignore (Or_error.ok_exn (Cache.register cache data)) ) ;
          Gc.full_major () ;
          assert (!dropped_cache_items = 1) )

    let%test_unit "cached objects are garbage collected independently of data"
        =
      setup () ;
      let logger = Logger.create () in
      with_item ~f:(fun data ->
          with_cache ~logger ~f:(fun cache ->
              ignore (Or_error.ok_exn (Cache.register cache data)) ) ;
          Gc.full_major () ;
          assert (!dropped_cache_items = 1) )

    let%test_unit "cached objects are not unexpectedly garbage collected" =
      setup () ;
      let logger = Logger.create () in
      with_cache ~logger ~f:(fun cache ->
          with_item ~f:(fun data ->
              let cached = Or_error.ok_exn (Cache.register cache data) in
              Gc.full_major () ;
              assert (!dropped_cache_items = 0) ;
              ignore (Cached.invalidate cached) ) ) ;
      Gc.full_major () ;
      assert (!dropped_cache_items = 0)

    let%test_unit "garbage collection of derived cached objects do not \
                   trigger unconsumption handler for parents" =
      setup () ;
      let logger = Logger.create () in
      with_cache ~logger ~f:(fun cache ->
          with_item ~f:(fun data ->
              Cache.register cache data |> Or_error.ok_exn
              |> Cached.transform ~f:(Fn.const 5)
              |> Cached.transform ~f:(Fn.const ())
              |> ignore ) ;
          Gc.full_major () ;
          assert (!dropped_cache_items = 1) )

    let%test_unit "properly invalidated derived cached objects do not trigger \
                   any unconsumption handler calls" =
      setup () ;
      let logger = Logger.create () in
      with_cache ~logger ~f:(fun cache ->
          with_item ~f:(fun data ->
              Cache.register cache data |> Or_error.ok_exn
              |> Cached.transform ~f:(Fn.const 5)
              |> Cached.transform ~f:(Fn.const ())
              |> Cached.invalidate |> ignore ) ;
          Gc.full_major () ;
          assert (!dropped_cache_items = 0) )

    let%test_unit "deriving a cached object consumes it's parent, disallowing \
                   use of it" =
      setup () ;
      let logger = Logger.create () in
      with_cache ~logger ~f:(fun cache ->
          with_item ~f:(fun data ->
              let src = Or_error.ok_exn (Cache.register cache data) in
              let derivation = Cached.transform src ~f:(Fn.const 5) in
              assert (
                try
                  ignore (Cached.invalidate src) ;
                  false
                with _ -> true ) ;
              ignore (Cached.invalidate derivation) ) ;
          Gc.full_major () ;
          assert (!dropped_cache_items = 0) )
  end )
