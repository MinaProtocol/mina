open Core_kernel
open Mina_base

module Key = struct
  type t = Time.Stable.With_utc_sexp.V2.t * State_hash.t [@@deriving sexp]

  let compare (at, ah) (bt, bh) =
    let c1 = Time.compare at bt in
    if c1 = 0 then State_hash.compare ah bh else c1
end

module TimeoutSet = Set.Make (Key)

type t = { mutable events : TimeoutSet.t }

let process_events (type state_t)
    ~state_functions:
      (module F : Substate.State_functions with type state_t = state_t)
    ~transition_states t =
  let rec impl () =
    let now_ = Time.now () in
    let to_process =
      TimeoutSet.fold_until t.events ~init:TimeoutSet.empty ~finish:Fn.id
        ~f:(fun to_p (t, h) ->
          if Time.(now_ > t) then
            Container.Continue_or_stop.Continue (TimeoutSet.add to_p (t, h))
          else Container.Continue_or_stop.Stop to_p )
    in
    let old_min_t = TimeoutSet.min_elt t.events in
    t.events <- TimeoutSet.diff t.events to_process ;
    let modifier target_timeout =
      { Substate.modifier =
          (fun subst ->
            match subst.status with
            | Processing (In_progress { interrupt_ivar; timeout })
              when Time.(timeout = target_timeout) ->
                Async_kernel.Ivar.fill_if_empty interrupt_ivar () ;
                ( { subst with status = Failed (Error.of_string "timed out") }
                , () )
            | _ ->
                (subst, ()) )
      }
    in
    TimeoutSet.iter to_process ~f:(fun (target_t, state_hash) ->
        State_hash.Table.change transition_states state_hash ~f:(fun st_opt ->
            let%bind.Option st = st_opt in
            let%map.Option st', () =
              F.modify_substate ~f:(modifier target_t) st
            in
            st' ) ) ;
    Option.iter (TimeoutSet.min_elt t.events) ~f:(fun (new_t, _) ->
        if
          Option.value_map old_min_t ~default:true ~f:(fun (prev_t, _) ->
              Time.(prev_t > new_t) )
        then Async_kernel.upon (Async.at new_t) impl )
  in
  impl ()

let register ~state_functions ~transition_states ~state_hash ~timeout t =
  let old_min_t = TimeoutSet.min_elt t.events in
  t.events <- TimeoutSet.add t.events (timeout, state_hash) ;
  if
    Option.value_map ~default:true
      ~f:Time.(fun (old_t, _) -> old_t > timeout)
      old_min_t
  then
    Async_kernel.upon (Async.at timeout) (fun () ->
        process_events ~state_functions ~transition_states t )

let unregister ~state_hash ~timeout t =
  t.events <- TimeoutSet.remove t.events (timeout, state_hash)

(** [unregister_processing_ctx] unregsiters a transition when timeout_controller argument is provided and processing ctx is In_progress.
  Does nothing otherwise    
  *)
let cancel_in_progress_ctx ~timeout_controller ~state_hash = function
  | Substate.In_progress { timeout; interrupt_ivar } ->
      unregister ~state_hash ~timeout timeout_controller ;
      Async_kernel.Ivar.fill_if_empty interrupt_ivar ()
  | _ ->
      ()

let create () = { events = TimeoutSet.empty }

let cancel_all (type state_t)
    ~state_functions:
      (module F : Substate.State_functions with type state_t = state_t)
    ~transition_states t =
  let events = t.events in
  t.events <- TimeoutSet.empty ;
  TimeoutSet.iter events ~f:(fun (_, h) ->
      Option.value ~default:()
      @@ let%bind.Option st = State_hash.Table.find transition_states h in
         Substate.view st ~modify_substate:F.modify_substate
           ~f:
             { viewer =
                 (fun subst ->
                   match subst.status with
                   | Processing (In_progress { interrupt_ivar; _ }) ->
                       Async_kernel.Ivar.fill_if_empty interrupt_ivar ()
                   | _ ->
                       () )
             } )
