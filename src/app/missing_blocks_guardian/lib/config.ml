(* config.ml -- the guardian's settings. Each comes from an explicit option,
   else its environment variable ({!Env}), else a default. *)

open Core

(** Values given explicitly, as on the command line. Each overrides its
    environment variable. *)
type options =
  { archive_uri : string option
  ; precomputed_blocks_url : string option
  ; network : string option
  ; block_format : string option
  ; interval : float option
  ; idle_multiplier : int option
  ; http_timeout : float option
  ; retries : int option
  ; retry_delay : float option
  ; max_blocks : int option
  ; min_height : int option
  ; max_consecutive_failures : int option
  ; dry_run : bool
  }

type t =
  { archive_uri : Uri.t
  ; blocks : Block_source.t option  (** [None] for [audit], which reads none *)
  ; format : Archive_lib.Block_json.format
  ; interval : Time_ns.Span.t
  ; idle_multiplier : int
  ; http_timeout : Time_ns.Span.t
  ; retries : int
  ; retry_delay : Time_ns.Span.t
  ; max_blocks : int option
  ; min_height : int option
  ; max_consecutive_failures : int
  ; dry_run : bool
  }

let default_interval_seconds = 600.

let default_idle_multiplier = 6

let default_http_timeout_seconds = 60.

let default_retries = 3

let default_retry_delay_seconds = 5.

let default_max_consecutive_failures = 5

let positive_span name seconds =
  if Float.( > ) seconds 0. then Ok (Time_ns.Span.of_sec seconds)
  else Or_error.errorf "%s must be greater than zero, but it is %f" name seconds

let at_least minimum name value =
  if Int.( >= ) value minimum then Ok value
  else Or_error.errorf "%s must be at least %d, but it is %d" name minimum value

let optional_at_least minimum name = function
  | None ->
      Ok None
  | Some value ->
      Or_error.map (at_least minimum name value) ~f:Option.some

let block_format (o : options) =
  match Option.first_some o.block_format (Env.get Env.blocks_format) with
  | None ->
      Ok Archive_lib.Block_json.Precomputed
  | Some name ->
      Archive_lib.Block_json.format_of_string name

let required ~name = function
  | Some value ->
      Ok value
  | None ->
      Or_error.errorf "%s is required to fetch blocks" name

(** A block file is named <network>-<height>-<state hash>.json under the
    source URL, so fetching needs both. *)
let block_source ~requires_blocks (o : options) =
  if not requires_blocks then Ok None
  else
    let open Or_error.Let_syntax in
    let%bind url, network =
      Or_error.both
        (required ~name:"--precomputed-blocks-url (PRECOMPUTED_BLOCKS_URL)"
           (Option.first_some o.precomputed_blocks_url
              (Env.get Env.precomputed_blocks_url) ) )
        (required ~name:"--network (MINA_NETWORK)"
           (Option.first_some o.network (Env.get Env.network)) )
    in
    Or_error.map (Block_source.create ~network url) ~f:Option.some

let interval (o : options) =
  let open Or_error.Let_syntax in
  let%bind seconds =
    match o.interval with
    | Some seconds ->
        Ok seconds
    | None ->
        Env.float Env.timeout >>| Option.value ~default:default_interval_seconds
  in
  positive_span "--interval (TIMEOUT)" seconds

let resolve ~requires_blocks (o : options) =
  let open Or_error.Let_syntax in
  let%bind archive_uri = Archive_uri.resolve ~flag:o.archive_uri ~env:Env.get in
  let%bind blocks = block_source ~requires_blocks o in
  let%bind format = block_format o in
  let%bind interval = interval o in
  let%bind http_timeout =
    positive_span "--http-timeout"
      (Option.value o.http_timeout ~default:default_http_timeout_seconds)
  in
  let%bind retry_delay =
    positive_span "--retry-delay"
      (Option.value o.retry_delay ~default:default_retry_delay_seconds)
  in
  let%bind retries =
    at_least 0 "--retries" (Option.value o.retries ~default:default_retries)
  in
  let%bind idle_multiplier =
    at_least 1 "--idle-multiplier"
      (Option.value o.idle_multiplier ~default:default_idle_multiplier)
  in
  let%bind max_consecutive_failures =
    at_least 0 "--max-consecutive-failures"
      (Option.value o.max_consecutive_failures
         ~default:default_max_consecutive_failures )
  in
  let%bind max_blocks = optional_at_least 1 "--max-blocks" o.max_blocks in
  let%map min_height = optional_at_least 1 "--min-height" o.min_height in
  { archive_uri
  ; blocks
  ; format
  ; interval
  ; idle_multiplier
  ; http_timeout
  ; retries
  ; retry_delay
  ; max_blocks
  ; min_height
  ; max_consecutive_failures
  ; dry_run = o.dry_run
  }

let%test_module "config" =
  ( module struct
    let no_options =
      { archive_uri = None
      ; precomputed_blocks_url = None
      ; network = None
      ; block_format = None
      ; interval = None
      ; idle_multiplier = None
      ; http_timeout = None
      ; retries = None
      ; retry_delay = None
      ; max_blocks = None
      ; min_height = None
      ; max_consecutive_failures = None
      ; dry_run = false
      }

    let%test "a flag archive URI is used as given" =
      match
        resolve ~requires_blocks:false
          { no_options with archive_uri = Some "postgres://u:p@h:5432/archive" }
      with
      | Ok t ->
          String.equal
            (Uri.to_string t.archive_uri)
            "postgres://u:p@h:5432/archive"
      | Error _ ->
          false

    let%test "an unset archive database is reported, not guessed" =
      match resolve ~requires_blocks:false no_options with
      | Error err ->
          String.is_substring (Error.to_string_hum err) ~substring:"PG_CONN"
      | Ok _ ->
          false

    let%test "fetching blocks needs both a URL and a network" =
      match
        resolve ~requires_blocks:true
          { no_options with
            archive_uri = Some "postgres://u:p@h:5432/archive"
          ; precomputed_blocks_url = Some "https://example.com/blocks"
          }
      with
      | Error err ->
          String.is_substring (Error.to_string_hum err) ~substring:"--network"
      | Ok _ ->
          false

    let%test "a bad --min-height is rejected" =
      Or_error.is_error
        (resolve ~requires_blocks:false
           { no_options with
             archive_uri = Some "postgres://u:p@h:5432/archive"
           ; min_height = Some 0
           } )

    let%test "a bad --interval is rejected" =
      Or_error.is_error
        (resolve ~requires_blocks:false
           { no_options with
             archive_uri = Some "postgres://u:p@h:5432/archive"
           ; interval = Some 0.
           } )

    let%test "an unknown block format is rejected" =
      Or_error.is_error
        (resolve ~requires_blocks:false
           { no_options with
             archive_uri = Some "postgres://u:p@h:5432/archive"
           ; block_format = Some "extensionall"
           } )
  end )
