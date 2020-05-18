[@react.component]
let make = () => {
  <div className=Css.(style([marginBottom(px(8)), textAlign(`left)]))>
    <p className=Theme.Body.basic>
      {React.string(
         "Get started on Coda by applying for the Genesis Token Program.",
       )}
    </p>
    <Spacer height=1. />
    <Button
      link="/genesis"
      label="Join Genesis"
      bgColor=Theme.Colors.hyperlink
      bgColorHover={Theme.Colors.hyperlinkAlpha(1.)}
    />
  </div>;
};
