open Core_kernel
open Async_kernel

module type S = sig
  include Coda.Ledger_builder_controller_intf
end

module Make (Ledger_builder_hash : sig
  type t
end) (Ledger_hash : sig
  type t [@@deriving eq]
end) (Ledger_proof : sig
  type t
end) (Ledger_builder_transition : sig
  type t [@@deriving eq, sexp, compare, bin_io]

  val gen : t Quickcheck.Generator.t
end)
(Ledger : sig
  type t

  val merkle_root : t -> Ledger_hash.t
end)
(Ledger_builder : sig
  type t [@@deriving bin_io]

  val ledger : t -> Ledger.t

  val create : unit -> t

  val copy : t -> t

  val apply :
       t
    -> Ledger_builder_transition.t
    -> ((Ledger_hash.t * Ledger_proof.t) option) Deferred.Or_error.t
end)  (Ledger_hash : sig
  type t [@@deriving bin_io]
end)  (State : sig
  type t [@@deriving eq, sexp, compare, bin_io]

  val root_hash : t -> Ledger_hash.t

  val gen : t Quickcheck.Generator.t
end) (Valid_transaction : sig
  type t [@@deriving eq, sexp, compare, bin_io]

  val gen : t Quickcheck.Generator.t
end) (Net : sig
  include Coda.Ledger_builder_io_intf
          with type ledger_builder := Ledger_builder.t
           and type ledger_builder_hash := Ledger_builder_hash.t
           and type state := State.t
end) (Snark_pool : sig
  type t
end)
(Store : Storage.With_checksum_intf) =
struct
  module Config = struct
    type t =
      { keep_count: int [@default 50]
      ; parent_log: Logger.t
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
    [@@deriving eq, compare, bin_io, sexp]

    let gen =
      let open Quickcheck.Generator.Let_syntax in
      let%map transactions = Quickcheck.Generator.list Valid_transaction.gen
      and transition = Ledger_builder_transition.gen
      and state = State.gen in
      {transactions; transition; state}
  end

  module Witness_tree =
    Ktree.Make (Witness)
      (struct
        let k = 50
      end)

  module State = struct
    type t =
      { locked_ledger_builder: Ledger_hash.t * Ledger_builder.t
      ; longest_branch_tip: Ledger_hash.t * Ledger_builder.t
      ; mutable ktree: Witness_tree.t option
      (* TODO: This impl assumes we have the original Ouroboros assumption. In
         order to work with the Praos assumption we'll need to keep a linked
         list as well at the prefix of size (#blocks possible out of order)
       *)
      }
    [@@deriving bin_io]

    let create genesis_ledger : t =
      let root = Ledger.merkle_root genesis_ledger in
      { locked_ledger_builder= (root, Ledger_builder.create ())
      ; longest_branch_tip= (root, Ledger_builder.create ())
      ; ktree= None }
  end

  type t = {ledger_builder_io: Net.t; log: Logger.t; state: State.t}

  let best_tip tree =
    Witness_tree.longest_path tree |> List.last_exn

  let locked_head tree =
    Witness_tree.longest_path tree |> List.hd_exn

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
    let t =
      { ledger_builder_io= Net.create net
      ; log= Logger.child config.parent_log "ledger_builder_controller"
      ; state }
    in
    let strongest_ledgers =
      Linear_pipe.filter_map_unordered ~max_concurrency:1 config.ledger_builder_transitions ~f:
        (fun (transactions, state, transition) ->
          (* The following assertion will always pass because we're supposed
             to have validated the witness upstream this pipe (see coda.ml) *)
          let assert_valid_state (witness : Witness.t) builder =
            assert (Ledger_hash.equal (State.root_hash witness.state) (Ledger.merkle_root @@ Ledger_builder.ledger builder) );
            ()
          in

          let old_tree = t.state.ktree in
          (* When we get a new transition adjust our ktree *)
          (t.state).ktree
          <- Witness_tree.add t.state.ktree {transactions; transition; state};

          (* Adjust the locked_ledger if necessary *)
          let%bind () =
            let new_head = locked_head t.state.ktree in
            if (Witness.equal (locked_head old_tree) new_head) then return () else (
              let%map (_, _) = Ledger_builder.apply t.state.locked_ledger_builder new_head in
              assert_valid_state new_head t.state.locked_ledger_builder;
              ()
            )
          in

          (* Adjust the longest_branch_tip if necessary *)
          let tip = path |> List.last_exn in
          if Witness.equal tip t.best_tip then
            None
          else
            Some 
          )

  let strongest_ledgers
end
