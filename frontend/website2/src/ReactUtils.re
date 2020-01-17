let fromOpt = (~f, v) =>
  Option.map(f, v) |> Option.value(~default=React.null);

[@bs.obj]
external makeProps:
  (~value: 'a, ~children: React.element, unit) =>
  {
    .
    "value": 'a,
    "children": React.element,
  } =
  "";

let createContext = default => {
  let context = React.createContext(default);
  let make = context->React.Context.provider;
  (context, make, makeProps);
};
