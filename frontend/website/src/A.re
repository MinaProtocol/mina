[@react.component]
let make =
    (
      ~name,
      ~id=?,
      ~href=?,
      ~target=?,
      ~className=?,
      ~innerHtml=?,
      ~children=?,
    ) => {
  let dangerouslySetInnerHTML =
    Belt.Option.map(innerHtml, innerHtml => {"__html": innerHtml});
  switch (children) {
  | None => <a name ?id ?href ?target ?className ?dangerouslySetInnerHTML />
  | Some(children) =>
    <a name ?id ?href ?target ?className ?dangerouslySetInnerHTML>
      children
    </a>
  };
};
