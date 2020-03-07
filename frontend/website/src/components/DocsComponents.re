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

[@bs.scope ("navigator", "clipboard")] [@bs.val]
external writeText: string => Js.Promise.t(unit) = "writeText";

module Pre = {
  let make = props => {
    let text =
      Js.String.trim(
        Js.String.make(
          {
            let props =
              ReactExt.Children.only(props##children) |> ReactExt.props;
            props##children;
          },
        ),
      );
    <pre
      className={style([
        backgroundColor(Theme.Colors.slateAlpha(0.05)),
        borderRadius(`px(9)),
        padding2(~v=`rem(0.5), ~h=`rem(1.)),
        overflow(`scroll),
        position(`relative),
      ])}>
      <div
        className={style([
          position(`absolute),
          top(`px(6)),
          right(`px(6)),
          width(`px(24)),
          height(`px(24)),
          height(`px(24)),
          opacity(0.2),
          cursor(`pointer),
          backgroundImage(
            `url(
              "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNTEyIiBoZWlnaHQ9IjUxMiIgdmlld0JveD0iMCAwIDUxMiA1MTIiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI1MTIiIGhlaWdodD0iNTEyIiAvPgo8cGF0aCBmaWxsLXJ1bGU9ImV2ZW5vZGQiIGNsaXAtcnVsZT0iZXZlbm9kZCIgZD0iTTMwMSAxMzBIMTUzVjM3MUgxMzdWMTIyQzEzNyAxMTcuNTgyIDE0MC41ODIgMTE0IDE0NSAxMTRIMzAxVjEzMFpNMTg2IDM4NlYxNjJIMzI2VjM4NkgxODZaTTE3MCAxNTRDMTcwIDE0OS41ODIgMTczLjU4MiAxNDYgMTc4IDE0NkgzMzRDMzM4LjQxOCAxNDYgMzQyIDE0OS41ODIgMzQyIDE1NFYzOTRDMzQyIDM5OC40MTggMzM4LjQxOCA0MDIgMzM0IDQwMkgxNzhDMTczLjU4MiA0MDIgMTcwIDM5OC40MTggMTcwIDM5NFYxNTRaIiBmaWxsPSJibGFjayIvPgo8L3N2Zz4K",
            ),
          ),
          backgroundSize(`cover),
          hover([opacity(0.7)]),
        ])}
        onClick={_ => {
          // TODO: Change copy icon to checkmark or something when copy
          writeText(text)
          |> Promise.iter(() => {Js.log("copied")})
        }}
      />
      {props##children}
    </pre>;
  };
};

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
