[@react.component]
let make = (~children) => {
  <script dangerouslySetInnerHTML={"__html": children} />;
};
