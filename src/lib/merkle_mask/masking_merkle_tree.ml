(* masking_merkle_tree.ml -- implements a mask in front of a Merkle tree; see
   RFC 0004 and docs/specs/merkle_tree.md *)

open Core

(* builds a Merkle tree mask; it's a Merkle tree, with some additional
   operations
*)
module Make (Inputs : Inputs_intf.S) = struct
  open Inputs
  module Location = Location

  (* Free_list depends on this module alias. Change with care. *)
  module Addr = Location.Addr

  (** Invariant is that parent is None in unattached mask and `Some` in the
      attached one. We can capture this with a GADT but there's some annoying
      issues with bin_io to do so *)
  module Parent = struct
    type t = (Base.t, string (* Location where null was set *)) Result.t
    [@@deriving sexp]
  end

  module Detached_parent_signal = struct
    type t = unit Async.Ivar.t

    let sexp_of_t (_ : t) = Sexp.List []

    let t_of_sexp (_ : Sexp.t) : t = Async.Ivar.create ()
  end

  type account_location = Location.t [@@deriving sexp]

  type maps_t =
    { accounts : Account.t Location_binable.Map.t
    ; token_owners : Account_id.t Token_id.Map.t
    ; hashes : Hash.t Addr.Map.t
    ; locations : account_location Account_id.Map.t
    }
  [@@deriving sexp]

  (** Merges second maps object into the first one,
      potentially overwriting some keys *)
  let maps_merge base { accounts; token_owners; hashes; locations } =
    let combine ~key:_ _ v = v in
    { accounts = Map.merge_skewed ~combine base.accounts accounts
    ; token_owners = Map.merge_skewed ~combine base.token_owners token_owners
    ; hashes = Map.merge_skewed ~combine base.hashes hashes
    ; locations = Map.merge_skewed ~combine base.locations locations
    }

  module Free_list = Merkle_ledger.Free_list.Make (Location)

  (** Structure managing cache accumulated since the "base" ledger.

    Its purpose is to optimize lookups through a few consequitive masks
    (by using just one map lookup instead of [O(number of masks)] map lookups).

    With a number of mask around 290, this trick gives a sizeable performance improvement.

    Accumulator is inherited from parent mask if [set_parent ~accumulated] of a child
    is called with [to_acumulated t] of the parent mask.

    Structure maintains two caches: [current] and [next], with the former
    being always a superset of a latter and [next] always being superset of mask's contents
    from [maps] field. These two caches are being rotated according to a certain rule
    to ensure that not much more memory is used within accumulator as compared to the case
    when [accumulated = None] for all masks.

    Garbage-collection/rotation mechanism for [next] and [current] is based on idea to set
    [current] to [next] and [next] to [t.maps] when the mask at which accumulation of [next] started
    became detached. *)
  type accumulated_t =
    { mutable current : maps_t
          (** Currently used cache: contains a superset of contents of masks from base ledger to the current mask *)
    ; mutable next : maps_t
          (** Cache that will be used after the current cache is garbage-collected *)
    ; base : Base.t  (** Base ledger *)
    ; detached_next_signal : Detached_parent_signal.t
          (** Ivar for mask from which next was started being built.
             When it's fulfilled, [next] becomes [current] (because next contains superset of all masks from [baser],
            [detached_signal] is reset to the current mask and [next] is set to contents of the current mask.
          *)
    }

  (* Available locations for allocations are tracked using 2 fields:
     1. [fill_frontier] is the fill frontier, that is, on the right of this
        location, all locations are available
     2. [freed] represents all available locations in  [0, fill_frontier].
        Locations are added to this only after having been removed.
  *)
  type t =
    { uuid : Uuid.Stable.V1.t
    ; mutable parent : Parent.t
    ; detached_parent_signal : Detached_parent_signal.t
    ; mutable fill_frontier : Location.t option
    ; mutable freed : Free_list.t
    ; depth : int
    ; mutable maps : maps_t
          (* If present, contains maps containing changes both for this mask
             and for a few ancestors. This is used as a lookup cache. *)
    ; mutable accumulated : (accumulated_t[@sexp.opaque]) option
    ; mutable is_committing : bool
    }
  [@@deriving sexp]

  type unattached = t [@@deriving sexp]

  let empty_maps () =
    { accounts = Location_binable.Map.empty
    ; token_owners = Token_id.Map.empty
    ; hashes = Addr.Map.empty
    ; locations = Account_id.Map.empty
    }

  let create ~depth () =
    { uuid = Uuid_unix.create ()
    ; parent = Error __LOC__
    ; detached_parent_signal = Async.Ivar.create ()
    ; fill_frontier = None
    ; depth
    ; accumulated = None
    ; maps = empty_maps ()
    ; is_committing = false
    ; freed = Free_list.empty
    }

  let has_parent { parent; _ } = Result.is_ok parent

  let get_uuid { uuid; _ } = uuid

  module Attached = struct
    type parent = Base.t [@@deriving sexp]

    type t = unattached [@@deriving sexp]

    module Path = Base.Path
    module Addr = Location.Addr
    module Location = Location

    type index = int

    type path = Path.t

    exception
      Dangling_parent_reference of
        Uuid.t * (* Location where null was set*) string

    let unset_parent ?(trigger_signal = true) ~loc t =
      assert (has_parent t) ;
      t.parent <- Error loc ;
      if trigger_signal then (
        t.accumulated <- None ;
        Async.Ivar.fill_if_empty t.detached_parent_signal () ) ;
      t

    let assert_is_attached t =
      match t.parent with
      | Error loc ->
          raise (Dangling_parent_reference (t.uuid, loc))
      | Ok _ ->
          ()

    let detached_signal t = Async.Ivar.read t.detached_parent_signal

    let get_parent ({ parent = opt; _ } as t) =
      assert_is_attached t ; Result.ok_or_failwith opt

    (** Check whether mask from which we started computing the [next]
        accumulator is detached and [current] can be garbage-collected. *)
    let actualize_accumulated t =
      Option.iter t.accumulated
        ~f:(fun { detached_next_signal; next; base; current = _ } ->
          if Async.Ivar.is_full detached_next_signal then
            t.accumulated <-
              Some
                { next = t.maps
                ; current = next
                ; detached_next_signal = t.detached_parent_signal
                ; base
                } )

    (** When [accumulated] is not configured, returns current [t.maps] and parent.
        Otherwise, returns the [current] accumulator and [base]. *)
    let maps_and_ancestor t =
      actualize_accumulated t ;
      match t.accumulated with
      | Some { current; base; _ } ->
          (current, base)
      | None ->
          (t.maps, get_parent t)

    (** Either copies accumulated or initializes it with the parent being used as the [base]. *)
    let to_accumulated t =
      actualize_accumulated t ;
      match (t.accumulated, t.parent) with
      | Some { base; detached_next_signal; next; current }, _ ->
          { base; detached_next_signal; next; current }
      | None, Ok base ->
          { base
          ; next = t.maps
          ; current = t.maps
          ; detached_next_signal = t.detached_parent_signal
          }
      | None, Error loc ->
          raise (Dangling_parent_reference (t.uuid, loc))

    let get_uuid t = assert_is_attached t ; t.uuid

    let get_directory t =
      assert_is_attached t ;
      Base.get_directory (Result.ok_or_failwith t.parent)

    let depth t = assert_is_attached t ; t.depth

    let update_maps ~f t =
      t.maps <- f t.maps ;
      Option.iter t.accumulated ~f:(fun acc ->
          acc.current <- f acc.current ;
          acc.next <- f acc.next )

    module Freed = struct
      let add t loc = t.freed <- Free_list.Location.add t.freed loc

      let _remove t loc = t.freed <- Free_list.Location.remove t.freed loc

      let mem t loc = Free_list.Location.mem t.freed loc
    end

    (* A location is free if
       - the fill interval is empty, aka all locations are available
       - the location is outside of the fill interval
       - it is within the fill interval and it has been freed
    *)
    let is_free t loc =
      Option.is_none t.fill_frontier
      || Location.( > ) loc (Option.value_exn t.fill_frontier)
      || Freed.mem t loc

    let self_set_hash t address hash =
      update_maps t ~f:(fun maps ->
          { maps with hashes = Map.set maps.hashes ~key:address ~data:hash } )

    let set_inner_hash_at_addr_exn t address hash =
      assert_is_attached t ;
      assert (Addr.depth address <= t.depth) ;
      self_set_hash t address hash

    let self_set_location t account_id location =
      (* This function is only correct when the free list is empty *)
      assert (Free_list.is_empty t.freed) ;
      update_maps t ~f:(fun maps ->
          { maps with
            locations = Map.set maps.locations ~key:account_id ~data:location
          } ) ;

      (* if account is at a hitherto-unused location, that
         becomes the current location
      *)
      match t.fill_frontier with
      | None ->
          t.fill_frontier <- Some location
      | Some loc ->
          if Location.( > ) location loc then t.fill_frontier <- Some location

    let self_set_account t location account =
      update_maps t ~f:(fun maps ->
          { maps with
            accounts = Map.set maps.accounts ~key:location ~data:account
          } ) ;
      self_set_location t (Account.identifier account) location

    let self_set_token_owner t token_id account_id =
      update_maps t ~f:(fun maps ->
          { maps with
            token_owners =
              Map.set maps.token_owners ~key:token_id ~data:account_id
          } )

    (* a read does a lookup in the account_tbl; if that fails, delegate to
       parent *)
    let get t location =
      assert_is_attached t ;
      let maps, ancestor = maps_and_ancestor t in
      match Map.find maps.accounts location with
      | Some account ->
          Some account
      | None ->
          let is_empty =
            (* The location does not mark an account for this mask, maybe it has been freed *)
            Freed.mem t location
            ||
            match t.fill_frontier with
            | None ->
                true
            | Some fill_frontier ->
                let address = Location.to_path_exn location in
                let current_address = Location.to_path_exn fill_frontier in
                Addr.is_further_right ~than:current_address address
          in
          if is_empty then None else Base.get ancestor location

    (* TODO: Filter out freed locations before sending to parent *)
    let self_find_or_batch_lookup self_find lookup_parent t ids =
      assert_is_attached t ;
      let maps, ancestor = maps_and_ancestor t in
      let self_found_or_none = List.map ids ~f:(self_find ~maps) in
      let not_found =
        List.filter_map self_found_or_none ~f:(function
          | id, None ->
              Some id
          | _ ->
              None )
      in
      let from_parent = lookup_parent ancestor not_found in
      List.fold_map self_found_or_none ~init:from_parent
        ~f:(fun from_parent (id, self_found) ->
          match (self_found, from_parent) with
          | None, r :: rest ->
              (rest, r)
          | Some acc_found_locally, _ ->
              (from_parent, (id, acc_found_locally))
          | _ ->
              failwith "unexpected number of results from DB" )
      |> snd

    let get_batch t =
      let self_find ~maps id =
        let res = Map.find maps.accounts id in
        let res =
          if Option.is_none res then
            let is_empty =
              Option.value_map ~default:true t.fill_frontier
                ~f:(fun fill_frontier ->
                  let address = Location.to_path_exn id in
                  let current_address = Location.to_path_exn fill_frontier in
                  Addr.is_further_right ~than:current_address address )
            in
            Option.some_if is_empty None
          else Some res
        in
        (id, res)
      in
      self_find_or_batch_lookup self_find Base.get_batch t

    let empty_hash =
      Empty_hashes.extensible_cache (module Hash) ~init_hash:Hash.empty_account

    let self_path_get_hash ~hashes ~fill_frontier height address =
      match Map.find hashes address with
      | Some hash ->
          Some hash
      | None ->
          let is_empty =
            match fill_frontier with
            | None ->
                true
            | Some fill_frontier ->
                let current_address = Location.to_path_exn fill_frontier in
                Addr.is_further_right ~than:current_address address
          in
          if is_empty then Some (empty_hash height) else None

    let rec self_path_impl ~element ~depth address =
      let height = Addr.height ~ledger_depth:depth address in
      if height >= depth then Some []
      else
        let%bind.Option el = element height address in
        let%bind.Option parent_address = Addr.parent address |> Or_error.ok in
        let%map.Option rest = self_path_impl ~element ~depth parent_address in
        el :: rest

    let self_merkle_path ~hashes ~fill_frontier =
      let element height address =
        let sibling = Addr.sibling address in
        let dir = Location.last_direction address in
        let%map.Option sibling_hash =
          self_path_get_hash ~hashes ~fill_frontier height sibling
        in
        Direction.map dir ~left:(`Left sibling_hash) ~right:(`Right sibling_hash)
      in
      self_path_impl ~element

    let self_wide_merkle_path ~hashes ~fill_frontier =
      let element height address =
        let sibling = Addr.sibling address in
        let dir = Location.last_direction address in
        let%bind.Option sibling_hash =
          self_path_get_hash ~hashes ~fill_frontier height sibling
        in
        let%map.Option self_hash =
          self_path_get_hash ~hashes ~fill_frontier height address
        in
        Direction.map dir
          ~left:(`Left (self_hash, sibling_hash))
          ~right:(`Right (sibling_hash, self_hash))
      in
      self_path_impl ~element

    (* fixup_merkle_path patches a Merkle path reported by the parent,
       overriding with hashes which are stored in the mask *)
    let fixup_merkle_path ~hashes ~address:init =
      let f address =
        (* first element in the path contains hash at sibling of address *)
        let sibling_mask_hash = Map.find hashes (Addr.sibling address) in
        let parent_addr = Addr.parent_exn address in
        let open Option in
        function
        | `Left h ->
            (parent_addr, `Left (value sibling_mask_hash ~default:h))
        | `Right h ->
            (parent_addr, `Right (value sibling_mask_hash ~default:h))
      in
      Fn.compose snd @@ List.fold_map ~init ~f

    (* fixup_merkle_path patches a Merkle path reported by the parent,
       overriding with hashes which are stored in the mask *)
    let fixup_wide_merkle_path ~hashes ~address:init =
      let f address =
        (* element in the path contains hash at sibling of address *)
        let sibling_mask_hash = Map.find hashes (Addr.sibling address) in
        let self_mask_hash = Map.find hashes address in
        let parent_addr = Addr.parent_exn address in
        let open Option in
        function
        | `Left (h_l, h_r) ->
            ( parent_addr
            , `Left
                ( value self_mask_hash ~default:h_l
                , value sibling_mask_hash ~default:h_r ) )
        | `Right (h_l, h_r) ->
            ( parent_addr
            , `Right
                ( value sibling_mask_hash ~default:h_l
                , value self_mask_hash ~default:h_r ) )
      in
      Fn.compose snd @@ List.fold_map ~init ~f

    (* the following merkle_path_* functions report the Merkle path for the
       mask *)

    let merkle_path_at_addr_exn t address =
      assert_is_attached t ;
      let maps, ancestor = maps_and_ancestor t in
      match
        self_merkle_path ~depth:t.depth ~hashes:maps.hashes
          ~fill_frontier:t.fill_frontier address
      with
      | Some path ->
          path
      | None ->
          let parent_merkle_path =
            Base.merkle_path_at_addr_exn ancestor address
          in
          fixup_merkle_path ~hashes:maps.hashes parent_merkle_path ~address

    let merkle_path_at_index_exn t index =
      merkle_path_at_addr_exn t (Addr.of_int_exn ~ledger_depth:t.depth index)

    let merkle_path t location =
      merkle_path_at_addr_exn t (Location.to_path_exn location)

    let path_batch_impl ~fixup_path ~self_lookup ~base_lookup t locations =
      assert_is_attached t ;
      let maps, ancestor = maps_and_ancestor t in
      let self_paths =
        List.map locations ~f:(fun location ->
            let address = Location.to_path_exn location in
            self_lookup ~hashes:maps.hashes ~fill_frontier:t.fill_frontier
              ~depth:t.depth address
            |> Option.value_map
                 ~default:(Either.Second (location, address))
                 ~f:Either.first )
      in
      let all_parent_paths =
        let locs =
          List.filter_map self_paths ~f:(function
            | Either.First _ ->
                None
            | Either.Second (location, _) ->
                Some location )
        in
        if List.is_empty locs then [] else base_lookup ancestor locs
      in
      let f parent_paths = function
        | Either.First path ->
            (parent_paths, path)
        | Either.Second (_, address) ->
            let path =
              fixup_path ~hashes:maps.hashes ~address (List.hd_exn parent_paths)
            in
            (List.tl_exn parent_paths, path)
      in
      snd @@ List.fold_map ~init:all_parent_paths ~f self_paths

    let merkle_path_batch =
      path_batch_impl ~base_lookup:Base.merkle_path_batch
        ~self_lookup:self_merkle_path ~fixup_path:fixup_merkle_path

    let wide_merkle_path_batch =
      path_batch_impl ~base_lookup:Base.wide_merkle_path_batch
        ~self_lookup:self_wide_merkle_path ~fixup_path:fixup_wide_merkle_path

    (* given a Merkle path corresponding to a starting address, calculate
       addresses and hashes for each node affected by the starting hash; that is,
       along the path from the account address to root *)
    let addresses_and_hashes_from_merkle_path_exn merkle_path starting_address
        starting_hash : (Addr.t * Hash.t) list =
      (* The accum list is never empty by construction *)
      let[@warning "-8"] get_addresses_hashes height
          ((last_address, last_hash) :: _ as accum) node =
        let next_address = Addr.parent_exn last_address in
        let next_hash =
          match node with
          | `Left sibling_hash ->
              Hash.merge ~height last_hash sibling_hash
          | `Right sibling_hash ->
              Hash.merge ~height sibling_hash last_hash
        in
        (next_address, next_hash) :: accum
      in
      List.foldi merkle_path
        ~init:[ (starting_address, starting_hash) ]
        ~f:get_addresses_hashes

    (* use mask Merkle root, if it exists, else get from parent *)
    let merkle_root t =
      assert_is_attached t ;
      let maps, ancestor = maps_and_ancestor t in
      match Map.find maps.hashes (Addr.root ()) with
      | Some hash ->
          hash
      | None ->
          Base.merkle_root ancestor

    let remove_account_location_update_hashes t account location =
      let account_id = Account.identifier account in
      t.maps <-
        { t.maps with
          (* remove account and key from tables *)
          accounts =
            Map.remove t.maps.accounts location (* update token info. *)
        ; token_owners =
            Token_id.Map.remove t.maps.token_owners
              (Account_id.derive_token_id ~owner:account_id)
        ; locations = Map.remove t.maps.locations account_id
        } ;
      let () =
        match t.fill_frontier with
        | Some curr_loc ->
            if Location.equal location curr_loc then
              match Location.prev location with
              | Some prev_loc ->
                  (* On removal, if the account is at the fill frontier, we need to
                     remove all contiguous freed locations next to this
                     frontier. *)
                  let freed, opt_loc =
                    Free_list.Location.remove_all_contiguous t.freed prev_loc
                  in
                  t.freed <- freed ;
                  t.fill_frontier <- opt_loc
              | None ->
                  t.fill_frontier <- None
            else
              (* save newly unused location to local stack *)
              Freed.add t location
        | None ->
            (* no current location indicates no insertion ever occurred *)
            ()
      in
      (* update hashes *)
      let account_address = Location.to_path_exn location in
      let account_hash = Hash.empty_account in
      let merkle_path = merkle_path t location in
      (* FIXME: Instead of creating a list then iterating over it we could do a
         single iteration pass. *)
      let addresses_and_hashes =
        addresses_and_hashes_from_merkle_path_exn merkle_path account_address
          account_hash
      in
      List.iter addresses_and_hashes ~f:(fun (addr, hash) ->
          self_set_hash t addr hash )

    let remove_account_and_update_hashes t location =
      (* remove account and key from tables *)
      let account = Option.value_exn (Map.find t.maps.accounts location) in
      remove_account_location_update_hashes t account location

    let remove_location t location =
      assert_is_attached t ;
      match get t location with
      | Some account ->
          remove_account_location_update_hashes t account location
      | None ->
          ()

    let set_freed t locs =
      let freed = Free_list.Location.of_list locs in
      t.freed <- freed

    (* FIXME: Makes this more efficient. Avoid the back and forth betwee lists
       and sets *)
    let get_freed t =
      let freed =
        match Base.get_freed (get_parent t) with
        | [] ->
            t.freed
        | freed ->
            let freed' =
              Map.fold t.maps.accounts ~init:[] ~f:(fun ~key ~data:_ acc ->
                  if List.mem freed key ~equal:Location.equal then acc
                  else key :: acc )
            in
            Free_list.union t.freed (Free_list.Location.of_list freed')
      in
      Free_list.Location.to_list freed

    let set_account_unsafe t location account =
      assert_is_attached t ;
      self_set_account t location account ;
      (* Update token info. *)
      let account_id = Account.identifier account in
      self_set_token_owner t
        (Account_id.derive_token_id ~owner:account_id)
        account_id

    (* a write writes only to the mask, parent is not involved need to update
       both account and hash pieces of the mask *)
    let set t location account =
      assert_is_attached t ;
      set_account_unsafe t location account ;
      (* Update merkle path. *)
      let account_address = Location.to_path_exn location in
      let account_hash = Hash.hash_account account in
      let merkle_path = merkle_path t location in
      let addresses_and_hashes =
        addresses_and_hashes_from_merkle_path_exn merkle_path account_address
          account_hash
      in
      List.iter addresses_and_hashes ~f:(fun (addr, hash) ->
          self_set_hash t addr hash )

    (* if the mask's parent sets an account, we can prune an entry in the mask
       if the account in the parent is the same in the mask

        returns true is the mask is in the state of being comitted *)
    let parent_set_notify t account =
      assert_is_attached t ;
      Option.value ~default:()
      @@ let%bind.Option location =
           Map.find t.maps.locations (Account.identifier account)
         in
         let%bind.Option existing_account = Map.find t.maps.accounts location in
         let%map.Option () =
           Option.some_if (Account.equal account existing_account) ()
         in
         remove_account_and_update_hashes t location

    let parent_remove_notify t account =
      match Map.find t.maps.locations (Account.identifier account) with
      | None ->
          (* Inform that the location is free *)
          ()
      | Some location -> (
          match Map.find t.maps.accounts location with
          | Some existing_account ->
              if Account.equal account existing_account then
                remove_account_location_update_hashes t account location
          | None ->
              (* If we have a loc -> account binding in maps.accounts, there
                 needs to be an account -> loc association in the
                 maps.location *)
              assert false )

    let is_committing t = t.is_committing

    (* as for accounts, we see if we have it in the mask, else delegate to
       parent *)
    let get_hash t addr =
      assert_is_attached t ;
      let maps, ancestor = maps_and_ancestor t in
      match Map.find maps.hashes addr with
      | Some hash ->
          Some hash
      | None -> (
          try
            let hash = Base.get_inner_hash_at_addr_exn ancestor addr in
            Some hash
          with _ -> None )

    let get_hash_batch_exn t locations =
      assert_is_attached t ;
      let maps, ancestor = maps_and_ancestor t in
      let self_hashes_rev =
        List.rev_map locations ~f:(fun location ->
            (location, Map.find maps.hashes (Location.to_path_exn location)) )
      in
      let parent_locations_rev =
        List.filter_map self_hashes_rev ~f:(fun (location, hash) ->
            match hash with None -> Some location | Some _ -> None )
      in
      let parent_hashes_rev =
        if List.is_empty parent_locations_rev then []
        else Base.get_hash_batch_exn ancestor parent_locations_rev
      in
      let rec recombine self_hashes_rev parent_hashes_rev acc =
        match (self_hashes_rev, parent_hashes_rev) with
        | [], [] ->
            acc
        | (_location, None) :: self_hashes_rev, hash :: parent_hashes_rev
        | (_location, Some hash) :: self_hashes_rev, parent_hashes_rev ->
            recombine self_hashes_rev parent_hashes_rev (hash :: acc)
        | _, [] | [], _ ->
            assert false
      in
      recombine self_hashes_rev parent_hashes_rev []

    (* transfer state from mask to parent; flush local state *)
    let commit t =
      assert (not t.is_committing) ;
      t.is_committing <- true ;
      assert_is_attached t ;
      let parent = get_parent t in
      let old_root_hash = merkle_root t in
      let account_data = Map.to_alist t.maps.accounts in
      t.maps <-
        { accounts = Location_binable.Map.empty
        ; hashes = Addr.Map.empty
        ; token_owners = Token_id.Map.empty
        ; locations = Account_id.Map.empty
        } ;
      (* We might write data over accounts that were previously freed - this
         should be transmitted by the parents so that the free list of the
         child is alway a newer version of the one from the parent.

         It assumes we never write to the parent when it has at least a child.

         In that we just need to copy the free list of the child to the one of
         the parent.

         However in the child we might have newly freed location, so we need to
         "erase" these ones from the parent. These are locations that are in the
         child but *not* in the parent.

         Erase = FL(C) \ FL(P)
      *)
      Base.set_freed parent (Free_list.Location.to_list t.freed) ;
      Base.set_batch parent account_data ;
      Debug_assert.debug_assert (fun () ->
          [%test_result: Hash.t]
            ~message:
              "Parent merkle root after committing should be the same as the \
               old one in the mask"
            ~expect:old_root_hash (Base.merkle_root parent) ;
          [%test_result: Hash.t]
            ~message:"Merkle root of the mask should delegate to the parent now"
            ~expect:(merkle_root t) (Base.merkle_root parent) ) ;
      t.is_committing <- false

    (* copy tables in t; use same parent *)
    let copy t =
      { uuid = Uuid_unix.create ()
      ; parent = Ok (get_parent t)
      ; detached_parent_signal = Async.Ivar.create ()
      ; fill_frontier = t.fill_frontier
      ; depth = t.depth
      ; maps = t.maps
      ; accumulated =
          Option.map t.accumulated ~f:(fun acc ->
              { base = acc.base
              ; detached_next_signal = acc.detached_next_signal
              ; next = acc.next
              ; current = acc.current
              } )
      ; is_committing = false
      ; freed = Free_list.empty
      }

    let max_filled t =
      assert_is_attached t ;
      Option.value_map
        (Base.max_filled (get_parent t))
        ~default:t.fill_frontier
        ~f:(fun parent_loc ->
          match t.fill_frontier with
          | None ->
              Some parent_loc
          | Some our_loc -> (
              match (parent_loc, our_loc) with
              | Account parent_addr, Account our_addr ->
                  (* Addr.compare is Bitstring.compare, essentially String.compare *)
                  let loc =
                    if Addr.compare parent_addr our_addr >= 0 then parent_loc
                    else our_loc
                  in
                  Some loc
              | (Generic _ | Hash _), Account _
              | Account _, (Generic _ | Hash _)
              | (Generic _ | Hash _), (Generic _ | Hash _) ->
                  failwith
                    "max_filled: expected account locations for the parent and \
                     mask" ) )

    let is_compact t =
      assert_is_attached t ;
      Free_list.is_empty t.freed && Base.is_compact (get_parent t)

    let drop_accumulated t = t.accumulated <- None

    include Merkle_ledger.Util.Make (struct
      module Location = Location
      module Location_binable = Location_binable
      module Key = Key
      module Token_id = Token_id
      module Account_id = Account_id
      module Account = Account
      module Hash = Hash
      module Balance = Balance

      module Base = struct
        type nonrec t = t

        let get = get

        let max_filled = max_filled

        let is_compact = is_compact
      end

      let ledger_depth = depth

      let location_of_account_addr addr = Location.Account addr

      let location_of_hash_addr addr = Location.Hash addr

      let get_hash t location =
        Option.value_exn (get_hash t (Location.to_path_exn location))

      let set_raw_hash_batch t locations_and_hashes =
        assert_is_attached t ;
        List.iter locations_and_hashes ~f:(fun (location, hash) ->
            self_set_hash t (Location.to_path_exn location) hash )

      let set_location_batch ~last_location t account_to_location_list =
        t.fill_frontier <- Some last_location ;
        Mina_stdlib.Nonempty_list.iter account_to_location_list
          ~f:(fun (key, data) -> self_set_location t key data)

      let set_raw_account_batch t locations_and_accounts =
        assert_is_attached t ;
        List.iter locations_and_accounts ~f:(fun (location, account) ->
            let account_id = Account.identifier account in
            self_set_token_owner t
              (Account_id.derive_token_id ~owner:account_id)
              account_id ;
            self_set_account t location account )
    end)

    let set_batch_accounts t addresses_and_accounts =
      assert_is_attached t ;
      set_batch_accounts t addresses_and_accounts

    (* set accounts in mask *)
    let set_all_accounts_rooted_at_exn t address (accounts : Account.t list) =
      assert_is_attached t ;
      set_all_accounts_rooted_at_exn t address accounts

    let token_owner t tid =
      assert_is_attached t ;
      let maps, ancestor = maps_and_ancestor t in
      match Map.find maps.token_owners tid with
      | Some id ->
          Some id
      | None ->
          Base.token_owner ancestor tid

    let token_owners (t : t) : Account_id.Set.t =
      assert_is_attached t ;
      let maps, ancestor = maps_and_ancestor t in
      let mask_owners =
        Map.fold maps.token_owners ~init:Account_id.Set.empty
          ~f:(fun ~key:_tid ~data:owner acc -> Set.add acc owner)
      in
      Set.union mask_owners (Base.token_owners ancestor)

    let tokens t pk =
      assert_is_attached t ;
      let maps, ancestor = maps_and_ancestor t in
      let mask_tokens =
        Map.keys maps.locations
        |> List.filter_map ~f:(fun aid ->
               if Key.equal pk (Account_id.public_key aid) then
                 Some (Account_id.token_id aid)
               else None )
        |> Token_id.Set.of_list
      in
      Set.union mask_tokens (Base.tokens ancestor pk)

    let num_accounts t =
      assert_is_attached t ;
      match t.fill_frontier with
      | None ->
          0
      | Some location -> (
          match location with
          | Account addr ->
              Addr.to_int addr + 1
          | Generic _ | Hash _ ->
              failwith "Expected mask current location to represent an account"
          )

    let location_of_account t account_id =
      assert_is_attached t ;
      let maps, ancestor = maps_and_ancestor t in
      let mask_result = Map.find maps.locations account_id in
      match mask_result with
      | Some _ as locopt ->
          locopt
      | None -> (
          (* This account was never touched by this mask, let's see whether the
             parent knows anything about it *)
          match Base.location_of_account ancestor account_id with
          | Some loc as locopt ->
              if is_free t loc then None else locopt
          | None ->
              None )

    let remove_account t account =
      let id = Account.identifier account in
      match location_of_account t id with
      | Some location ->
          remove_location t location
      | None ->
          ()

    let location_of_account_batch t =
      self_find_or_batch_lookup
        (fun ~maps id ->
          (id, Option.map ~f:Option.some @@ Map.find maps.locations id) )
        Base.location_of_account_batch t

    (* Adds specified accounts to the mask by loading them from parent ledger.

       Could be useful for transaction processing when to pre-populate mask with the
       accounts used in processing a transaction (or a block) to ensure there are not loaded
       from parent on each lookup. I.e. these accounts will be cached in mask and accessing
       them during processing of a transaction won't use disk I/O.
    *)
    let unsafe_preload_accounts_from_parent t account_ids =
      assert_is_attached t ;
      let locations = location_of_account_batch t account_ids in
      let non_empty_locations = List.filter_map locations ~f:snd in
      let accounts = get_batch t non_empty_locations in
      let all_hash_locations =
        let rec generate_locations account_locations acc =
          match account_locations with
          | [] ->
              acc
          | location :: account_locations -> (
              let address = Location.to_path_exn location in
              match Addr.parent address with
              | Ok parent ->
                  let sibling = Addr.sibling address in
                  generate_locations
                    (Location.Hash parent :: account_locations)
                    (Location.Hash address :: Location.Hash sibling :: acc)
              | Error _ ->
                  (* This is the root. It's somewhat wasteful to add it for
                     every account, but makes this logic simpler.
                  *)
                  generate_locations account_locations
                    (Location.Hash address :: acc) )
        in
        generate_locations non_empty_locations []
      in
      let all_hashes = get_hash_batch_exn t all_hash_locations in
      (* Batch import merkle paths and self hashes. *)
      List.iter2_exn all_hash_locations all_hashes ~f:(fun location hash ->
          let address = Location.to_path_exn location in
          self_set_hash t address hash ) ;
      (* Batch import accounts. *)
      List.iter accounts ~f:(fun (location, account) ->
          match account with
          | None ->
              ()
          | Some account ->
              set_account_unsafe t location account )

    (* not needed for in-memory mask; in the database, it's currently a NOP *)
    let get_inner_hash_at_addr_exn t address =
      assert_is_attached t ;
      assert (Addr.depth address <= t.depth) ;
      get_hash t address |> Option.value_exn

    (* Destroy intentionally does not commit before destroying
       as sometimes this is desired behavior *)
    let close t =
      assert_is_attached t ;
      t.maps <-
        { t.maps with
          accounts = Location_binable.Map.empty
        ; hashes = Addr.Map.empty
        ; locations = Account_id.Map.empty
        } ;
      Async.Ivar.fill_if_empty t.detached_parent_signal ()

    let index_of_account_exn t key =
      assert_is_attached t ;
      let location = location_of_account t key |> Option.value_exn in
      let addr = Location.to_path_exn location in
      Addr.to_int addr

    let get_at_index_exn t index =
      assert_is_attached t ;
      let addr = Addr.of_int_exn ~ledger_depth:t.depth index in
      get t (Location.Account addr) |> Option.value_exn

    let set_at_index_exn t index account =
      assert_is_attached t ;
      let addr = Addr.of_int_exn ~ledger_depth:t.depth index in
      set t (Location.Account addr) account

    let to_list t =
      assert_is_attached t ;
      let num_accounts = num_accounts t in
      Async.Deferred.List.init ~how:`Parallel num_accounts ~f:(fun i ->
          Async.Deferred.return @@ get_at_index_exn t i )

    let to_list_sequential t =
      assert_is_attached t ;
      let num_accounts = num_accounts t in
      List.init num_accounts ~f:(fun i -> get_at_index_exn t i)

    (* keys from this mask and all ancestors *)
    let accounts t =
      assert_is_attached t ;
      let%map.Async.Deferred accts = to_list t in
      List.map accts ~f:Account.identifier |> Account_id.Set.of_list

    let iteri t ~f =
      assert_is_attached t ;
      let num_accounts = num_accounts t in
      Sequence.range ~stop:`exclusive 0 num_accounts
      |> Sequence.iter ~f:(fun i -> f i (get_at_index_exn t i))

    let foldi_with_ignored_accounts t ignored_accounts ~init ~f =
      assert_is_attached t ;
      let maps, ancestor = maps_and_ancestor t in
      let locations_and_accounts = Map.to_alist maps.accounts in
      (* parent should ignore accounts in this mask *)
      let mask_accounts =
        List.map locations_and_accounts ~f:(fun (_loc, acct) ->
            Account.identifier acct )
      in
      let mask_ignored_accounts = Account_id.Set.of_list mask_accounts in
      let all_ignored_accounts =
        Account_id.Set.union ignored_accounts mask_ignored_accounts
      in
      (* in parent, ignore any passed-in ignored accounts and accounts in mask *)
      let parent_result =
        Base.foldi_with_ignored_accounts ancestor all_ignored_accounts ~init ~f
      in
      let f' accum (location, account) =
        (* for mask, ignore just passed-in ignored accounts *)
        if Account_id.Set.mem ignored_accounts (Account.identifier account) then
          accum
        else
          let address = Location.to_path_exn location in
          f address accum account
      in
      List.fold locations_and_accounts ~init:parent_result ~f:f'

    let foldi t ~init ~f =
      assert_is_attached t ;
      foldi_with_ignored_accounts t Account_id.Set.empty ~init ~f

    (* we would want fold_until to combine results from the parent and the mask
       way (1): use the parent result as the init of the mask fold (or
         vice-versa) the parent result may be of different type than the mask
         fold init, so we get a less general type than the signature indicates,
         so compilation fails
       way (2): make the folds independent, but there's not a specified way to
         combine the results
       way (3): load parent accounts into an in-memory list, merge with mask
         accounts, then fold; this becomes intractable if the parent has a large
         number of entries *)
    let fold_until _t ~init:_ ~f:_ ~finish:_ =
      failwith "fold_until: not implemented"

    module For_testing = struct
      let location_in_mask t location =
        assert_is_attached t ;
        Option.is_some (Map.find t.maps.accounts location)

      let address_in_mask t addr =
        assert_is_attached t ;
        Option.is_some (Map.find t.maps.hashes addr)

      let fill_frontier t = t.fill_frontier
    end

    let leftmost_available_slot t =
      match max_filled t with
      | None ->
          let loc =
            let path_to_leftmost_slot =
              List.init t.depth ~f:(fun _ -> Direction.Left)
            in
            Location.Account (Addr.of_directions path_to_leftmost_slot)
          in
          Some loc
      | Some loc ->
          Location.next loc

    (* Finds the next available location in the following order of priority:
       - reuse a freed location, due to previously removed data; or
       - use the leftmost available slot *)
    let pop_next_fillable t =
      match Free_list.Location.pop t.freed with
      | Some (loc, freed) ->
          t.freed <- freed ;
          Some loc
      | None ->
          leftmost_available_slot t

    let allocate_new t account =
      match pop_next_fillable t with
      | None ->
          Or_error.error_string "Db_error.Out_of_leaves"
      | Some location ->
          (* `set` calls `self_set_location`, which updates
             the current location *)
          set t location account ;
          Ok (`Added, location)

    (* NB: updates the mutable fill_frontier field in t *)
    let get_or_create_account t account_id account =
      assert_is_attached t ;
      let maps, ancestor = maps_and_ancestor t in
      match Map.find maps.locations account_id with
      (* | Some Deleted -> (
       *     (\* not in mask, maybe in parent *\)
       *     match Base.location_of_account ancestor account_id with
       *     | Some location ->
       *         if Freed.mem t location then (
       *           (\* If that's feasible reuse the same location as the parent *\)
       *           Freed.remove t location ;
       *           Ok (`Existed, location) )
       *         else allocate_new t account
       *     | None ->
       *         (\* not in parent, create new location *\) allocate_new t account ) *)
      | None -> (
          (* not in mask, maybe in parent *)
          match Base.location_of_account ancestor account_id with
          | Some location ->
              Ok (`Existed, location)
          | None ->
              (* not in parent, create new location *) allocate_new t account )
      | Some location ->
          Ok (`Existed, location)
  end

  let set_parent ?accumulated:accumulated_opt t parent =
    assert (Result.is_error t.parent) ;
    assert (Option.is_none (Async.Ivar.peek t.detached_parent_signal)) ;
    assert (Int.equal t.depth (Base.depth parent)) ;
    let is_reparenting = has_parent t in
    t.parent <- Ok parent ;
    t.fill_frontier <- Attached.max_filled t ;
    (* FIXME: Should really come from the parent, this is incorrect *)
    if not is_reparenting then t.freed <- Free_list.empty ;
    (* If [t.accumulated] isn't empty, then this mask had a parent before
       and now we just reparent it (which may only happen if both old and new parents
        have the same merkle root (and some masks in between may have been removed),
       hence no need to modify [t.accumulated]) *)
    ( match accumulated_opt with
    | Some { current; next; base; detached_next_signal }
      when Option.is_none t.accumulated ->
        t.accumulated <-
          Some
            { current = maps_merge current t.maps
            ; next = maps_merge next t.maps
            ; base
            ; detached_next_signal
            }
    | _ ->
        () ) ;
    t
end
