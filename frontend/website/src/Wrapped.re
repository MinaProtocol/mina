[@react.component]
let make = (~overflowHidden=false, ~children) => {
  <div
    className=Css.(
      style(
        (overflowHidden ? [overflow(`hidden)] : [])
        @ [
          margin(`auto),
          media(
            Style.MediaQuery.full,
            [
              maxWidth(`rem(89.0)),
              margin(`auto),
              ...Style.paddingX(`rem(3.0)),
            ],
          ),
          ...Style.paddingX(`rem(1.25)),
        ],
      )
    )>
    children
  </div>;
};
