# Spacetime profiling

Spacetime is a feature for showing memory usage over time within OCaml programs. It's useful
for revealing the location of memory leaks.

## Building for Spacetime

To use Spacetime, you need an OCaml compiler built with that feature enabled. There are
Spacetime-enabled compiler switches within OPAM. For example, there's the switch 
4.07.1+spacetime, which works with same OPAM packages as vanilla 4.07.1. To build
with it in your enviroment, install the switch:

```
  opam switch create 4.07.1+spacetime # or the current OCaml version for building Coda 
  eval $(opam env)
```
Building some OPAM packages with Spacetime requires a large amount of stack space, so you
may need to increase the available stack provided by your shell. For bash:
```
  ulimit -s unlimited
```
Then follow the instructions for "Building outside docker" given in README-dev.md. 

## Running for Spacetime

Once the Coda executable has been built for Spacetime, you can run it as you would otherwise.
To obtain Spacetime profiling data, set the environment variable `OCAML_SPACETIME_INTERVAL`
to the sampling interval, in milliseconds. In practice, we've found that 10 seconds works well:

```
  export OCAML_SPACETIME_INTERVAL=10000
```

With that setting running a Coda daemon for an hour generates perhaps 500 Mb of profile data.
When done profiling, terminate the daemon with Ctrl-C, to make sure the profile data is fully
written.

You can specify a directory where the profiling data is written, using the environment
variable `OCAML_SPACETIME_SNAPSHOT_DIR`.

## Viewing Spacetime profiles

Spacetime generates a profile file for each process that you run, with the name `spacetime-<pid>`. 
To view the data, install the OPAM package `prof_spacetime`:

```
  opam install prof_spacetime
```

You can view the profile data in a terminal, but it's probably more useful to view the profile
as interactive graphs via Web browser. To speed up viewing, you should preprocess the 
profile file:

```
  prof_spacetime process spacetime-<pid>
```

That generates a file `spacetime-<pid>.p`. Now start a Web server:

```
  prof_spacetime serve -p spacetime-<pid>.p
```

That starts a Web server on `127.0.0.1` with port 8080. You can use the flags `--address` and
`--port` to change those options.

It may take several seconds for the graph to be visible. You can see three different graphs, 
live bytes, live words, and all allocated words. All of them show different allocation points
with different colors, and the amount of allocation over time.

The following blog article describes how to use the graphs in more detail, and also describes
viewing the profiles in a terminal:

* [A Brief Trip Through Spacetime](https://blog.janestreet.com/a-brief-trip-through-spacetime/)
