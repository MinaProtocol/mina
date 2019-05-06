open Tc;

type apolloObservable;
type apolloObserver = {
  .
  [@bs.meth] "next": Js.Json.t => unit,
  [@bs.meth] "error": Js.Json.t => unit,
  [@bs.meth] "complete": unit => unit,
};

[@bs.module "apollo-link"] [@bs.new]
external createObservable: (apolloObserver => unit) => apolloObservable =
  "Observable";

[@bs.module "apollo-link"] [@bs.new]
external createApolloLink:
  (GraphqlLinkMessages.apolloOperation => apolloObservable) =>
  ReasonApolloTypes.apolloLink =
  "ApolloLink";

module GraphqlIpcRenderer =
  BsElectron.IpcRenderer.MakeIpcRenderer(GraphqlLinkMessages);

let create = () => {
  let callTable = GraphqlLinkMessages.CallTable.make();
  GraphqlIpcRenderer.on((. _event, m) =>
    switch (m) {
    | `Pipe_graphql_response(id, str) =>
      GraphqlLinkMessages.CallTable.resolve(
        callTable,
        GraphqlLinkMessages.CallTable.Ident.Decode.t(
          id,
          GraphqlLinkMessages.Typ.ResultString,
        ),
        str,
      )
    }
  );

  createApolloLink(operation =>
    createObservable(observer =>
      switch (Js.Json.stringifyAny(operation)) {
      | Some(operationStr) =>
        let pending =
          GraphqlLinkMessages.CallTable.nextPending(
            callTable,
            GraphqlLinkMessages.Typ.ResultString,
            ~loc=__LOC__,
          );

        GraphqlIpcRenderer.send(
          `Pipe_graphql_request((
            GraphqlLinkMessages.CallTable.Ident.Encode.t(pending.ident),
            operationStr,
          )),
        );

        Task.perform(
          ~f=
            response =>
              switch (response) {
              | Ok(msg) =>
                observer##next(Js.Json.parseExn(msg));
                observer##complete();
              | Error(errMsg) => observer##error(Js.Json.parseExn(errMsg))
              },
          pending.task,
        );
      | None => prerr_endline("Couldn't stringify request. Shouldn't happen.")
      }
    )
  );
};
