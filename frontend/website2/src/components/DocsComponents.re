module type Component = {
  let className: string;
  let element: React.element;
};

module Wrap = (C: Component) => {
  let className = C.className;
  let make = props => {
    ReasonReact.cloneElement(C.element, ~props, [||]);
  };
};

open Css;

let headerStyle =
  style([
    display(`flex),
    marginTop(rem(2.)),
    marginBottom(`rem(0.5)),
    color(Theme.Colors.denimTwo),
  ]);

module H1 =
  Wrap({
    let className =
      merge([
        headerStyle,
        Theme.H1.hero,
        style([alignItems(`baseline), fontWeight(`light)]),
      ]);
    let element = <h1 className />;
  });

module H2 =
  Wrap({
    let className =
      merge([
        headerStyle,
        Theme.H2.basic,
        style([alignItems(`baseline), fontWeight(`light)]),
      ]);
    let element = <h2 className />;
  });

module H3 =
  Wrap({
    let className =
      merge([
        headerStyle,
        Theme.H3.basic,
        style([alignItems(`center), fontWeight(`medium)]),
      ]);

    let element = <h2 className />;
  });

module H4 =
  Wrap({
    let className = merge([headerStyle, Theme.H4.basic]);
    let element = <h2 className />;
  });

module P =
  Wrap({
    let className =
      style([
        color(Theme.Colors.saville),
        fontWeight(`extraLight),
        ...Theme.Body.basicStyles,
      ]);

    let element = <p className />;
  });

module A =
  Wrap({
    let className = Theme.Link.basic;
    let element = <a className />;
  });

module Strong =
  Wrap({
    let className =
      style([fontWeight(`num(600)), color(Theme.Colors.saville)]);
    let element = <strong className />;
  });

module Pre =
  Wrap({
    let className =
      style([
        backgroundColor(Theme.Colors.slateAlpha(0.05)),
        borderRadius(`px(9)),
        padding2(~v=`rem(0.5), ~h=`rem(1.)),
        overflow(`scroll),
      ]);
    let element = <pre className />;
  });

module Code =
  Wrap({
    let className =
      style([Theme.Typeface.pragmataPro, color(Theme.Colors.midnight)]);
    let element = <code className />;
  });

module Ul =
  Wrap({
    let className =
      merge([
        style([
          margin2(~v=`rem(1.), ~h=`zero),
          marginLeft(rem(1.5)),
          padding(`zero),
        ]),
        Theme.Body.basic,
      ]);
    let element = <ul className />;
  });

module Ol =
  Wrap({
    let className = Ul.className;
    let element = <ol className />;
  });

module Metadata = {
  [@react.component]
  let make = (~title) => {
    <Next.Head> <title> {React.string(title)} </title> </Next.Head>;
  };
};
