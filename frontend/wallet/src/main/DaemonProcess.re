open Bindings;

let start = port => {
  print_endline("Starting graphql-faker");
  let p =
    ChildProcess.spawn(
      "node",
      [|
        Filename.concat(
          ProjectRoot.resource,
          "node_modules/graphql-faker/dist/index.js",
        ),
        "--port",
        string_of_int(port),
        "--",
        "schema.graphql",
      |],
    );

  ChildProcess.Process.onError(p, e =>
    prerr_endline(
      "Daemon process crashed: " ++ ChildProcess.Error.messageGet(e),
    )
  );

  ChildProcess.Process.onExit(p, (n, s) =>
    if (n == 1) {
      Printf.fprintf(
        stderr,
        "Daemon process exited with non-zero exit code: Exit:%d, msg:%s%!\n",
        n,
        Tc.Option.withDefault(s, ~default="Port 8080 already in use?"),
      );
    } else {
      print_endline("Shutting down daemon process.");
    }
  );

  () => ChildProcess.Process.kill(p);
};
