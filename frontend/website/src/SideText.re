module Cta = {
  type t = {
    copy: string,
    link: Links.Named.t(string),
  };
};

[@react.component]
let make = (~className="", ~paragraphs, ~cta) => {
  let {Cta.link} = cta;
  let ps =
    paragraphs
    |> Array.mapi((i, entry) => {
         let key = string_of_int(i);
         let content =
           switch (entry) {
           | `str(s) => [|<span key> {ReasonReact.string(s)} </span>|]
           | `styled(xs) =>
             List.mapi(
               (i, x) => {
                 let styleKey = string_of_int(i);
                 switch (x) {
                 | `emph(s) =>
                   <span key=styleKey className=Style.Body.basic_semibold>
                     {ReasonReact.string(s)}
                   </span>
                 | `str(s) =>
                   <span key=styleKey> {ReasonReact.string(s)} </span>
                 };
               },
               xs,
             )
             |> Array.of_list
           };

         <p
           key
           className=Css.(
             merge([Style.Body.basic, style([marginBottom(`rem(1.5))])])
           )>
           {React.array(content)}
         </p>;
       });

  <div
    className=Css.(
      merge([
        className,
        style([media(Style.MediaQuery.notMobile, [width(`rem(20.625))])]),
      ])
    )>
    {React.array(ps)}
  </div>;
};
