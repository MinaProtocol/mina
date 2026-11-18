(* config.ml -- the settings of the guardian. Each one comes from its flag,
   else from its environment variable, else from a default. Every problem is
   reported, not only the first. *)

open Core

module Block_format = struct
  type t = Precomputed | Extensional [@@deriving equal]

  let to_string = function
    | Precomputed ->
        "precomputed"
    | Extensional ->
        "extensional"

  let of_string = function
    | "precomputed" ->
        Ok Precomputed
    | "extensional" ->
        Ok Extensional
    | _ ->
        Error "expected precomputed or extensional"
end

module Default = struct
  let auditor = "mina-missing-blocks-auditor"

  let format = Block_format.Precomputed

  let interval = 600

  (* After a recovery, the daemon waits this many intervals. *)
  let recovery_sleep_factor = 6
end

(* The archive database and the program that audits it. *)
type archive = { uri : Uri.t; auditor : string }

(* Where the missing blocks come from. *)
type blocks = { url : string; network : string; format : Block_format.t }

(* A lookup of the environment. A variable set to the empty string counts as
   unset. *)
type env = string -> string option

let process_env : env =
 fun name ->
  match Sys.getenv name with
  | Some value when not (String.is_empty value) ->
      Some value
  | _ ->
      None

(* The URI with its password replaced, safe to log. *)
let redact uri =
  match Uri.password uri with
  | None ->
      Uri.to_string uri
  | Some _ ->
      (* [Uri] percent-encodes the password, so the placeholder goes in after
         printing. *)
      let placeholder = "REDACTEDPASSWORD" in
      String.substr_replace_first
        (Uri.to_string (Uri.with_password uri (Some placeholder)))
        ~pattern:placeholder ~with_:"<hidden>"

(* A setting, or the problems with it. *)
type 'a result = ('a, string list) Result.t

let errors results =
  List.concat_map results ~f:(function Ok _ -> [] | Error problems -> problems)

(* Both settings, or the problems with either. *)
let both a b =
  match (a, b) with
  | Ok a, Ok b ->
      Ok (a, b)
  | _ ->
      Error (errors [ Result.map a ~f:ignore; Result.map b ~f:ignore ])

(* The value of [flag], else of the environment variable [var], else
   [default]. *)
let setting ~(env : env) ~flag ~var ?default ~parse value : _ result =
  let parsed ~shown text =
    match parse text with
    | Ok value ->
        Ok value
    | Error reason ->
        Error [ sprintf "%s: %s" shown reason ]
  in
  match (value, env var, default) with
  | Some text, _, _ ->
      parsed ~shown:(flag ^ " " ^ text) text
  | None, Some text, _ ->
      parsed ~shown:(var ^ "=" ^ text) text
  | None, None, Some default ->
      Ok default
  | None, None, None ->
      Error
        [ sprintf "missing %s: pass the flag or set the environment variable %s"
            flag var
        ]

let positive_int text =
  match Option.try_with (fun () -> Int.of_string text) with
  | Some n when n > 0 ->
      Ok n
  | _ ->
      Error "expected a positive integer"

let port text =
  match Option.try_with (fun () -> Int.of_string text) with
  | Some n when n >= 1 && n <= 65535 ->
      Ok n
  | _ ->
      Error "expected a port number from 1 to 65535"

let program text =
  if String.is_empty (String.strip text) then
    Error "expected the name or path of a program"
  else Ok text

(* The network name is the prefix of the block file names. *)
let network_name text =
  if
    String.is_empty text
    || String.exists text ~f:(fun c -> Char.is_whitespace c || Char.equal c '/')
  then Error "expected a name without spaces or slashes"
  else Ok text

