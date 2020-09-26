// Remove cloneElement once https://github.com/reasonml/reason-react/pull/469 is merged
let katexStylesheet = {
  ReasonReact.cloneElement(
    <link
      rel="stylesheet"
      href="https://cdn.jsdelivr.net/npm/katex@0.11.0/dist/katex.min.css"
      integrity="sha384-BdGj8xC2eZkQaxoQ8nSLefg4AV4/AwB3Fj+8SUSo7pnKP6Eoy18liIKTPn9oBYNG"
    />,
    ~props={"crossOrigin": "anonymous"},
    [||],
  );
};

// We need an uncurried reference to createElement for rehype2react
[@bs.module "react"]
external createElement: (. React.component('props), 'props) => React.element =
  "createElement";

[@react.component]
let make = (~content) => {
  open Unified.Transformers;
  let result =
    Unified.create()
    ->Unified.use(markdown, {"footnotes": true})
    ->Unified.use(math, ())
    ->Unified.use(remarkRehype, {"allowDangerousHTML": true})
    ->Unified.use(rehypeRaw, ())
    ->Unified.use(katex, ())
    ->Unified.use(
        rehypeReact,
        {"createElement": createElement, "Fragment": ReasonReact.fragment,
        "components": {
          a: DocsComponents.A.make,
          p: DocsComponents.P.make,
          code: DocsComponents.Code.make,
          pre: DocsComponents.Pre.make,
          h2: DocsComponents.H2.make,
          h3: DocsComponents.H3.make,
          h4: DocsComponents.H4.make,
          ol: DocsComponents.Ol.make,
          ul: DocsComponents.Ul.make,
          strong: DocsComponents.Strong.make,
          img: DocsComponents.Blog.Img.make
        } },
      )
    ->Unified.processSync(~content);

  result.contents;
};
