let navigate = route => ReasonReact.Router.push("#" ++ Route.print(route));

let listenToMain = () =>
  MainCommunication.on((. _event, message) =>
    switch (message) {
    | `Deep_link(route) => navigate(route)
    }
  );
