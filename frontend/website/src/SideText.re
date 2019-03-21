let component = ReasonReact.statelessComponent("SideText");
let make = (~paragraphs, ~cta, _children) => {
  ...component,
  render: _self => {
    let ps =
      Belt.Array.map(paragraphs, p =>
        <p className=Style.Body.basic key=p> {ReasonReact.string(p)} </p>
      );

    <div className=Css.(style([width(`rem(21.0))]))>
      {ReasonReact.array(ps)}
      <a
        href=Links.mailingList
        className=Css.(
          merge([Style.Link.basic, style([marginTop(`rem(1.5))])])
        )>
        {ReasonReact.string(cta ++ {j|\u00A0→|j})}
      </a>
    </div>;
  },
};
