open Cmdliner;
%raw
"process.argv.shift()";

/**
 * Keypair commands.
 */

let keypair = action => {
  Keypair.(
    switch (action) {
    | Some("create") =>
      let keypair = create(~nickname=None);
      Js.log(keypair.publicKey);
      write(keypair);
    | Some(message) =>
      Js.log2("Unsupported action:", message);
      Js.log("See --help");
    | _ => Js.log("Please provide an ACTION. See --help.")
    }
  );
};

let keypairTerm = {
  let doc = "Create, upload and download keypairs.";
  let sdocs = Manpage.s_common_options;
  let action =
    Arg.(value(pos(0, some(string), None, info([], ~docv="ACTION"))));
  (Term.(const(keypair) $ action), Term.info("keypair", ~doc, ~sdocs));
};

/**
 * Keyset commands.
 */

let rec populateKeyset: (Keyset.t, int) => Keyset.t =
  (keyset, count) =>
    count > 0
      ? {
        let keypair =
          Keypair.create(
            ~nickname=Some(keyset.name ++ string_of_int(count)),
          );
        Keypair.write(keypair);
        populateKeyset(Keyset.appendKeypair(keyset, keypair), count - 1);
      }
      : keyset;

let keyset = (action, keysetName, publicKey, count) => {
  open Keyset;
  switch (action, keysetName) {
  | (Some("create"), Some(name)) =>
    let keyset = create(name);
    write(keyset);
    Js.log("Created keyset: " ++ name);
    switch (count) {
    | Some(num) =>
      Js.log3("Generating", num, "new keys");
      populateKeyset(keyset, num) |> write;
      Js.log("Successfully generated new keys");
    | None => ()
    };
  | (Some("create"), None)
  | (Some("show"), None)
  | (Some("add"), None) =>
    Js.log("Please provide a keyset name with -n/--name")
  | (Some("add"), Some(name)) =>
    switch (load(name), publicKey) {
    | (Some(keyset), Some(publicKey)) =>
      append(keyset, ~publicKey, ~nickname=None)->write;
      ();
    | (None, _) => Js.log("The provided keyset does not exist.")
    | (Some(_), None) =>
      Js.log("Please provide a publicKey with -k/--publickey")
    }
  | (Some("show"), Some(name)) =>
    switch (load(name)) {
    | Some(keyset) =>
      Js.log(keyset.entries);
      ();
    | None => Js.log("The provided keyset does not exist.")
    }
  | (Some("ls"), _)
  | (Some("list"), _) =>
    list()
    |> Js.Promise.then_(files => {
         Js.log(files);
         Js.Promise.resolve();
       })
    |> ignore
  | (Some("upload"), Some(name)) =>
    let keyset = load(name);
    switch (keyset) {
    | Some(keyset) => upload(keyset) |> ignore
    | None => Js.log("The provided keyset does not exist.")
    };
  | (_, _) => Js.log("Unsupported ACTION.")
  };
  ();
};

let keysetTerm = {
  let doc = "Generate and manage shared keysets.";
  let sdocs = Manpage.s_common_options;
  let action =
    Arg.(value(pos(0, some(string), None, info([], ~docv="ACTION"))));
  let keysetName =
    Arg.(
      value(opt(some(string), None, info(["n", "name"], ~docv="NAME")))
    );
  let count =
    Arg.(
      value(opt(some(int), None, info(["c", "count"], ~docv="COUNT")))
    );
  let publicKey =
    Arg.(
      value(
        opt(
          some(string),
          None,
          info(["k", "publicKey"], ~docv="PUBLICKEY"),
        ),
      )
    );
  (
    Term.(const(keyset) $ action $ keysetName $ publicKey $ count),
    Term.info("keyset", ~doc, ~sdocs),
  );
};

/**
 * Keyset commands.
 */

let genesis = () => {
  Genesis.(
    prompt([||])
    |> Js.Promise.then_(config => {
         let ledger = create(config);
         write(ledger);
         Js.log2("\nCreated genesis ledger version", version(ledger));
         Js.Promise.resolve();
       })
    |> ignore
  );
};

let genesisTerm = {
  let doc = "Generate and manage shared keysets.";
  let sdocs = Manpage.s_common_options;
  (Term.(const(genesis) $ const()), Term.info("genesis", ~doc, ~sdocs));
};

/**
 * Default command.
 */

let defaultCommand = {
  let doc = "simple utility for spinning up coda testnets";
  let sdocs = Manpage.s_common_options;
  (
    Term.(ret(const(_ => `Help((`Pager, None))) $ const())),
    Term.info("coda-network", ~version="0.1.0-alpha", ~doc, ~sdocs),
  );
};

let commands = [keypairTerm, keysetTerm, genesisTerm];

// Don't exit until all callbacks/Promises resolve.
let safeExit = result => {
  switch (result) {
  | `Ok(_) => ()
  | res => Term.exit(res)
  };
};

let _ = safeExit @@ Term.eval_choice(defaultCommand, commands);
