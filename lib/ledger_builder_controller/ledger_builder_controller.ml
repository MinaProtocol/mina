open Core_kernel
open Async_kernel

module type Inputs_intf = sig
  module Ledger_builder_hash : sig
    type t [@@deriving eq, bin_io]
  end

  module Ledger_hash : sig
    type t [@@deriving bin_io]
  end

  module Ledger_builder_transition : sig
    type t [@@deriving eq, sexp, compare, bin_io]
  end

  module Ledger : sig
    type t

    val merkle_root : t -> Ledger_hash.t
  end

  module Ledger_builder : sig
    type t [@@deriving bin_io]

    type proof

    val ledger : t -> Ledger.t

    val create : Ledger.t -> t

    val copy : t -> t

    val hash : t -> Ledger_builder_hash.t

    val apply :
         t
      -> Ledger_builder_transition.t
      -> (Ledger_hash.t * proof) option Deferred.Or_error.t
  end

  module State_hash : sig
    type t [@@deriving eq]
  end

  module Strength : sig
    type t

    val ( < ) : t -> t -> bool

    val ( > ) : t -> t -> bool

    val ( = ) : t -> t -> bool
  end

  module State : sig
    type t [@@deriving eq, sexp, compare, bin_io]

    val ledger_builder_hash : t -> Ledger_builder_hash.t

    val hash : t -> State_hash.t

    val strength : t -> Strength.t

    val previous_state_hash : t -> State_hash.t

    val ledger_hash : t -> Ledger_hash.t
  end

  module Valid_transaction : sig
    type t [@@deriving eq, sexp, compare, bin_io]
  end

  module Net : sig
    include Coda.Ledger_builder_io_intf
            with type ledger_builder := Ledger_builder.t
             and type ledger_builder_hash := Ledger_builder_hash.t
             and type state := State.t
  end

  module Snark_pool : sig
    type t
  end

  module Store : Storage.With_checksum_intf
end

