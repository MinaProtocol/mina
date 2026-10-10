(* cli.ml -- the command line flags. Each overrides an environment variable;
   see {!Missing_blocks_guardian_lib.Env}. *)

open Core
open Missing_blocks_guardian_lib

let options : Config.options Command.Param.t =
  let%map_open.Command archive_uri =
    flag "--archive-uri" (optional string)
      ~doc:
        "URI Archive database to check and repair, for example \
         postgres://user:password@localhost:5432/archive. Overrides PG_CONN \
         and the DB_* variables."
  and precomputed_blocks_url =
    flag "--precomputed-blocks-url" (optional string)
      ~doc:
        "URL Location of the block files, as an http, https or file URL, or a \
         local directory. Overrides PRECOMPUTED_BLOCKS_URL."
  and network =
    flag "--network" (optional string)
      ~doc:
        "NAME Network name used as the block file name prefix. Overrides \
         MINA_NETWORK."
  and block_format =
    flag "--block-format" (optional string)
      ~doc:
        "precomputed|extensional Format of the block files. Overrides \
         BLOCKS_FORMAT. Default: precomputed."
  and interval =
    flag "--interval" (optional float)
      ~doc:
        "SECONDS Time to wait between checks in daemon mode. Overrides \
         TIMEOUT. Default: 600."
  and idle_multiplier =
    flag "--idle-multiplier" (optional int)
      ~doc:
        "N In daemon mode, wait N times --interval after a repair adds blocks. \
         Default: 6."
  and http_timeout =
    flag "--http-timeout" (optional float)
      ~doc:"SECONDS Time allowed for one block download. Default: 60."
  and retries =
    flag "--retries" (optional int)
      ~doc:
        "N Extra attempts for a download that fails for a transient reason. A \
         missing or malformed block is never retried. Default: 3."
  and retry_delay =
    flag "--retry-delay" (optional float)
      ~doc:"SECONDS Time to wait between download attempts. Default: 5."
  and max_blocks =
    flag "--max-blocks" (optional int)
      ~doc:"N Stop after adding N blocks in one repair pass. Default: no limit."
  and min_height =
    flag "--min-height" (optional int)
      ~doc:
        "HEIGHT Refuse to fetch a block below this height. Use it on a forked \
         network whose archive does not hold the fork block, to stop the walk \
         at the fork point instead of running down to height 1."
  and max_consecutive_failures =
    flag "--max-consecutive-failures" (optional int)
      ~doc:
        "N Exit in daemon mode after N repair passes fail in a row. 0 means \
         never exit. Default: 5."
  and dry_run =
    flag "--dry-run" no_arg
      ~doc:
        " Report what would be downloaded and check that it can be downloaded \
         and decoded, without writing anything to the database."
  in
  { Config.archive_uri
  ; precomputed_blocks_url
  ; network
  ; block_format
  ; interval
  ; idle_multiplier
  ; http_timeout
  ; retries
  ; retry_delay
  ; max_blocks
  ; min_height
  ; max_consecutive_failures
  ; dry_run
  }
