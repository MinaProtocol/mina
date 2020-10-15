module Styles = {
  open Css;
  let link =
    style([
      Theme.Typeface.monumentGrotesk,
      cursor(`pointer),
      color(Theme.Colors.orange),
      display(`flex),
      hover([textDecoration(`underline)]),
    ]);

  let text = style([marginRight(`rem(0.2)), cursor(`pointer)]);
};

[@react.component]
let make = (~href="/", ~text="Read More") => {
  <Next.Link href>
    <div className=Styles.link>
      <span className=Styles.text> {React.string(text)} </span>
      <Icon kind=Icon.ArrowRightMedium />
    </div>
  </Next.Link>;
};
