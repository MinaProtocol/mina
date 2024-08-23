mina automation
==============

The `mina_automation` lib is a small utility which helps to automate local app execution

Library can be used in various local test and automation. For example to test if archive and extract blocks apps gives expected archive state. Main feature of an lib is ability to detect location of apps. App can be build locally and resides in _build/default folder, or can be installed globally and put in /usr/local/bin folder.

It also has automation for docker if we would like to run docker command locally and use some output further in the test.

An example of usage:

```
  open Mina_automation

  let archive_blocks = Archive_blocks.of_context Executor.AutoDetect in

  let%bind _ =
    Archive_blocks.run archive_blocks ~blocks:extensional_files
      ~archive_uri:target_db ~format:Extensional
  
```