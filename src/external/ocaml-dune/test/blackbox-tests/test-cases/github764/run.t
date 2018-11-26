  $ mkdir -p c1
  $ cd c1 && ln -s . x
  $ cd c1 && ln -s . y
  $ cd c1 && dune build
  Path . has already been scanned. Cannot scan it again through symlink x
  [1]

  $ mkdir -p c2/a c2/b
  $ cd c2/a && ln -s ../b x
  $ cd c2/b && ln -s ../a x
  $ cd c2 && dune build
  Path a has already been scanned. Cannot scan it again through symlink a/x/x
  [1]

  $ mkdir symlink-outside-root
  $ cd symlink-outside-root && ln -s ../sample-exe sample
  $ cd symlink-outside-root && echo "(lang dune 1.0)" > dune-project
  $ cd symlink-outside-root && jbuilder exec --root . -- sample/foo.exe
  foo

  $ mkdir -p symlink-outside-root2/root
  $ mkdir -p symlink-outside-root2/other/a
  $ mkdir -p symlink-outside-root2/other/b
  $ cd symlink-outside-root2/other/a && ln -s ../b x
  $ cd symlink-outside-root2/other/b && ln -s ../a x
  $ cd symlink-outside-root2/root && ln -s ../other src
  $ cd symlink-outside-root2/root && dune build
  Path src/a has already been scanned. Cannot scan it again through symlink src/a/x/x
  [1]

  $ mkdir -p symlink-outside-root3/root
  $ mkdir -p symlink-outside-root3/other
  $ cd symlink-outside-root3/root  && ln -s ../other src
  $ cd symlink-outside-root3/other && ln -s ../other foo
  $ cd symlink-outside-root3/root && dune build
  Path src has already been scanned. Cannot scan it again through symlink src/foo
  [1]
