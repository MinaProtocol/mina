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

let staticArray = a => {
  a
  |> Array.mapi((i, e) =>
       <React.Fragment key={string_of_int(i)}> e </React.Fragment>
     )
  |> React.array;
};
