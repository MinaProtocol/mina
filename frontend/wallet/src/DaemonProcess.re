open Bindings;

let process: ref(option(ChildProcess.Process.t)) = ref(None);

let start = port => {
  print_endline("Starting graphql-faker");
  let p =
    ChildProcess.spawn(
      "./node_modules/.bin/graphql-faker",
      [|"--port", string_of_int(port), "--", "schema.graphql"|],
    );
  process := Some(p);
  ChildProcess.Process.onError(
    p,
    e => {
      prerr_endline(
        "Daemon process crashed. : " ++ ChildProcess.Error.messageGet(e),
      );
      process := None;
    },
  );
  ChildProcess.Process.onExit(
    p,
    (n, s) => {
      if (n == 1) {
        Printf.fprintf(
          stderr,
          "Daemon process exited with non-zero exit code: Exit:%d, msg:%s%!\n",
          n,
          Tc.Option.withDefault(s, ~default="Port 8080 already in use?"),
        );
      } else {
        print_endline("Shutting down daemon process.");
      };
      process := None;
    },
  );
};

let kill = () => {
  switch (process^) {
  | Some(p) => ChildProcess.Process.kill(p)
  | None => ()
  };
};
