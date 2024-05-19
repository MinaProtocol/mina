open Executor
open Core
include Executor

module Config = struct
  
  type mode = Audit | Run
  
  type t = {
    archive_uri:  Uri.t
    ; precomputed_blocks: Uri.t
    ; network: string
    ; run_mode: mode
    ; missing_blocks_auditor: string option
    ; archive_blocks:string option
    }

  let to_args t = 
    match t.run_mode with 
      | Audit -> ["audit"]
      | Run -> ["single-run"]
    
  let to_envs t = 
    `Extend ([
      ("MINA_NETWORK", t.network)
      ; ("PRECOMPUTED_BLOCKS_URL", Uri.to_string t.precomputed_blocks)
      ; ("DB_USERNAME",Option.value_exn (Uri.user t.archive_uri) )
      ; ("DB_HOST",Uri.host_with_default ~default:"localhost" t.archive_uri)
      ; ("DB_PORT",Int.to_string (Option.value_exn (Uri.port t.archive_uri)) )
      ; ("DB_NAME",Uri.path t.archive_uri )
      ; ("PGPASSWORD",Option.value_exn (Uri.password t.archive_uri) )
    ] @
    
     ( Option.map t.missing_blocks_auditor ~f:(fun x ->
        ["MINA_MISSING_BLOCKS_AUDITOR_APP",x]
       ) |> Option.value ~default:[]
    
     )
    @

    (
      Option.map t.archive_blocks ~f:(fun x ->
        ["MINA_ARCHIVE_BLOCKS_APP",x]
       ) |> Option.value ~default:[]
       
    )
    )
end


let of_context context =
  Executor.of_context ~context
    ~dune_name:"scripts/archive/missing-blocks-guardian.sh"
    ~official_name:"/etc/mina/scripts/missing-blocks-guardian.sh"

let run t ~config =
  run t ~args:(Config.to_args config) ~env:(Config.to_envs config)

  