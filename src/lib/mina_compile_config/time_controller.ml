[%%import "/src/config/config.mlh"]

open Core_kernel

module T (F : sig
  type time

  type span

  val to_span_since_epoch : time -> span

  val of_span_since_epoch : span -> time

  val of_time_span : Time.Span.t -> span

  val of_time : Time.t -> time

  val ( + ) : span -> span -> span
end) =
struct
  [%%if time_offsets]

  type t = unit -> Time.Span.t [@@deriving sexp]

  (* NB: All instances are identical by construction (see basic below). *)
  let equal _ _ = true

  (* NB: All instances are identical by construction (see basic below). *)
  let compare _ _ = 0

  let time_offset = ref None

  let setting_enabled = ref None

  let disable_setting_offset () = setting_enabled := Some false

  let enable_setting_offset () =
    match !setting_enabled with
    | None ->
        setting_enabled := Some true
    | Some true ->
        ()
    | Some false ->
        failwith
          "Cannot enable time offset mutations; it has been explicitly disabled"

  let set_time_offset offset =
    match !setting_enabled with
    | Some true ->
        time_offset := Some offset
    | None | Some false ->
        failwith "Cannot mutate the time offset"

  let create offset = offset

  let basic ~logger:_ () =
    match !time_offset with
    | Some offset ->
        offset
    | None ->
        let offset =
          let env = "MINA_TIME_OFFSET" in
          let env_offset =
            match Sys.getenv_opt env with
            | Some tm ->
                Int.of_string tm
            | None ->
                let default = 0 in
                eprintf
                  "Environment variable %s not found, using default of %d\n%!"
                  env default ;
                default
          in
          Time.Span.of_int_sec env_offset
        in
        time_offset := Some offset ;
        offset

  let get_time_offset ~logger = basic ~logger ()

  let to_system_time offset t =
    F.(of_span_since_epoch (to_span_since_epoch t + of_time_span (offset ())))

  let now offset = F.of_time @@ Time.sub (Time.now ()) (offset ())

  [%%else]

  type t = unit [@@deriving sexp, equal, compare]

  let create () = ()

  let basic ~logger:_ = ()

  let disable_setting_offset () = ()

  let enable_setting_offset () = ()

  let set_time_offset _ = failwith "Cannot mutate the time offset"

  let get_time_offset _ = Time.Span.of_int_sec 0

  let to_system_time _ t = t

  let now _ = F.of_time @@ Time.now ()

  [%%endif]
end
