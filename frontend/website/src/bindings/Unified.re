type processor('a, 'b, 'ctx);
type t('a, 'b);
type node('a) = {contents: 'a};

[@bs.module] external create: unit => t(string, string) = "unified";

[@bs.send]
external use: (t('a, 'b), processor('b, 'c, 'ctx), 'ctx) => t('a, 'c) =
  "use";

[@bs.send]
external processSync: (t('a, 'b), ~content: 'a) => node('b) = "processSync";

module Transformers = {
  type markdown;
  type html;

  [@bs.module]
  external markdown: processor(string, markdown, {. "footnotes": bool}) =
    "remark-parse";

  [@bs.module]
  external math: processor(markdown, markdown, unit) = "remark-math";

  [@bs.module] external katex: processor(html, html, unit) = "rehype-katex";

  [@bs.module]
  external remarkRehype:
    processor(markdown, html, {. "allowDangerousHTML": bool}) =
    "remark-rehype";

  [@bs.module]
  external rehypeReact:
    processor(
      html,
      React.element,
      {
        .
        "createElement": (. React.component('props), 'props) => React.element,
        "Fragment": React.component('a),
      },
    ) =
    "rehype-react";

  // Reparse raw html after converting from markdown
  [@bs.module] external rehypeRaw: processor(html, html, unit) = "rehype-raw";

  [@bs.module]
  external sanitize: processor(html, html, unit) = "rehype-sanitize";
};
