open Core
open Async_kernel

module type Ledger_intf = sig
  include Merkle_ledger.Syncable_intf.S

  val load_ledger : int -> int -> t * string list
end

module type Input_intf = sig
  module Root_hash : sig
    type t [@@deriving bin_io, compare, hash, sexp, compare]

    val equal : t -> t -> bool
  end

  module L : Ledger_intf with type root_hash := Root_hash.t

  module SL :
    Syncable_ledger.S
    with type merkle_tree := L.t
     and type hash := L.hash
     and type root_hash := Root_hash.t
     and type addr := L.addr
     and type merkle_path := L.path
     and type account := L.account

  module SR = SL.Responder
end

module Make
    (Input : Input_intf) (Input' : sig
        val num_accts : int
    end) =
struct
  open Input
  open Input'

  (* not really kosher but the tests are run in-order, so this will get filled
   * in before we need it. *)
  let total_queries = ref None

  let parent_log = Logger.null ()

  let%test "full_sync_entirely_different" =
    let l1, _k1 = L.load_ledger 1 1 in
    let l2, _k2 = L.load_ledger num_accts 2 in
    let desired_root = L.merkle_root l2 in
    let lsync = SL.create l1 ~parent_log in
    let qr = SL.query_reader lsync in
    let aw = SL.answer_writer lsync in
    let seen_queries = ref [] in
    let sr = SR.create l2 (fun q -> seen_queries := q :: !seen_queries) in
    don't_wait_for
      (Linear_pipe.iter_unordered ~max_concurrency:3 qr
         ~f:(fun (_hash, query) ->
           let answ = SR.answer_query sr query in
           let%bind () =
             if match query with What_contents _ -> true | _ -> false then
               Clock_ns.after
                 (Time_ns.Span.randomize (Time_ns.Span.of_ms 0.2)
                    ~percent:(Percent.of_percentage 20.))
             else Deferred.unit
           in
           Linear_pipe.write aw (desired_root, answ) )) ;
    match
      Async.Thread_safe.block_on_async_exn (fun () ->
          SL.fetch lsync desired_root )
    with
    | `Ok mt ->
        total_queries := Some (List.length !seen_queries) ;
        Root_hash.equal desired_root (L.merkle_root mt)
    | `Target_changed _ -> false

  let%test_unit "new_goal_soon" =
    let l1, _k1 = L.load_ledger num_accts 1 in
    let l2, _k2 = L.load_ledger num_accts 2 in
    let l3, _k3 = L.load_ledger num_accts 3 in
    let desired_root = ref @@ L.merkle_root l2 in
    let lsync = SL.create l1 ~parent_log in
    let qr = SL.query_reader lsync in
    let aw = SL.answer_writer lsync in
    let seen_queries = ref [] in
    let sr =
      ref @@ SR.create l2 (fun q -> seen_queries := q :: !seen_queries)
    in
    let ctr = ref 0 in
    don't_wait_for
      (Linear_pipe.iter qr ~f:(fun (hash, query) ->
           if not (Root_hash.equal hash !desired_root) then Deferred.unit
           else
             let res =
               if !ctr = (!total_queries |> Option.value_exn) / 2 then (
                 sr :=
                   SR.create l3 (fun q -> seen_queries := q :: !seen_queries) ;
                 desired_root := L.merkle_root l3 ;
                 SL.new_goal lsync !desired_root ;
                 Deferred.unit )
               else
                 let answ = SR.answer_query !sr query in
                 Linear_pipe.write aw (!desired_root, answ)
             in
             ctr := !ctr + 1 ;
             res )) ;
    match
      Async.Thread_safe.block_on_async_exn (fun () ->
          SL.fetch lsync !desired_root )
    with
    | `Ok _ -> failwith "shouldn't happen"
    | `Target_changed _ -> (
      match
        Async.Thread_safe.block_on_async_exn (fun () ->
            SL.wait_until_valid lsync !desired_root )
      with
      | `Ok mt ->
          [%test_result: Root_hash.t] ~expect:(L.merkle_root l3)
            (L.merkle_root mt)
      | `Target_changed _ -> failwith "the target changed again" )
end

module L3 = Test_ledger.Make (struct
  let depth = 3
end)

module L16 = Test_ledger.Make (struct
  let depth = 16
end)

module L10 = Test_ledger.Make (struct
  let depth = 10
end)

let%test_unit "exhaustive depth=10 testing" =
  for i = 3 to 1 lsl 10 do
    let module M =
      Make
        (L10)
        (struct
          let num_accts = i
        end)
    in
    ()
  done

module TestL3_3 =
  Make
    (L3)
    (struct
      let num_accts = 3
    end)

module TestL3_8 =
  Make
    (L3)
    (struct
      let num_accts = 8
    end)

module TestL16_2 =
  Make
    (L16)
    (struct
      let num_accts = 2
    end)

module TestL16_3 =
  Make
    (L16)
    (struct
      let num_accts = 3
    end)

module TestL16_20 =
  Make
    (L16)
    (struct
      let num_accts = 20
    end)

module TestL16_1024 =
  Make
    (L16)
    (struct
      let num_accts = 1024
    end)

module TestL16_1025 =
  Make
    (L16)
    (struct
      let num_accts = 80
    end)

module TestL16_65536 =
  Make
    (L16)
    (struct
      let num_accts = 65536
    end)

module DB3 = Test_db.Make (struct
  let depth = 3
end)

module DB16 = Test_db.Make (struct
  let depth = 16
end)

module TestDB3_3 =
  Make
    (DB3)
    (struct
      let num_accts = 3
    end)

module TestDB3_8 =
  Make
    (DB3)
    (struct
      let num_accts = 8
    end)

module TestDB16_20 =
  Make
    (DB16)
    (struct
      let num_accts = 20
    end)

module TestDB16_1024 =
  Make
    (DB16)
    (struct
      let num_accts = 1024
    end)

module TestDB16_1026 =
  Make
    (DB16)
    (struct
      let num_accts = 1026
    end)
