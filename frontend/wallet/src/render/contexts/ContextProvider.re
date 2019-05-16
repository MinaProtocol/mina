module type ContextType = {
  type t;
  let initialContext: t;
};

module Make = (T: ContextType) => {
  type context = T.t;

  let context = React.createContext(T.initialContext);

  let make = context->React.Context.provider;

  [@bs.obj]
  external makeProps:
    (~value: context, ~children: React.element, ~key: string=?, unit) =>
    {
      .
      "value": context,
      "children": React.element,
    } =
    "";
};