module Interruptible = struct
  module T = struct
    type 'a t = {stopped: bool ref; d: 'a Deferred.t option}

    let bind t ~f =
      if !(t.stopped) then {t with d= None}
      else
        let d' =
          Deferred.bind (Option.value_exn t.d) ~f:(fun a ->
              let t' = f a in
              t.stopped := !(t'.stopped) ;
              Option.value_exn t'.d )
        in
        {t with d= Some d'}

    let interrupt t = t.stopped := true

    let return a = {stopped= ref false; d= Some (Deferred.return a)}

    let lift d = {stopped= ref false; d= Some d}

    let map = `Define_using_bind
  end

  module M = Monad.Make (T)
  include T
  include M
end

module Make (Inputs : Inputs_intf) : sig
  include Coda.Ledger_builder_controller_intf
          with type ledger_builder := Inputs.Ledger_builder.t
           and type ledger_builder_hash := Inputs.Ledger_builder_hash.t
           and type ledger_builder_transition :=
                      Inputs.Ledger_builder_transition.t
           and type ledger := Inputs.Ledger.t
           and type transaction_with_valid_signature :=
                      Inputs.Valid_transaction.t
           and type net := Inputs.Net.net
           and type state := Inputs.State.t
           and type snark_pool := Inputs.Snark_pool.t

  val ledger_builder_io : t -> Inputs.Net.t
end = struct
  open Inputs

  module Config = struct
    type t =
      { parent_log: Logger.t
      ; net_deferred: Net.net Deferred.t
      ; ledger_builder_transitions:
          (Valid_transaction.t list * State.t * Ledger_builder_transition.t)
          Linear_pipe.Reader.t
      ; genesis_ledger: Ledger.t
      ; disk_location: string
      ; snark_pool: Snark_pool.t }
    [@@deriving make]
  end

  module Witness = struct
    type t =
      { transactions: Valid_transaction.t list
      ; transition: Ledger_builder_transition.t
      ; state: State.t }
    [@@deriving eq, compare, bin_io, sexp, fields]

    let ledger_builder_hash {state} = State.ledger_builder_hash state

    let state_hash {state} = State.hash state

    let strength {state} = State.strength state

    let previous_state_hash {state} = State.previous_state_hash state

    let gen txn_gen transition_gen state_gen =
      let open Quickcheck.Generator.Let_syntax in
      let%map transactions = Quickcheck.Generator.list txn_gen
      and transition = transition_gen
      and state = state_gen in
      {transactions; transition; state}
  end

  module Witness_tree =
    Ktree.Make (Witness)
      (struct
        let k = 50
      end)

  module State = struct
    type t =
      { mutable locked_ledger_builder: Ledger_builder.t
      ; mutable longest_branch_tip: Ledger_builder.t
      ; mutable ktree: Witness_tree.t option
      (* TODO: This impl assumes we have the original Ouroboros assumption. In
         order to work with the Praos assumption we'll need to keep a linked
         list as well at the prefix of size (#blocks possible out of order)
       *)
      }
    [@@deriving bin_io]

    let create genesis_ledger : t =
      { locked_ledger_builder= Ledger_builder.create genesis_ledger
      ; longest_branch_tip= Ledger_builder.create genesis_ledger
      ; ktree= None }
  end

  type t =
    { ledger_builder_io: Net.t
    ; log: Logger.t
    ; state: State.t
    ; strongest_ledgers:
        (Ledger_builder.t * Inputs.State.t) Linear_pipe.Reader.t }

  let ledger_builder_io {ledger_builder_io} = ledger_builder_io

  let best_tip tree = Witness_tree.longest_path tree |> List.last_exn

  let locked_head tree = Witness_tree.longest_path tree |> List.hd_exn

  (* The following assertion will always pass without extra checks because
     we're supposed to have validated the witness upstream this pipe (see
     coda.ml) *)
  let assert_valid_state (witness: Witness.t) builder =
    assert (
      Ledger_builder_hash.equal
        (Witness.ledger_builder_hash witness)
        (Ledger_builder.hash builder) ) ;
    ()

  let create (config: Config.t) =
    let log = Logger.child config.parent_log "ledger_builder_controller" in
    let storage_controller =
      Store.Controller.create ~parent_log:log [%bin_type_class : State.t]
    in
    let%bind state =
      match%map Store.load storage_controller config.disk_location with
      | Ok state -> state
      | Error (`IO_error e) ->
          Logger.info log "Ledger failed to load from storage %s; recreating"
            (Error.to_string_hum e) ;
          State.create config.genesis_ledger
      | Error `No_exist ->
          Logger.info log "Ledger doesn't exist in storage; recreating" ;
          State.create config.genesis_ledger
      | Error `Checksum_no_match ->
          Logger.warn log "Checksum failed when loading ledger, recreating" ;
          State.create config.genesis_ledger
    in
    let%map net = config.net_deferred in
    let ledger_builder_io = Net.create net in
    let force_apply_transition lb tip =
      match%map Ledger_builder.apply lb tip with
      | Ok _ -> ()
      | Error e ->
          failwithf
            "Invariant failed, we should have validated the data before here %s"
            (Error.to_string_hum e) ()
    in
    (* Here we effectfully listen to transitions and emit what we belive are
       the strongest ledger_builders *)
    let possibly_works =
      Linear_pipe.filter_map_unordered ~max_concurrency:1
        config.ledger_builder_transitions ~f:
        (fun (transactions, s, transition) ->
          match state.ktree with
          (* If we've seen no data from the network, we can only do nothing here *)
          | None ->
              state.ktree
              <- Some
                   (Witness_tree.single {transactions; transition; state= s}) ;
              return None
          | Some old_tree ->
              let witness_to_add : Witness.t =
                {transactions; transition; state= s}
              in
              let p_eq_previous_state_hash (w: Witness.t) =
                State_hash.equal (Witness.state_hash w)
                  (Witness.previous_state_hash witness_to_add)
              in
              (* When we get a new transition adjust our ktree *)
              match
                Witness_tree.add old_tree witness_to_add
                  ~parent:p_eq_previous_state_hash
              with
              | `No_parent ->
                  if
                    Strength.( > ) (Inputs.State.strength s)
                      (Witness.strength (best_tip old_tree))
                  then (
                    (* TODO: We'll need the full history in order to trust that
                      the ledger builder we get is actually valid. See #285 *)
                    (* TODO: This should be interruptible as well, when Corey's
                      PR is ready to integrate, we should do that *)
                    match%map
                      Net.get_ledger_builder_at_hash ledger_builder_io
                        (Inputs.State.ledger_builder_hash s)
                    with
                    | Ok (lb, _) ->
                        let new_tree =
                          Witness_tree.single
                            {transactions; transition; state= s}
                        in
                        state.ktree <- Some new_tree ;
                        state.locked_ledger_builder <- lb ;
                        Some (Witness_tree.longest_path new_tree)
                    | Error e ->
                        Logger.warn log
                          "Couldn't get ledger_builder_at_hash %s"
                          (Error.to_string_hum e) ;
                        None )
                  else return None
              | `Repeat -> return None
              | `Added new_tree ->
                  state.ktree <- Some new_tree ;
                  (* Adjust the locked_ledger if necessary *)
                  let%map () =
                    let new_head = locked_head new_tree in
                    if Witness.equal (locked_head old_tree) new_head then
                      return ()
                    else
                      let lb = state.locked_ledger_builder in
                      let%map () =
                        force_apply_transition lb (Witness.transition new_head)
                      in
                      assert_valid_state new_head lb ;
                      ()
                  in
                  (* Adjust the longest_branch_tip if necessary *)
                  let new_best_path = Witness_tree.longest_path new_tree in
                  let new_tip = List.last_exn new_best_path in
                  if Witness.equal (best_tip old_tree) new_tip then None
                  else Some new_best_path )
    in
    let iter_and_interrupt p ~f =
      let w : 'a Interruptible.t option ref = ref None in
      Linear_pipe.iter p ~f:(fun a ->
          Option.iter !w ~f:(fun w -> Interruptible.interrupt w) ;
          let w', d = f a in
          w := w' ;
          d )
    in
    let strongest_ledgers_reader, strongest_ledgers_writer =
      Linear_pipe.create ()
    in
    don't_wait_for
      (iter_and_interrupt possibly_works ~f:(fun new_best_path ->
           let new_tip = new_best_path |> List.last_exn in
           let curr_tip_hash = Ledger_builder.hash state.longest_branch_tip in
           let is_lb_hash_curr_tip w =
             Ledger_builder_hash.equal curr_tip_hash
               (Witness.ledger_builder_hash w)
           in
           if is_lb_hash_curr_tip new_tip then
             ( None
             , Linear_pipe.write strongest_ledgers_writer
                 (state.longest_branch_tip, Witness.state new_tip) )
           else
             let apply lb transition =
               Interruptible.lift (force_apply_transition lb transition)
             in
             let w =
               let best_lb, path =
                 match
                   List.findi new_best_path ~f:(fun i tip ->
                       is_lb_hash_curr_tip tip )
                 with
                 | None ->
                     ( Ledger_builder.copy state.locked_ledger_builder
                     , new_best_path )
                 | Some (i, _) ->
                     ( Ledger_builder.copy state.longest_branch_tip
                     , List.drop new_best_path i )
               in
               let open Interruptible.Let_syntax in
               let lb = best_lb in
               let%map () =
                 List.fold path ~init:(Interruptible.return ()) ~f:
                   (fun acc w ->
                     let%bind () = acc in
                     apply lb w.Witness.transition )
               in
               state.longest_branch_tip <- lb ;
               Linear_pipe.write_or_exn ~capacity:3 strongest_ledgers_writer
                 strongest_ledgers_reader
                 (lb, Witness.state new_tip)
             in
             (Some w, Deferred.return ()) )) ;
    { ledger_builder_io
    ; log= Logger.child config.parent_log "ledger_builder_controller"
    ; strongest_ledgers= strongest_ledgers_reader
    ; state }

  let strongest_ledgers {strongest_ledgers} = strongest_ledgers

  (** Returns a reference to a ledger_builder denoted by [hash], materialize a
   fresh ledger at a specific hash if necessary *)
  let local_get_ledger t hash =
    let find_state tree lb_hash =
      Witness_tree.find_map tree ~f:(fun w ->
          if Ledger_builder_hash.equal (Witness.ledger_builder_hash w) lb_hash
          then Some (Witness.state w)
          else None )
    in
    Option.map t.state.ktree ~f:(fun tree ->
        (* First let's see if we have an easy case *)
        let locked = t.state.locked_ledger_builder in
        let tip = t.state.longest_branch_tip in
        let attempt_easy w err_msg_name =
          match find_state tree (Ledger_builder.hash w) with
          | None ->
              return
              @@ Or_error.errorf
                   "This was our %s, but we didn't witness the state"
                   err_msg_name
          | Some state -> return @@ Ok (w, state)
        in
        if Ledger_builder_hash.equal hash (Ledger_builder.hash locked) then
          attempt_easy locked "locked_head"
        else if Ledger_builder_hash.equal hash (Ledger_builder.hash tip) then
          attempt_easy tip "tip"
        else
          (* Now we need to materialize it *)
          match
            Witness_tree.path tree ~f:(fun w ->
                Ledger_builder_hash.equal hash (Witness.ledger_builder_hash w)
            )
          with
          | Some path ->
              let lb_start = t.state.locked_ledger_builder in
              assert_valid_state (List.hd_exn path) lb_start ;
              let lb = Ledger_builder.copy lb_start in
              (* Fast-forward the lb *)
              let%map () =
                Deferred.List.fold ~init:() (List.tl_exn path) ~f:(fun () w ->
                    let open Deferred.Let_syntax in
                    match%map Ledger_builder.apply lb w.Witness.transition with
                    | Ok None -> ()
                    | Ok (Some _) -> ()
                    (* We've already verified that all the patches can be
                       applied successfully before we added to the ktree, so we
                       can force-unwrap here *)
                    | Error e ->
                        failwithf
                          "We should have already verified patches can be \
                           applied: %s"
                          (Error.to_string_hum e) () )
              in
              assert (Ledger_builder_hash.equal (Ledger_builder.hash lb) hash) ;
              Ok (lb, List.last_exn path |> Witness.state)
          | None -> return (Or_error.error_string "Hash not found locally") )
    |> Option.value
         ~default:(return @@ Or_error.error_string "Haven't seen any nodes yet")
end

let%test_module "test" =
  ( module struct
    module Inputs = struct
      module Ledger_builder_hash = Int
      module Ledger_hash = Int
      (* A ledger_builder transition will just add to a "ledger" integer *)
      module Ledger_builder_transition = Int

      module Ledger = struct
        include Int

        let merkle_root t = t
      end

      module Ledger_builder = struct
        type t = int ref [@@deriving eq, sexp, bin_io]

        type proof = ()

        let ledger t = !t

        let create x = ref x

        let copy t = ref !t

        let hash t = !t

        let apply (t: t) (x: Ledger_builder_transition.t) =
          t := x ;
          return (Ok (Some (x, ())))
      end

      module State_hash = Int
      module Strength = Int

      module State = struct
        type t =
          { ledger_builder_hash: Ledger_builder_hash.t
          ; hash: State_hash.t
          ; strength: Strength.t
          ; previous_state_hash: State_hash.t
          ; ledger_hash: Ledger_hash.t }
        [@@deriving eq, sexp, compare, bin_io, fields]
      end

      (* Not sure if we even need this *)
      module Valid_transaction = Int

      module Net = struct
        type t = State.t State_hash.Table.t

        type net = unit

        let create () = State_hash.Table.create ()

        let get_ledger_builder_at_hash t hash =
          return (Ok (ref hash, State_hash.Table.find_exn t hash))
      end

      module Snark_pool = struct
        type t = unit
      end

      module Store = Storage.Memory
    end

    module Lbc = Make (Inputs)

    let transition x parent strength =
      ( []
      , { Inputs.State.ledger_builder_hash= x
        ; hash= x
        ; strength
        ; ledger_hash= x
        ; previous_state_hash= parent }
      , x )

    let config transitions =
      let ledger_builder_transitions = Linear_pipe.of_list transitions in
      Lbc.Config.make ~parent_log:(Logger.create ()) ~net_deferred:(return ())
        ~ledger_builder_transitions ~genesis_ledger:0
        ~disk_location:"/tmp/test_lbc_disk" ~snark_pool:()

    let take_map ~f p cnt =
      let rec go acc cnt =
        if cnt = 0 then return acc
        else
          match%bind Linear_pipe.read p with
          | `Eof -> return acc
          | `Ok x -> go (f x :: acc) (cnt - 1)
      in
      go [] cnt >>| List.rev

    let assert_strongest_ledgers lbc_deferred ~transitions ~expected =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind lbc = lbc_deferred in
          let%map results =
            take_map (Lbc.strongest_ledgers lbc) (List.length expected) ~f:
              (fun (lb, _) -> !lb )
          in
          assert (List.equal results expected ~equal:Int.equal) )

    let%test_unit "strongest_ledgers updates appropriately when new_states \
                   flow in within tree" =
      let transitions =
        let f = transition in
        [ f 0 (-1) 0
        ; f 1 0 1
        ; f 2 1 2
        ; f 3 0 1
        ; f 4 0 1
        ; f 5 2 3
        ; f 6 1 2
        ; f 7 5 4 ]
      in
      let config = config transitions in
      assert_strongest_ledgers (Lbc.create config) ~transitions
        ~expected:[1; 2; 5; 7]

    let%test_unit "strongest_ledgers updates appropriately using the network" =
      let transitions =
        let f = transition in
        [ f 0 (-1) 0
        ; f 1 0 1
        ; f 2 1 2
        ; f 3 8 6 (* This one comes over the network *)
        ; f 4 2 3
          (* Here this would have extended, if we didn't kill the tree *)
        ; f 5 3 7
        (* Now we attach to the one from the network *) ]
      in
      let config = config transitions in
      let lbc_deferred =
        let%map lbc = Lbc.create config in
        Inputs.State_hash.Table.add_exn
          (Lbc.ledger_builder_io lbc)
          ~key:3
          ~data:
            { Inputs.State.ledger_builder_hash= 3
            ; hash= 3
            ; strength= 6
            ; ledger_hash= 3
            ; previous_state_hash= 8 } ;
        lbc
      in
      assert_strongest_ledgers lbc_deferred ~transitions ~expected:[1; 2; 3; 5]

    let%test_unit "local_get_ledger can materialize a ledger locally" =
      let transitions =
        let f = transition in
        [ f 0 (-1) 0
        ; f 1 0 1
        ; f 2 1 2
        ; f 3 0 1
        ; f 4 0 1
        ; f 5 2 3
        ; f 6 1 2
        ; f 7 5 4 ]
      in
      let config = config transitions in
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind lbc = Lbc.create config in
          (* Drain the first few strongest_ledgers *)
          let%bind _ =
            take_map (Lbc.strongest_ledgers lbc) 4 ~f:(fun _ -> ())
          in
          match%map Lbc.local_get_ledger lbc 6 with
          | Ok (lb, s) -> assert (!lb = 6)
          | Error e ->
              failwithf "Unexpected error %s" (Error.to_string_hum e) () )
  end )
