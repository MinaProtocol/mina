// Removes .html from a slug for backwards compatibility
let stripHTMLSuffix = s =>
  switch (String.split_on_char('.', s)) {
  | [] => ""
  | [slug, "html"] => slug
  | [slug, ..._] => slug
  };

module System = {
  type contentType = {id: string};
  type contentTypeSys = {sys: contentType};

  type sys = {
    id: string,
    contentType: contentTypeSys,
    createdAt: string,
    updatedAt: string,
  };

  type entry('a) = {
    sys,
    fields: 'a,
  };
  type entries('a) = {items: array(entry('a))};
};

module Post = {
  let id = "test";
  type t = {
    title: string,
    snippet: string,
    slug: string,
    subtitle: Js.Undefined.t(string),
    author: string,
    authorWebsite: Js.Undefined.t(string),
    date: string,
    text: string,
  };
  type entry = System.entry(t);
  type entries = System.entries(t);
};

module JobPost = {
  let id = "jobPost";
  type t = {
    title: string,
    jobDescription: string,
    slug: string,
  };
  type entry = System.entry(t);
  type entries = System.entries(t);
};

module KnowledgeBase = {
  let id = "knowledgeBase";
  type link = {
    title: string,
    url: string,
  };
  type links = {
    articles: array(link),
    videos: array(link),
  };
  type t = {links};
  type entry = System.entry(t);
  type entries = System.entries(t);
};

module DocsPage = {
  let id = "docsPage2";
  type t = {
    title: string,
    slug: string,
    content: string,
  };
  type entry = System.entry(t);
  type entries = System.entries(t);
};

module DocsFolder = {
  let id = "docsPage";
  type docsChild;
  type docsChildEntry = System.entry(docsChild);
  type t = {
    title: string,
    slug: string,
    children: array(docsChildEntry),
  };
  type entry = System.entry(t);
  type entries = System.entries(t);
  external childToPageUnsafe: docsChildEntry => DocsPage.entry = "%identity";
  external childToFolderUnsafe: docsChildEntry => entry = "%identity";
};

module Docs = {
  type t = [ | `Page(DocsPage.t) | `Folder(DocsFolder.t)];

  let fromDocsChild = (entry: System.entry(DocsFolder.docsChild)) =>
    if (entry.sys.contentType.sys.id == DocsPage.id) {
      `Page(DocsFolder.childToPageUnsafe(entry).fields);
    } else {
      `Folder(DocsFolder.childToFolderUnsafe(entry).fields);
    };
};
