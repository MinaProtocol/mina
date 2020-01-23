module Style = {
  open Css;
  let header =
    style([
      display(`flex),
      marginTop(rem(2.)),
      marginBottom(`rem(0.5)),
      color(Theme.Colors.denimTwo),
      hover([selector(".headerlink", [display(`inlineBlock)])]),
    ]);

  let headerLink =
    style([
      display(`none),
      width(rem(1.)),
      height(rem(1.)),
      fontSize(`px(16)),
      lineHeight(`px(24)),
      marginLeft(rem(0.5)),
      color(`transparent),
      hover([color(`transparent)]),
      backgroundSize(`cover),
      backgroundImage(url("/static/img/link.svg")),
    ]);

  let list =
    merge([
      style([
        margin2(~v=`rem(1.), ~h=`zero),
        marginLeft(rem(1.5)),
        padding(`zero),
      ]),
      Theme.Body.basic,
    ]);
};

module type Component = {let element: React.element;};

module Wrap = (C: Component) => {
  let make = props => {
    ReasonReact.cloneElement(C.element, ~props, [||]);
  };
};

module WrapHeader = (C: Component) => {
  let make = props => {
    switch (Js.Undefined.toOption(props##id)) {
    | None => ReasonReact.cloneElement(C.element, ~props, [||])
    | Some(id) =>
      // Somewhat dangerously add a headerlink to the header's children
      let children =
        Js.Array.concat(
          [|
            <a
              className={"headerlink " ++ Style.headerLink}
              href={"#" ++ id}
            />,
          |],
          [|props##children|],
        );
      ReasonReact.cloneElement(C.element, ~props, children);
    };
  };
};

open Css;

module H1 =
  WrapHeader({
    let element =
      <h1
        className={merge([
          Style.header,
          Theme.H1.hero,
          style([alignItems(`baseline), fontWeight(`light)]),
        ])}
      />;
  });

module H2 =
  WrapHeader({
    let element =
      <h2
        className={merge([
          Style.header,
          Theme.H2.basic,
          style([alignItems(`baseline), fontWeight(`light)]),
        ])}
      />;
  });

module H3 =
  WrapHeader({
    let element =
      <h2
        className={merge([
          Style.header,
          Theme.H3.basic,
          style([alignItems(`center), fontWeight(`medium)]),
        ])}
      />;
  });

module H4 =
  WrapHeader({
    let element = <h2 className={merge([Style.header, Theme.H4.basic])} />;
  });

module P =
  Wrap({
    let element =
      <p
        className={style([
          color(Theme.Colors.saville),
          fontWeight(`extraLight),
          ...Theme.Body.basicStyles,
        ])}
      />;
  });

module A =
  Wrap({
    let element = <a className=Theme.Link.basic />;
  });

module Strong =
  Wrap({
    let element =
      <strong
        className={style([
          fontWeight(`num(600)),
          color(Theme.Colors.saville),
        ])}
      />;
  });

module Pre =
  Wrap({
    let element =
      <pre
        className={style([
          backgroundColor(Theme.Colors.slateAlpha(0.05)),
          borderRadius(`px(9)),
          padding2(~v=`rem(0.5), ~h=`rem(1.)),
          overflow(`scroll),
        ])}
      />;
  });

module Code =
  Wrap({
    let element =
      <code
        className={style([
          Theme.Typeface.pragmataPro,
          color(Theme.Colors.midnight),
        ])}
      />;
  });

module Ul =
  Wrap({
    let element = <ul className=Style.list />;
  });

module Ol =
  Wrap({
    let element = <ol className=Style.list />;
  });
