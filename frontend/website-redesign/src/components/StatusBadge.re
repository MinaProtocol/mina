module Styles = {
  open Css;
  let wrapper = (bgColor, fgColor) =>
    style([
      backgroundColor(white),
      border(`px(4), `solid, fgColor),
      color(fgColor),
      fontWeight(`medium),
      textTransform(`uppercase),
      height(`rem(3.)),
      borderRadius(`px(4)),
      display(`inlineFlex),
      justifyContent(`center),
      alignItems(`center),
      padding2(~v=`zero, ~h=`rem(1.)),
      selector(
        "svg",
        [
          marginLeft(`rem(0.5)),
          SVG.fill(Theme.Colors.digitalBlackA(0.5)),
        ],
      ),
      hover([
        backgroundColor(bgColor),
        selector("svg", [SVG.fill(fgColor)]),
      ]),
    ]);
  let statusCircle =
    style([
      width(`px(14)),
      height(`px(14)),
      borderRadius(`percent(50.)),
      backgroundColor(`currentColor),
      marginRight(`rem(0.5)),
    ]);
  let link =
    style([
      textDecoration(`none),
      display(`inline),
      margin2(~v=`zero, ~h=`rem(0.5)),
    ]);

  let icon = style([display(`inlineFlex), alignItems(`center)]);
};

let url = "https://status.minaprotocol.com";
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
  | DegradedPerformance
  | PartialOutage
  | MajorOutage
  | UnderMaintenance;

let parseStatus = status =>
  switch (status) {
  | "operational" => Operational
  | "degraded_performance" => DegradedPerformance
  | "partial_outage" => PartialOutage
  | "major_outage" => MajorOutage
  | "under_maintenance" => UnderMaintenance
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
  | "Mina Testnet"
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
           | [{status}, ..._] => setStatus(_ => parseStatus(status))
           };
         });
      None;
    });
    let (statusStr, bgColor, fgColor) = {
      switch (status) {
      | Unknown => (
          "Unknown",
          Theme.Colors.digitalBlackA(0.1),
          Css_Colors.grey,
        )
      | Operational => (
          "Operational",
          Theme.Colors.operational,
          Theme.Colors.operational,
        )
      | DegradedPerformance => (
          "Degraded",
          Theme.Colors.amberAlpha(0.1),
          Theme.Colors.amber,
        )
      | PartialOutage => (
          "Partial Outage",
          Theme.Colors.digitalBlackA(0.1),
          Css_Colors.grey,
        )
      | MajorOutage => (
          "Major Outage",
          Theme.Colors.digitalBlackA(0.1),
          Css_Colors.grey,
        )
      | UnderMaintenance => (
          "Under Maintenance",
          Theme.Colors.digitalBlackA(0.1),
          Css_Colors.grey,
        )
      };
    };
    <a href=url className=Styles.link target="_blank">
      <span className={Styles.wrapper(bgColor, fgColor)}>
        <span className=Styles.statusCircle />
        <span className=Theme.Type.buttonLabel>
          {React.string(statusStr)}
        </span>
        <span className=Styles.icon> <Icon kind=Icon.ExternalLink /> </span>
      </span>
    </a>;
    //Icons.externalLink
  };
};

let (make, makeProps) = Inner.(make, makeProps);

// For use from MDX code
let default = (props: {. "service": string}) => {
  <Inner service={parseServiceName(props##service)} />;
};
