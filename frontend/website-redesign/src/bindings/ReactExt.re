[@bs.get]
external props: React.element => {.. "children": React.element} = "props";

module Children = {
  [@bs.val] [@bs.module "react"] [@bs.scope "Children"]
  external only: React.element => React.element = "only";

  [@bs.val] [@bs.module "react"] [@bs.scope "Children"]
  external forEach: (React.element, (. React.element) => 'a) => unit =
    "forEach";

  [@bs.val] [@bs.module "react"] [@bs.scope "Children"]
  external toArray: React.element => array(React.element) = "toArray";
};

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

// Other helper fns

let fromOpt = (~f, v) =>
  Option.map(f, v) |> Option.value(~default=React.null);

let staticArray = a => {
  a
  |> Array.mapi((i, e) =>
       <React.Fragment key={string_of_int(i)}> e </React.Fragment>
     )
  |> React.array;
};
