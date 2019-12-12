[@react.component]
let make = (~className="", ~paragraphs) => {
  let ps =
    paragraphs
    |> Array.mapi((i, entry) => {
         let key = string_of_int(i);
         let content =
           switch (entry) {
           | `str(s) => [|<span key> {React.string(s)} </span>|]
           | `styled(xs) =>
             List.mapi(
               (i, x) => {
                 let styleKey = string_of_int(i);
                 switch (x) {
                 | `emph(s) =>
                   <span key=styleKey className=Theme.Body.basic_semibold>
                     {React.string(s)}
                   </span>
                 | `str(s) => <span key=styleKey> {React.string(s)} </span>
                 };
               },
               xs,
             )
             |> Array.of_list
           };

         <p
           key
           className=Css.(
             merge([Theme.Body.basic, style([marginBottom(`rem(1.5))])])
           )>
           {React.array(content)}
         </p>;
       });

  <div
    className=Css.(
      merge([
        className,
        style([media(Theme.MediaQuery.notMobile, [width(`rem(20.625))])]),
      ])
    )>
    {React.array(ps)}
  </div>;
};
