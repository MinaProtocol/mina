open Tc;

module GraphqlIpcMain = BsElectron.IpcMain.MakeIpcMain(GraphqlLinkMessages);

let sendStringified = (event, id, stringified, errorMsg) => {
  let response: Tc.Result.t(string, string) =
    switch (stringified) {
    | Some(responseStr) => Ok(responseStr)
    | None => Error(errorMsg)
    };

  event##sender##send(
    GraphqlLinkMessages.message,
    Js.Json.stringify(
      [@warning "-20"]
      BsElectron.Json.toValidJson(`Pipe_graphql_response((id, response))),
    ),
  );
};

let start = apolloClient =>
  GraphqlIpcMain.on((. event, m) =>
    switch (m) {
    | `Pipe_graphql_request(id, requestStr) =>
      // These are the same thing
      let r: ApolloClient.queryObj = Obj.magic(Js.Json.parseExn(requestStr));
      let query =
        Task.liftPromise(() =>
          apolloClient##query(r)
          |> Js.Promise.then_(v => Js.Promise.resolve(`Ok(v)))
          |> Js.Promise.catch(e => Js.Promise.resolve(`Error(e)))
        );

      Task.perform(
        ~f=
          v =>
            switch (v) {
            | `Ok(response) =>
              let response: Tc.Result.t(string, string) =
                switch (Js.Json.stringifyAny(response)) {
                | Some(responseStr) => Ok(responseStr)
                | None => Error("Could not serialize response")
                };

              event##sender##send(
                GraphqlLinkMessages.message,
                Js.Json.stringify(
                  [@warning "-20"]
                  BsElectron.Json.toValidJson(
                    `Pipe_graphql_response((id, response)),
                  ),
                ),
              );
            | `Error(err) =>
              let error: Tc.Result.t(string, string) =
                switch (Js.Json.stringifyAny(err)) {
                | Some(responseStr) => Error(responseStr)
                | None => Error("Could not serialize error")
                };

              event##sender##send(
                GraphqlLinkMessages.message,
                Js.Json.stringify(
                  [@warning "-20"]
                  BsElectron.Json.toValidJson(
                    `Pipe_graphql_response((id, error)),
                  ),
                ),
              );
            },
        query,
      );
    }
  );
