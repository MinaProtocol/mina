module Cta = {
  type t = {
    copy: string,
    link: string,
  };
};
let component = ReasonReact.statelessComponent("SideText");
let make = (~className="", ~paragraphs, ~cta, _children) => {
  ...component,
  render: _self => {
    let {Cta.copy, link} = cta;
    let ps =
      Belt.Array.mapWithIndex(paragraphs, (i, p) =>
        <p
          className=Css.(
            merge([
              Style.Body.basic,
              style(
                if (i == 0) {
                  [marginTop(`zero)];
                } else {
                  [];
                },
              ),
            ])
          )
          key=p>
          {ReasonReact.string(p)}
        </p>
      );

    <div
      className=Css.(
        merge([
          className,
          style([
            media(Style.MediaQuery.notMobile, [width(`rem(20.625))]),
          ]),
        ])
      )>
      {ReasonReact.array(ps)}
      <a
        target="_blank"
        href=link
        className=Css.(
          merge([Style.Link.basic, style([marginTop(`rem(1.5))])])
        )>
        {ReasonReact.string(copy ++ {j|\u00A0→|j})}
      </a>
    </div>;
  },
};
