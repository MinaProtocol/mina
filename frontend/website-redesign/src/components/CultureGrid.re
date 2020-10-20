module Styles = {
  open Css;

  let container =
    style([
      display(`flex),
      flexDirection(`column),
      media(
        Theme.MediaQuery.desktop,
        [flexDirection(`row), justifyContent(`spaceBetween)],
      ),
    ]);

  let grid =
    style([
      display(`grid),
      gridTemplateColumns([`rem(21.)]),
      unsafe("grid-auto-rows", "min-content"),
      gridGap(`rem(1.)),
      marginTop(`rem(2.)),
      marginBottom(`rem(4.)),
      media(
        Theme.MediaQuery.tablet,
        [
          gridTemplateColumns([`rem(21.), `rem(21.)]),
          gridColumnGap(`rem(1.)),
        ],
      ),
      media(Theme.MediaQuery.desktop, [marginTop(`zero)]),
    ]);

  let h2 =
    merge([
      Theme.Type.h2,
      style([color(black), width(`percent(80.)), fontWeight(`light)]),
    ]);

  let h4 = merge([Theme.Type.h4, style([fontWeight(`normal)])]);

  let gridItem =
    style([
      height(`percent(100.)),
      backgroundColor(white),
      padding(`rem(1.5)),
    ]);

  let description =
    style([
      width(`percent(80.)),
      media(Theme.MediaQuery.notMobile, [width(`percent(80.))]),
    ]);

  let gridItemCopy =
    style([height(`percent(100.)), maxHeight(`rem(13.75))]);

  let link = merge([Theme.Type.link, style([textDecoration(`none)])]);

  let divider =
    style([
      maxWidth(`rem(71.)),
      margin2(~v=`zero, ~h=`auto),
      height(`px(1)),
      backgroundColor(Theme.Colors.digitalBlack),
    ]);
};

type section = {
  title: string,
  copy: string,
};

module GridItem = {
  [@react.component]
  let make = (~label="", ~children=?) => {
    <div className=Styles.gridItem>
      <h4 className=Styles.h4> {React.string(label)} </h4>
      <Spacer height=1. />
      {switch (children) {
       | Some(children) => <div className=Styles.gridItemCopy> children </div>
       | None => <> </>
       }}
    </div>;
  };
};

[@react.component]
let make = (~title, ~description, ~sections: array(section)) => {
  <div className=Styles.container>
    <div>
      <h2 className=Styles.h2> {React.string(title)} </h2>
      {switch (description) {
       | Some(description) =>
         <div className=Styles.description>
           <Spacer height=1. />
           description
         </div>
       | None => React.null
       }}
    </div>
    <div className=Styles.grid>
      {sections
       |> Array.map(section =>
            <div key={section.title}>
              <GridItem label={section.title}>
                <p className=Theme.Type.paragraph>
                  {React.string(section.copy)}
                </p>
              </GridItem>
            </div>
          )
       |> React.array}
    </div>
  </div>;
};
