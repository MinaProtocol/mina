This tests makes sure that when we restart the build in pollling mode,
the commands that are currently running don't affect the next build.

It works as follow: we have an orchestrate process that runs dune in
watch mode with y as target. In the dune file, we have a rule to
produce y from x. The action of this rule runs a client program that:

- read the contents x
- connect to the orchestrate
- wait for the orchestrate to tell it to continue
- write y with the contents read from x
- tell the orchestrate we are done
- exit

Initially, x contains 1. When the first client connects to the
orchestrate, the orchestrate write 2 to x. The builds then restart and
a new clients is spawn. When this new client connects, the orchestrate
tells it to continue and waits for it to tell it is done.

If the first program is not dead, the orchestrate tells it to continue
and waits for it to finish.

At this point, the test has passed iff y contains 2.

  $ dune clean
  $ dune build orchestrate.exe client.exe
  $ ./_build/default/orchestrate.exe debug
