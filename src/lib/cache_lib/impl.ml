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

    val remove : 'elt t -> 'elt -> unit Or_error.t
  end = struct
    type 'a t = {name: string; set: 'a Hash_set.t; logger: Logger.t}

    let name {name; _} = name

    let create (type elt) ~name ~logger
        (module Elt : Hash_set.Elt_plain with type t = elt) : elt t =
      let set =
        Hash_set.create ~growth_allowed:true ?size:None (module Elt) ()
      in
      {name; set; logger}

    let register t x =
      let%map () = Hash_set.strict_add t.set x in
      Cached.create ~logger:t.logger t x

    let mem t x = Hash_set.mem t.set x

    let remove t x = Hash_set.strict_remove t.set x
  end
  
  and Cached : sig
    include Intf.Cached.S

    val create : logger:Logger.t -> 'elt Cache.t -> 'elt -> ('elt, 'elt) t
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
          ; parent: ('c, 'a) t
          ; mutable consumed: bool }
          -> ('b, 'a) t
      | Phantom : 'a -> ('a, _) t

    let phantom x = Phantom x

    let rec cache : type a b. (a, b) t -> b Cache.t = function
      | Base x -> x.cache
      | Derivative x -> cache x.parent
      | Phantom _ -> failwith "cannot access cache of phantom Cached.t"

    let value : type a b. (a, b) t -> a = function
      | Base x -> x.data
      | Derivative x -> x.mutant
      | Phantom x -> x

    let original : type a b. (a, b) t -> b = function
      | Base x -> x.data
      | Derivative x -> x.original
      | Phantom _ -> failwith "cannot access original of phantom Cached.t"

    let was_consumed : type a b. (a, b) t -> bool = function
      | Base x -> x.consumed
      | Derivative x -> x.consumed
      | Phantom _ ->
          failwith "cannot determine consumption of phantom Cached.t"

    let mark_consumed : type a b. (a, b) t -> unit = function
      | Base x -> x.consumed <- true
      | Derivative x -> x.consumed <- true
      | Phantom _ -> failwith "cannot set consumption of phantom Cached.t"

    let create ~logger cache data =
      let t = Base {data; cache; consumed= false} in
      Gc.Expert.add_finalizer (Heap_block.create_exn t) (fun block ->
          let t = Heap_block.value block in
          if not (was_consumed t) then
            Inputs.handle_unconsumed_cache_item ~logger
              ~cache_name:(Cache.name cache) ) ;
      t

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
      Derivative
        {original= original t; mutant= f (value t); parent= t; consumed= false}

    let invalidate (type a b) (t : (a, b) t) : a Or_error.t =
      consume t ;
      let%map () = Cache.remove (cache t) (original t) in
      value t

    let lift_deferred (type a b) (t : (a Deferred.t, b) t) :
        (a, b) t Deferred.t =
      let open Deferred.Let_syntax in
      let%map x = peek t in
      transform t ~f:(Fn.const x)

    let lift_result (type a b) (t : ((a, 'e) Result.t, b) t) :
        ((a, b) t, 'e) Result.t =
      match peek t with
      | Ok x -> Ok (transform t ~f:(Fn.const x))
      | Error err ->
          (* TODO: should this log something if there was an error? *)
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
    let%test_unit "cached objects do not trigger unconsumption hook when \
                   invalidated" =
      let collected = ref false in
      let module Cache_lib = Make (struct
        let handle_unconsumed_cache_item ~logger:_ ~cache_name:_ =
          collected := true
      end) in
      let logger = Logger.create () in
      let cache =
        Cache_lib.Cache.create ~name:"test" ~logger (module String)
      in
      (fun () ->
        let x =
          Or_error.ok_exn
            (Cache_lib.Cache.register cache Bytes.(create 10 |> to_string))
        in
        ignore (Cache_lib.Cached.invalidate x) )
        () ;
      Gc.full_major () ;
      assert (not !collected)

    let%test_unit "cached objects are garbage collected independently of caches"
        =
      let collected = ref false in
      let module Cache_lib = Make (struct
        let handle_unconsumed_cache_item ~logger:_ ~cache_name:_ =
          collected := true
      end) in
      let logger = Logger.create () in
      let cache =
        Cache_lib.Cache.create ~name:"test" ~logger (module String)
      in
      (fun () ->
        ignore
          (Or_error.ok_exn
             (Cache_lib.Cache.register cache Bytes.(create 10 |> to_string)))
        )
        () ;
      Gc.full_major () ;
      assert !collected

    let%test_unit "cached objects are garbage collected independently of data"
        =
      let collected = ref false in
      let module Cache_lib = Make (struct
        let handle_unconsumed_cache_item ~logger:_ ~cache_name:_ =
          collected := true
      end) in
      let logger = Logger.create () in
      let data = Bytes.(create 10 |> to_string) in
      (fun () ->
        let cache =
          Cache_lib.Cache.create ~name:"test" ~logger (module String)
        in
        ignore (Or_error.ok_exn (Cache_lib.Cache.register cache data)) )
        () ;
      Gc.full_major () ;
      assert !collected

    let%test_unit "cached objects are not unexpectedly garbage collected" =
      let collected = ref false in
      let module Cache_lib = Make (struct
        let handle_unconsumed_cache_item ~logger:_ ~cache_name:_ =
          collected := true
      end) in
      let logger = Logger.create () in
      let data = Bytes.(create 10 |> to_string) in
      let cache =
        Cache_lib.Cache.create ~name:"test" ~logger (module String)
      in
      let cached = Or_error.ok_exn (Cache_lib.Cache.register cache data) in
      Gc.full_major () ;
      assert (not !collected) ;
      ignore (Cache_lib.Cached.invalidate cached)
  end )
