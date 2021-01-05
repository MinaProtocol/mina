type entry = {
  pk: string,
  sk: option(string),
  balance: string,
  delegate: option(string),
};

type t = array(entry);
type config = (Keyset.t, int, option(Keyset.t));

/**
 * Generates a genesis ledger from the given configuration
 */
let create = config => {
  // Reduce the config into a genesis ledger array
  Array.fold_right(
    (
      (keyset, balance, delegateKeyset): (Keyset.t, int, option(Keyset.t)),
      acc,
    ) => {
      // Sanity check that delegate keyset has the same number of keys
      switch (delegateKeyset) {
      | Some(delegateKeyset) =>
        if (Array.length(keyset.entries)
            !== Array.length(delegateKeyset.entries)) {
          raise(
            Invalid_argument(
              "Delegate keyset doesn't have the same number of keys",
            ),
          );
        }
      | None => ()
      };

      Array.mapi(
        (index, keysetEntry) => {
          let entry: Keyset.entry = keysetEntry;
          {
            pk: entry.publicKey,
            sk: None,
            balance: string_of_int(balance),
            delegate:
              Belt.Option.map(delegateKeyset, dks =>
                dks.entries[index].publicKey
              ),
          };
        },
        keyset.entries,
      )
      |> Array.append(acc);
    },
    config,
    [||],
  );
};

let version = ledger => string_of_int(Hashtbl.hash(ledger));

/**
 * Writes a genesis ledger to disk.
 */
let write = ledger => {
  let content = Js.Json.stringifyAny(ledger)->Belt.Option.getExn;
  Cache.write(Cache.Genesis, ~filename=version(ledger), content);
};

/**
 * Prompts the user for specific inputs needed for a ledger entry.
 * Returns a promise that resolves to a ledger entry.
 */
let promptEntry = () => {
  Js.Promise.(
    Prompt.question("Name: ")
    |> then_(result =>
         switch (Keyset.load(result)) {
         | Some(keyset) =>
           all2((Prompt.question("Keyset balance: "), resolve(keyset)))
         | None => reject(Prompt.Invalid_input)
         }
       )
    |> then_(((balance, keyset)) =>
         switch (int_of_string_opt(balance)) {
         | Some(bal) =>
           all2((
             resolve((keyset, bal)),
             Prompt.question("Delegate keyset: "),
           ))
         | None => reject(Prompt.Invalid_input)
         }
       )
    |> then_((((keyset, balance), delegate)) =>
         switch (Js.String.trim(delegate)) {
         | "" => resolve((keyset, balance, None))
         | delegate =>
           switch (Keyset.load(delegate)) {
           | Some(delegateKeyset) =>
             resolve((keyset, balance, Some(delegateKeyset)))
           | None =>
             Js.log("Invalid delegate " ++ delegate);
             reject(Prompt.Invalid_input);
           }
         }
       )
  );
};

/**
 * Recursively builds up an array of ledger entries by calling promptEntry.
 * Returns a promise that resolves with the ledger config to be passed to create.
 */
let rec prompt = config => {
  open Js.Promise;
  let count = Array.length(config);
  let title = "\nKeyset #" ++ string_of_int(count + 1);
  Js.log(title);
  Js.log(String.make(String.length(title) - 1, '='));
  promptEntry()
  |> then_(entry => {
       all2((
         Prompt.yesNo("\nAdd another keyset? [Y/n] "),
         resolve(Array.append(config, [|entry|])),
       ))
     })
  |> then_(((another, newConfig)) =>
       another ? prompt(newConfig) : resolve(newConfig)
     )
  |> catch(error => {
       Js.log(error);
       resolve([||]);
     });
};
