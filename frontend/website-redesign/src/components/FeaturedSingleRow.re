module Row = {
  type rowType =
    | ImageRightCopyLeft
    | ImageLeftCopyRight;

  type backgroundType =
    | Image(string)
    | Color(Css.color);

  type buttonType = {
    buttonColor: Css.color,
    buttonTextColor: Css.color,
    buttonText: string,
    dark: bool,
  };

  type t = {
    rowType,
    title: string,
    description: string,
    textColor: Css.color,
    image: string,
    background: backgroundType,
    contentBackground: backgroundType,
    button: buttonType,
  };
};

module SingleRow = {
  module RowStyles = {
    open Css;

    let container =
      style([
        position(`relative),
        width(`percent(100.)),
        height(`rem(41.)),
        display(`flex),
        flexDirection(`column),
        alignItems(`center),
      ]);

    let contentBlock = (contentBackground: Row.backgroundType) => {
      style([
        position(`absolute),
        width(`rem(21.)),
        margin2(~h=`rem(5.), ~v=`zero),
        display(`flex),
        flexDirection(`column),
        alignItems(`flexStart),
        justifyContent(`spaceBetween),
        padding(`rem(3.)),
        important(backgroundSize(`cover)),
        media(
          Theme.MediaQuery.notMobile,
          [margin(`zero), bottom(`percent(35.))],
        ),
        switch (contentBackground) {
        | Image(url) => backgroundImage(`url(url))
        | Color(color) => backgroundColor(color)
        },
      ]);
    };

    let copyText = textColor => {
      style([
        display(`flex),
        flexDirection(`column),
        alignItems(`flexStart),
        selector("h2,p", [color(textColor)]),
      ]);
    };

    let buttonText =
      style([
        display(`flex),
        justifyContent(`spaceBetween),
        alignItems(`center),
        width(`percent(100.)),
        fontSize(`rem(0.7)),
      ]);

    let description =
      merge([Theme.Type.sectionSubhead, style([marginTop(`rem(1.))])]);

    let image =
      style([
        position(`absolute),
        width(`percent(100.)),
        height(`percent(60.)),
        maxWidth(`rem(53.)),
        media(
          Theme.MediaQuery.notMobile,
          [height(`percent(110.)), width(`percent(80.))],
        ),
      ]);
  };
  module ImageLeftCopyRight = {
    module Styles = {
      open Css;

      let image =
        merge([
          RowStyles.image,
          style([
            left(`zero),
            media(Theme.MediaQuery.notMobile, [bottom(`zero)]),
          ]),
        ]);

      let contentBlock = backgroundImg => {
        merge([
          RowStyles.contentBlock(backgroundImg),
          style([
            bottom(`percent(6.)),
            media(
              Theme.MediaQuery.tablet,
              [right(`zero), height(`auto), width(`rem(29.))],
            ),
          ]),
        ]);
      };
    };

    [@react.component]
    let make = (~row: Row.t) => {
      <div className=RowStyles.container>
        <img src={row.image} className=Styles.image />
        <div className={Styles.contentBlock(row.contentBackground)}>
          <div className={RowStyles.copyText(row.textColor)}>
            <h2 className=Theme.Type.h2> {React.string(row.title)} </h2>
            <p className=RowStyles.description>
              {React.string(row.description)}
            </p>
          </div>
          <div className=Css.(style([marginTop(`rem(1.))]))>
            <Button bgColor={row.button.buttonColor} dark={row.button.dark}>
              <span className=RowStyles.buttonText>
                {React.string(row.button.buttonText)}
                <span className=Css.(style([marginTop(`rem(0.8))]))>
                  <Icon kind=Icon.ArrowRightSmall currentColor="white" />
                </span>
              </span>
            </Button>
          </div>
        </div>
      </div>;
    };
  };

  module ImageRightCopyLeft = {
    module Styles = {
      open Css;

      let image =
        merge([
          RowStyles.image,
          style([
            right(`zero),
            bottom(`zero),
            media(Theme.MediaQuery.notMobile, [bottom(`zero)]),
          ]),
        ]);

      let contentBlock = contentBackground => {
        merge([
          RowStyles.contentBlock(contentBackground),
          style([
            top(`percent(6.)),
            media(
              Theme.MediaQuery.tablet,
              [left(`zero), height(`auto), width(`rem(32.))],
            ),
          ]),
        ]);
      };

      let buttonText = buttonColor => {
        merge([RowStyles.buttonText, style([color(buttonColor)])]);
      };
    };

    [@react.component]
    let make = (~row: Row.t) => {
      <div className=RowStyles.container>
        <img src={row.image} className=Styles.image />
        <div className={Styles.contentBlock(row.contentBackground)}>
          <div className={RowStyles.copyText(row.textColor)}>
            <h2 className=Theme.Type.h2> {React.string(row.title)} </h2>
            <p className=RowStyles.description>
              {React.string(row.description)}
            </p>
          </div>
          <div className=Css.(style([marginTop(`rem(1.))]))>
            <Button bgColor={row.button.buttonColor} dark={row.button.dark}>
              <span className={Styles.buttonText(row.button.buttonTextColor)}>
                {React.string(row.button.buttonText)}
                <span className=Css.(style([marginTop(`rem(0.8))]))>
                  <Icon kind=Icon.ArrowRightSmall currentColor="black" />
                </span>
              </span>
            </Button>
          </div>
        </div>
      </div>;
    };
  };
};

module Styles = {
  open Css;

  let singleRowBackground = (backgroundImg: Row.backgroundType) =>
    style([
      height(`percent(100.)),
      width(`percent(100.)),
      important(backgroundSize(`cover)),
      switch (backgroundImg) {
      | Image(url) => backgroundImage(`url(url))
      | Color(color) => backgroundColor(color)
      },
    ]);
};

[@react.component]
let make = (~row: Row.t) => {
  <div className={Styles.singleRowBackground(row.background)}>
    <Wrapped>
      {switch (row.rowType) {
       | ImageLeftCopyRight => <SingleRow.ImageLeftCopyRight row />
       | ImageRightCopyLeft => <SingleRow.ImageRightCopyLeft row />
       }}
    </Wrapped>
  </div>;
};
