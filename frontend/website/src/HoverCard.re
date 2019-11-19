module Styles = {
  open Css;

  let ctaButton =
    style([
      background(Style.Colors.lightBlue),
      borderRadius(`px(6)),
      textDecoration(`none),
      padding(`rem(2.0)),
      margin(`auto),
      height(`rem(13.)),
      width(`percent(80.)),
      media(
        "(min-width: 35rem)",
        [ 
           height(`rem(10.)),
           width(`rem(29.)),
        ],
      ),
      media(
        "(min-width: 50rem)",
        [ 
           height(`rem(11.)),
           width(`rem(23.)),
        ],
      ),
      media(
        "(min-width: 75rem)",
        [ 
           height(`rem(10.)),
           width(`rem(35.)),
        ],
      ),
      hover([
        backgroundColor(`hex("FAFCFD")),
        cursor(`pointer),
        boxShadow(
          ~x=`zero,
          ~y=`px(4),
          ~blur=`px(8),
          ~spread=`zero,
          `rgba((0, 0, 0, 0.25)),
        ),
      ]),
    ]);

  let ctaContent =
    style([display(`flex), selector("p", [fontSize(`px(36))])]);

  let ctaText = style([marginLeft(`px(13))]);

  let ctaHeading =
    merge([Style.H2.basic,style([
      Style.Typeface.ibmplexsans,
      color(Style.Colors.marine),
      textAlign(`left),
      paddingBottom(`rem(0.3)),
    ])]);

  let ctaBody =
      Style.Body.basic;
  let ctaIcon =
    style([
      marginTop(`px(2)),
      minWidth(`px(36)),
      maxHeight(`px(48)),
      flexShrink(0),
    ]);
};

[@react.component]
let make = (~icon=?, ~heading, ~text, ~href) => {
  <a href className=Styles.ctaButton>
    <div className=Styles.ctaContent>
      {switch (icon) {
       | Some(icon) => <p className=Styles.ctaIcon> icon </p>
       | None => React.null
       }}
      <div className=Styles.ctaText>
        <h2 className=Styles.ctaHeading> heading </h2>
        <h4 className=Styles.ctaBody> text </h4>
      </div>
    </div>
  </a>;
};
