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

let start = (apolloClient: ApolloClient.generatedApolloClient) =>
  GraphqlIpcMain.on((. event, m) =>
    switch (m) {
    | `Pipe_graphql_request(id, (kind, requestStr)) =>
      let r = Js.Json.parseExn(requestStr);

      let query =
        switch (kind) {
        | GraphqlLinkMessages.Kind.Query =>
          Js.log("Treating as query");
          let r: ApolloClient.queryObj = Obj.magic(r);
          Task.liftErrorPromise(() => apolloClient##query(r))
          |> Task.map(~f=Js.Json.stringifyAny);
        | Mutation =>
          Js.log("Treating as mutation");
          let r: ApolloClient.mutationObj = Obj.magic(r);
          Task.liftErrorPromise(() => apolloClient##mutate(r))
          |> Task.map(~f=Js.Json.stringifyAny);
        };

      Task.attempt(
        ~f=
          result =>
            switch (result) {
            | Ok(response) =>
              let response: Tc.Result.t(string, string) =
                switch (response) {
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
            | Error(err) =>
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