(* The bucket URL, without a trailing slash. *)
let blocks_url text =
  let uri = Uri.of_string text in
  let without_slash = String.rstrip text ~drop:(Char.equal '/') in
  let has_host =
    Option.exists (Uri.host uri) ~f:(fun host -> not (String.is_empty host))
  in
  match Uri.scheme uri with
  | Some ("http" | "https") when has_host ->
      Ok without_slash
  | Some ("http" | "https") ->
      Error "expected a host in the URL"
  | Some "file" when not (String.is_empty (Uri.path uri)) ->
      Ok without_slash
  | Some "file" ->
      Error "expected a path in the URL"
  | Some "gs" ->
      Error
        "expected an http, https or file URL; for a Google Cloud Storage \
         bucket use https://storage.googleapis.com/<bucket>"
  | Some "s3" ->
      Error
        "expected an http, https or file URL; for an S3 bucket use \
         https://<bucket>.s3.<region>.amazonaws.com"
  | _ ->
      Error "expected an http, https or file URL"

let archive_uri_of_string text =
  let uri = Uri.of_string text in
  match Uri.scheme uri with
  | Some ("postgres" | "postgresql") ->
      Ok uri
  | _ ->
      Error "expected a postgres:// URI"

let archive_uri_vars =
  [ "DB_USERNAME"; "PGPASSWORD"; "DB_HOST"; "DB_PORT"; "DB_NAME" ]

(* The archive URI, from --archive-uri or built from DB_USERNAME, PGPASSWORD,
   DB_HOST, DB_PORT and DB_NAME. *)
let archive_uri ~(env : env) value : Uri.t result =
  match value with
  | Some text -> (
      match archive_uri_of_string text with
      | Ok uri ->
          Ok uri
      | Error reason ->
          Error
            [ sprintf "--archive-uri %s: %s"
                (redact (Uri.of_string text))
                reason
            ] )
  | None -> (
      let values =
        List.map archive_uri_vars ~f:(fun name -> (name, env name))
      in
      match List.map values ~f:snd with
      | [ Some user; Some password; Some host; Some port_text; Some database ]
        -> (
          match port port_text with
          | Ok port ->
              Ok
                (Uri.make ~scheme:"postgres"
                   ~userinfo:(user ^ ":" ^ password)
                   ~host ~port ~path:("/" ^ database) () )
          | Error reason ->
              Error [ sprintf "DB_PORT=%s: %s" port_text reason ] )
      | _ ->
          let unset =
            List.filter_map values ~f:(fun (name, value) ->
                Option.some_if (Option.is_none value) name )
          in
          let not_set =
            if List.length unset = List.length archive_uri_vars then ""
            else sprintf " (not set: %s)" (String.concat ~sep:", " unset)
          in
          Error
            [ sprintf
                "missing --archive-uri: pass the flag or set the environment \
                 variables %s%s"
                (String.concat ~sep:", " archive_uri_vars)
                not_set
            ] )

let archive ~env ~uri ~auditor : archive result =
  let uri = archive_uri ~env uri in
  let auditor =
    setting ~env ~flag:"--missing-blocks-auditor" ~var:"MISSING_BLOCKS_AUDITOR"
      ~default:Default.auditor ~parse:program auditor
  in
  match both uri auditor with
  | Ok (uri, auditor) ->
      Ok { uri; auditor }
  | Error problems ->
      Error problems

let blocks ~env ~url ~network ~format : blocks result =
  let url =
    setting ~env ~flag:"--precomputed-blocks-url" ~var:"PRECOMPUTED_BLOCKS_URL"
      ~parse:blocks_url url
  in
  let network =
    setting ~env ~flag:"--network" ~var:"MINA_NETWORK" ~parse:network_name
      network
  in
  let format =
    setting ~env ~flag:"--block-format" ~var:"BLOCKS_FORMAT"
      ~default:Default.format ~parse:Block_format.of_string format
  in
  match both (both url network) format with
  | Ok ((url, network), format) ->
      Ok { url; network; format }
  | Error problems ->
      Error problems

let interval ~env value : int result =
  setting ~env ~flag:"--interval" ~var:"TIMEOUT" ~default:Default.interval
    ~parse:positive_int value
