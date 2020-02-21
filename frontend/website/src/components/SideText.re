[@react.component]
let make = (~className="", ~paragraphs) => {
  let ps =
    paragraphs
    |> Array.map(entry => {
         let content =
           switch (entry) {
           | `str(s) => [|<span> {React.string(s)} </span>|]
           | `styled(xs) =>
             List.map(
               x => {
                 switch (x) {
                 | `emph(s) =>
                   <span className=Theme.Body.basic_semibold>
                     {React.string(s)}
                   </span>
                 | `str(s) => <span> {React.string(s)} </span>
                 }
               },
               xs,
             )
             |> Array.of_list
           };

         <p
           className=Css.(
             merge([Theme.Body.basic, style([marginBottom(`rem(1.5))])])
           )>
           {ReactExt.staticArray(content)}
         </p>;
       });

  <div
    className=Css.(
      merge([
        className,
        style([media(Theme.MediaQuery.notMobile, [width(`rem(20.625))])]),
      ])
    )>
    {ReactExt.staticArray(ps)}
  </div>;
};
