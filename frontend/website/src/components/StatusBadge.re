module Styles = {
  open Css;
  let wrapper = (bgColor, fgColor) =>
    style([
      backgroundColor(bgColor),
      color(fgColor),
      width(`rem(10.)),
      borderRadius(`px(5)),
      display(`inlineFlex),
      justifyContent(`center),
    ]);
  let link = style([textDecoration(`none), display(`inline)]);
};

let url = "https://status.codaprotocol.com";
let apiPath = "/api/v2/summary.json";

type component = {
  id: string,
  name: string,
  status: string,
};
type response = {components: array(component)};

external parseStatusResponse: Js.Json.t => response = "%identity";

type service = [ | `Summary | `Network | `Faucet | `EchoBot | `GraphQLProxy];

type status =
  | Unknown
  | Operational
  | Maintenance;

let parseStatus = status =>
  switch (status) {
  | "under_maintenance" => Maintenance
  | "operational" => Operational
  | s =>
    Js.Console.warn("Unknown status `" ++ s ++ "`");
    Unknown;
  };

let parseServiceName = name =>
  switch (name) {
  | "Network" => `Network
  | "Faucet" => `Faucet
  | "Echo Bot" => `EchoBot
  | "GraphQL Proxy" => `GraphQLProxy
  | "Coda Testnet"
  | "Summary" => `Summary
  | s =>
    Js.Console.warn("Unknown status service `" ++ s ++ "`");
    `Summary;
  };

module Inner = {
  [@react.component]
  let make = (~service: service) => {
    let (status, setStatus) = React.useState(() => Unknown);
    React.useEffect0(() => {
      ReFetch.fetch(url ++ apiPath)
      |> Promise.bind(ReFetch.Response.json)
      |> Promise.map(parseStatusResponse)
      |> Promise.iter(response => {
           let components =
             response.components
             |> Array.to_list
             |> List.filter(c => parseServiceName(c.name) == service);
           switch (components) {
           | [] => Js.Console.warn("Error retrieving status")
           | [{status}, ..._] =>
             Js.log2("test", status);
             setStatus(_ => parseStatus(status));
           };
         });
      None;
    });
    let (statusStr, bgColor) =
      switch (status) {
      | Unknown => ("Unknown", Theme.Colors.grey)
      | Operational => ("Operational", Theme.Colors.clover)
      | Maintenance => ("Under Maintenance", Theme.Colors.rosebud)
      };
    <a href=url className=Styles.link>
      <span className={Styles.wrapper(bgColor, Theme.Colors.white)}>
        {React.string(statusStr)}
      </span>
    </a>;
  };
};

let (make, makeProps) = Inner.(make, makeProps);

// For use from MDX code
let default = (props: {. "service": string}) => {
  <Inner service={parseServiceName(props##service)} />;
};
