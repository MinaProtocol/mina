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
    href: [ | `External(string) | `Internal(string)],
  };

  type label = {
    labelColor: Css.color,
    labelText: string,
    href: [ | `External(string) | `Internal(string)],
  };

  type link =
    | Button(buttonType)
    | Label(label);

  type t = {
    rowType,
    copySize: [ | `Large | `Small],
    title: string,
    description: string,
    textColor: Css.color,
    image: string,
    background: backgroundType,
    contentBackground: backgroundType,
    link,
  };
};

/* The reason we have a custom wrapped component here is because we want the
   image to be the full width of the screen on mobile. If we wrap our component
   in a normal wrap, a width margin is applied on mobile which we don't want. Instead
   we create a custom wrapped component for this component only */

module CustomWrapped = {
  open Css;

  [@react.component]
  let make = (~overflowHidden=false, ~children) => {
    let paddingX = m => [paddingLeft(m), paddingRight(m)];
    <div
      className={style(
        (overflowHidden ? [overflow(`hidden)] : [])
        @ [
          margin(`auto),
          media(
            Theme.MediaQuery.tablet,
            [maxWidth(`rem(85.0)), ...paddingX(`rem(2.5))],
          ),
          media(
            Theme.MediaQuery.desktop,
            [maxWidth(`rem(90.0)), ...paddingX(`rem(9.5))],
          ),
        ],
      )}>
      children
    </div>;
  };
};

module SingleRow = {
  module RowStyles = {
    open Css;

    let childreWrapped =
      style([
        margin(`auto),
        padding2(~v=`zero, ~h=`rem(1.5)),
        media(
          Theme.MediaQuery.notMobile,
          [margin(`zero), padding2(~v=`zero, ~h=`zero)],
        ),
      ]);

    let container =
      style([
        position(`relative),
        width(`percent(100.)),
        height(`rem(41.)),
        display(`flex),
        flexDirection(`column),
        alignItems(`center),
      ]);

    let contentBlock = (size, contentBackground: Row.backgroundType) => {
      let additionalNotMobileStyles =
        switch (size) {
        | `Large => []
        | `Small => [bottom(`percent(35.))]
        };
      style([
        position(`absolute),
        width(`percent(92.5)),
        maxHeight(`rem(35.)),
        overflow(`scroll),
        unsafe("height", "fit-content"),
        margin2(~h=`rem(5.), ~v=`zero),
        display(`flex),
        flexDirection(`column),
        alignItems(`flexStart),
        justifyContent(`spaceBetween),
        padding(`rem(2.)),
        backgroundSize(`cover),
        media(
          Theme.MediaQuery.notMobile,
          [
            width(`percent(100.)),
            margin(`zero),
            overflow(`hidden),
            ...additionalNotMobileStyles,
          ],
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
        selector(
          "p",
          [Theme.Typeface.monumentGroteskMono, letterSpacing(`px(-1))],
        ),
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
        height(`percent(70.)),
        maxWidth(`rem(53.)),
        paddingTop(`rem(8.)),
        bottom(`zero),
        media(
          Theme.MediaQuery.tablet,
          [height(`percent(110.)), width(`percent(80.))],
        ),
        media(Theme.MediaQuery.desktop, [width(`percent(100.))]),
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
            bottom(`percent(30.)),
            media(Theme.MediaQuery.notMobile, [bottom(`zero)]),
          ]),
        ]);

      let contentBlock = (size, backgroundImg) => {
        merge([
          RowStyles.contentBlock(size, backgroundImg),
          style([
            bottom(`percent(5.)),
            media(
              Theme.MediaQuery.tablet,
              [
                bottom(`percent(25.)),
                top(`inherit_),
                right(`zero),
                width(`rem(29.)),
              ],
            ),
          ]),
        ]);
      };
    };

    [@react.component]
    let make = (~row: Row.t) => {
      <div className=RowStyles.container>
        <img src={row.image} className=Styles.image />
        <div
          className={Styles.contentBlock(row.copySize, row.contentBackground)}>
          <div className={RowStyles.copyText(row.textColor)}>
            <h2 className=Theme.Type.h2> {React.string(row.title)} </h2>
            <p className=RowStyles.description>
              {React.string(row.description)}
            </p>
          </div>
          <div className=Css.(style([marginTop(`rem(1.))]))>
            {switch (row.link) {
             | Button(button) =>
               <Button
                 textColor={button.buttonTextColor}
                 bgColor={button.buttonColor}
                 dark={button.dark}
                 href={button.href}>
                 <span className=RowStyles.buttonText>
                   {React.string(button.buttonText)}
                   <Icon kind=Icon.ArrowRightSmall size=1.5 />
                 </span>
               </Button>
             | Label(label) =>
               <Button.Link href={label.href}>
                 <span>
                   <Spacer height=1. />
                   <span className=Theme.Type.buttonLink>
                     <span> {React.string(label.labelText)} </span>
                     <Icon kind=Icon.ArrowRightMedium />
                   </span>
                 </span>
               </Button.Link>
             }}
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

      let contentBlock = (size, contentBackground) => {
        merge([
          RowStyles.contentBlock(size, contentBackground),
          style([
            top(`percent(5.)),
            media(
              Theme.MediaQuery.tablet,
              [left(`zero), width(`rem(32.)), top(`percent(15.))],
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
        <div
          className={Styles.contentBlock(row.copySize, row.contentBackground)}>
          <div className={RowStyles.copyText(row.textColor)}>
            <h2 className=Theme.Type.h2> {React.string(row.title)} </h2>
            <p className=RowStyles.description>
              {React.string(row.description)}
            </p>
          </div>
          <div className=Css.(style([marginTop(`rem(1.))]))>
            {switch (row.link) {
             | Button(button) =>
               <Button
                 textColor={button.buttonTextColor}
                 bgColor={button.buttonColor}
                 dark={button.dark}
                 href={button.href}>
                 <span className=RowStyles.buttonText>
                   {React.string(button.buttonText)}
                   <Icon kind=Icon.ArrowRightSmall size=1.5 />
                 </span>
               </Button>
             | Label(label) =>
               <Button.Link href={label.href}>
                 <span>
                   <Spacer height=1. />
                   <span className=Theme.Type.link>
                     <span> {React.string(label.labelText)} </span>
                     <Icon kind=Icon.ArrowRightMedium />
                   </span>
                 </span>
               </Button.Link>
             }}
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
      minHeight(`rem(32.5)),
      width(`percent(100.)),
      important(backgroundSize(`cover)),
      switch (backgroundImg) {
      | Image(url) => backgroundImage(`url(url))
      | Color(color) => backgroundColor(color)
      },
    ]);
};

[@react.component]
let make = (~row: Row.t, ~children=?) => {
  <div className={Styles.singleRowBackground(row.background)}>
    <CustomWrapped>
      {switch (row.rowType) {
       | ImageLeftCopyRight => <SingleRow.ImageLeftCopyRight row />
       | ImageRightCopyLeft => <SingleRow.ImageRightCopyLeft row />
       }}
      {switch (children) {
       | Some(children) =>
         <div className=SingleRow.RowStyles.childreWrapped> children </div>
       | None => <> </>
       }}
    </CustomWrapped>
  </div>;
};
