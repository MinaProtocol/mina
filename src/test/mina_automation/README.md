mina automation
==============

The `mina_automation` lib is a small utility which helps to automate local app execution

Library can be used in various local test and automation. For example to test if archive and extract blocks apps gives expected archive state. Main feature of an lib is ability to detect location of apps. App can be build locally and resides in _build/default folder, or can be installed globally and put in /usr/local/bin folder.

It also has automation for docker if we would like to run docker command locally and use some output further in the test.

Below list of all modules with short introduction

### archive blocks

Responsible for archiving extensional or precomputed blocks into archive database

Example of usage:

```
  open Mina_automation

  let archive_blocks = Archive_blocks.of_context Executor.AutoDetect in

  let%bind _ =
    Archive_blocks.run archive_blocks ~blocks:extensional_files
      ~archive_uri:target_db ~format:Extensional

```

where: 

- `extensional_files : String.t list` - list of paths to files
- `target_db: String.t` - db connection string (e.g: postgres://postgres:postgres@localhost:5432/archive)

### archive dumps

Usability module for downloading dumps from official o1labs dump bucket

Example of usage:

```
  open Mina_automation

  Archive_dumps.download_via_public_url ~prefix:"mainnet" ~date:"05-04-2034" ~target:"."
```

where:

- prefix : String.t - dump prefix usually corresponds to network name 
- date : String.t - date suffix of dump
- target: String.t - path to local dump destination

### docker

Usability module for running any application published as a docker.

Example of usage:

```
  open Mina_automation

  let client = Docker.Client.default in
  let logs = Docker.Client.run_cmd_in_image t ~image:"gcr.io....-mina-archive-blocks" ~cmd:"mina-archive blocks ..." ~workdir:"/workdir" ~volume:"/home/darek/work/mina:/workdir" ~network:"localhost" 

```

where :
 - `image : String.t` - docker image in which command will be run. If does not exist locally it will be pulled
 - `cmd: String.t` - command which will be run in docker
 - `workdir: String.t` - working directory off command
 - `volume: String.t` - volume mapping between docker and localhost
 - `network: String.t` - network which docker will be attached to when executing command. In our example we are using `localhost` which allows to connect to db from within docker
  

### extract blocks

Extract blocks apps dumps blocks stored in database in form of Extensional blocks.

Example of usage:

```
 open Mina_automation

  let extract_blocks = Extract_blocks.of_context Executor.AutoDetect in
  let config =
    { Extract_blocks.Config.archive_uri = source_db
    ; range = Extract_blocks.Config.AllBlocks
    ; output_folder = Some output_folder
    ; network = Some network_name
    ; include_block_height_in_name = true
    }
  in
  let%bind _ = Extract_blocks.run extract_blocks ~config in

```
  
### missing block auditor

Missing block auditor is an shell script which detect any gaps in database that can be fixed with missing block guardian. Currently it is used as a sub component for missing_blocks_guardian app so there is no features rather than path to app detection


### missing block guardian

Missing block guardian fills gaps of archive database

Example of usage:

```
  let%bind missing_blocks_auditor_path =
    Missing_blocks_auditor.of_context Executor.AutoDetect
    |> Missing_blocks_auditor.path in

  let%bind archive_blocks_path = 
    Archive_blocks.of_context Executor.AutoDetect |> path archive_blocks in

  let config =
    { Missing_blocks_guardian.Config.archive_uri = Uri.of_string target_db
    ; precomputed_blocks = Uri.make ~scheme:"file" ~path:output_folder ()
    ; network = network_name
    ; run_mode = Run
    ; missing_blocks_auditor = missing_blocks_auditor_path
    ; archive_blocks = archive_blocks_path
    ; block_format = Extensional
    } in

  let missing_blocks_guardian =
    Missing_blocks_guardian.of_context Executor.AutoDetect
  in

  let%bind _ = Missing_blocks_guardian.run missing_blocks_guardian ~config
```

where: 

- target_db : String.t - connection string to database

### replayer

Replayer checks integrity of database against ledger.

Example of usage:

```
  let replayer = Replayer.of_context Executor.AutoDetect in

  let%bind _ =
    Replayer.run replayer ~archive_uri:target_db
      ~input_config:
        (network_data.folder ^ "/" ^ network_data.replayer_input_file)
      ~interval_checkpoint:10 ~output_ledger:"./output_ledger" ()
  in

```

where:

- input_config: String.t - path to replayer input config
- interval_checkpoint: String.t - how frequent replayer should dump checkpoint (per slots)
- output_ledger: String.t - path to output ledger folder