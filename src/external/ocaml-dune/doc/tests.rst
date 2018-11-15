*************************
Writing and running tests
*************************

Dune tries to streamline the testing story as much as possible, so
that you can focus on the tests themselves and not bother with setting
up with various test frameworks.

In this section, we will explain the workflow to deal with tests in
dune. In particular we will see how to run the testsuite of a
project, how to describe your tests to dune and how to promote
tests result as expectation.

We distinguish two kinds of tests: inline tests and custom
tests. Inline tests are usually written directly inside the ml files
of a library. They are the easiest to work with and usually requires
nothing more than writing ``(inline_tests)`` inside your library
stanza. Custom tests consist on executing an executable and sometimes
do something afterwards, such as diffing its output.

Running tests
=============

Whatever the tests of a project are, the usual way to run tests with
dune is to call ``dune runtest`` from the shell. This will run
all the tests defined in the current directory and any sub-directory
recursively. You can also pass a directory argument to run the tests
from a sub-tree. For instance ``dune runtest test`` will only run
the tests from the ``test`` directory and any sub-directory of
``test`` recursively.

Note that in any case, ``dune runtest`` is simply a short-hand for
building the ``runtest`` alias, so you can always ask dune to run
the tests in conjunction with other targets by passing ``@runtest`` to
``dune build``. For instance:

.. code:: bash

          $ dune build @install @runtest
          $ dune build @install @test/runtest

Inline tests
============

There are several inline tests framework available for OCaml, such as
ppx_inline_test_ and qtest_. We will use ppx_inline_test_ as an
example as at the time of writing this document it has the necessary
setup to be used with dune out of the box.

ppx_inline_test_ allows to write tests directly inside ml files as
follow:

.. code:: ocaml

          let rec fact n = if n = 1 then 1 else n * fact (n - 1)

          let%test _ = fact 5 = 120

The file has to be preprocessed with the ppx_inline_test ppx rewriter,
so for instance the ``jbuild`` file might look like this:

.. code:: scheme

          (library
           (name foo)
           (preprocess (pps ppx_inline_test)))

In order to instruct dune that our library contains inline tests,
all we have to do is add an ``inline_tests`` field:

.. code:: scheme

          (library
           (name foo)
           (inline_tests)
           (preprocess (pps ppx_inline_test)))

We can now build and execute this test by running ``dune runtest``. For
instance, if we make the test fail by replacing ``120`` by ``0`` we get:

.. code:: bash

          $ dune runtest
          [...]
          File "src/fact.ml", line 3, characters 0-25: <<(fact 5) = 0>> is false.

          FAILED 1 / 1 tests

Note that in this case Jbuild knew how to build and run the tests
without any special configuration. This is because ppx_inline_test
defines an inline tests backend and it is used by the library. Some
other frameworks, such as qtest_ don't have any special library or ppx
rewriter. To use such a framework, you must tell dune about it
since it cannot guess it. You can do that by adding a ``backend``
field:

.. code:: scheme

          (library
           (name foo)
           (inline_tests (backend qtest)))


Inline expectation tests
------------------------

Inline expectation tests are a special case of inline tests where you
write a bit of OCaml code that prints something followed by what you
expect this code to print. For instance, using ppx_expect_:

.. code:: ocaml

          let%expect_test _ =
            print_endline "Hello, world!";
            [%expect{|
              Hello, world!
            |}]

The test procedure consist of executing the OCaml code and replacing
the contents of the ``[%expect]`` extension point by the real
output. You then get a new file that you can compare to the original
source file. Expectation tests are a neat way to write tests as the
following test elements are clearly identified:

- the code of the test
- the test expectation
- the test outcome

You can have a look at `this blog post
<https://blog.janestreet.com/testing-with-expectations/>`_ to find out
more about expectation tests. To dune, the workflow for
expectation tests is always as follows:

- write the test with some empty expect nodes in it
- run the tests
- check the suggested correction and promote it as the original source
  file if you are happy with it

Dune makes this workflow very easy, simply add ``ppx_expect`` to
your list of ppx rewriters as follow:

.. code:: scheme

          (library
           (name foo)
           (inline_tests)
           (preprocess (pps ppx_expect)))

Then calling ``dune runtest`` will run these tests and in case of
mismatch dune will print a diff of the original source file and
the suggested correction. For instance:

.. code:: bash

          $ dune runtest
          [...]
          -src/fact.ml
          +src/fact.ml.corrected
          File "src/fact.ml", line 5, characters 0-1:
          let rec fact n = if n = 1 then 1 else n * fact (n - 1)

          let%expect_test _ =
            print_int (fact 5);
          -  [%expect]
          +  [%expect{| 120 |}]

In order to accept the correction, simply run:

.. code:: bash

          $ dune promote

You can also make dune automatically accept the correction after
running the tests by typing:

.. code:: bash

          $ dune runtest --auto-promote

Finally, some editor integration is possible to make the editor do the
promotion and make the workflow even smoother.

Specifying inline test dependencies
-----------------------------------

If your tests are reading files, you must say it to dune by adding
a ``deps`` field the the ``inline_tests`` field. The argument of this
``deps`` field follows the usual :ref:`deps-field`. For instance:

.. code:: ocaml

          (library
           (name foo)
           (inline_tests (deps data.txt))
           (preprocess (pps ppx_expect)))

Passing special arguments to the test runner
--------------------------------------------

Under the hood, a test executable is built by dune. Depending on
the backend used this runner might take useful command line
arguments. You can specify such flags by using a ``flags`` field, such
as:

.. code:: ocaml

          (library
           (name foo)
           (inline_tests (flags (-foo bar)))
           (preprocess (pps ppx_expect)))

The argument of the ``flags`` field follows the :ref:`ordered-set-language`.

Using additional libraries in the test runner
---------------------------------------------

When tests are not part of the library code, it is possible that tests
require additional libraries than the library being tested. This is
the case with qtest_ as tests are written in comments. You can specify
such libraries using a ``libraries`` field, such as:

.. code:: ocaml

          (library
           (name foo)
           (inline_tests (backend qtest)
                         (libraries bar)))

Defining your own inline test backend
-------------------------------------

If you are writing a test framework, or for specific cases, you might
want to define your own inline tests backend. If your framework is
naturally implemented by a library or ppx rewriter that the user must
use when they want to write tests, then you should define this library
has a backend. Otherwise simply create an empty library with the name
you want to give for your backend.

In order to define a library as an inline tests backend, simply add an
``inline_tests.backend`` field to the library stanza. An inline tests
backend is specified by thee parameters:

1. How to create the test runner
2. How to build the test runner
3. How to run the test runner

These three parameters can be specified inside the
``inline_tests.backend`` field, which accepts the following fields:

.. code:: scheme

          (generate_runner   <action>)
          (runner_libraries (<ocaml-libraries>))
          (flags             <flags>)
          (extends          (<backends>))

For instance:

``<action>`` follows the :ref:`user-actions` specification. It
describe an action that should be executed in the directory of
libraries using this backend for their tests.  It is expected that the
action produces some OCaml code on its standard output. This code will
constitute the test runner. The action can use the following
additional variables:

- ``${library-name}`` which is the name of the library being tested
- ``${impl-files}`` which is the list of implementation files in the
  library, i.e. all the ``.ml`` and ``.re`` files
- ``${intf-files}`` which is the list of interface files in the library,
  i.e. all the ``.mli`` and ``.rei`` files

The ``runner_libraries`` field specifies what OCaml libraries the test
runner uses. For instance, if the ``generate_runner`` actions
generates something like ``My_test_framework.runtests ()``, the you
should probably put ``my_test_framework`` in the ``runner_libraries``
field.

If you test runner needs specific flags, you should pass them in the
``flags`` field. You can use the ``${library-name}`` variable in this
field.

Finally, a backend can be an extension of another backend. In this
case you must specify by in the ``extends`` field. For instance,
ppx_expect_ is an extension of ppx_inline_test_. It is possible to use
a backend with several extensions in a library, however there must be
exactly one *root backend*, i.e. exactly one backend that is not an
extension of another one.

When using a backend with extensions, the various fields are simply
concatenated. The order in which they are concatenated is unspecified,
however if a backend ``b`` extends of a backend ``a``, then ``a`` will
always come before ``b``.

Example of backend
~~~~~~~~~~~~~~~~~~

In this example, we put tests in comments of the form:

.. code:: ocaml

          (*TEST: assert (fact 5 = 120) *)

The backend for such a framework looks like this:

.. code:: scheme

          (library
           (name simple_tests)
           (inline_tests.backend
            (generate_runner (run sed "s/(\\*TEST:\\(.*\\)\\*)/let () = \\1;;/" %{impl-files}))
            ))

Now all you have to do is write ``(inline_tests ((backend
simple_tests)))`` wherever you want to write such tests. Note that
this is only an example, we do not recommend using ``sed`` in your
build as this would cause portability problems.

Custom tests
============

We said in `Running tests`_ that to run tests dune simply builds
the ``runtest`` alias. As a result, to define cutsom tests, you simply
need to add an action to this alias in any directory. For instance if
you have a binary ``tests.exe`` that you want to run as part of
running your testsuite, simply add this to a jbuild file:

.. code:: scheme

          (alias
           (name   runtest)
           (action (run ./tests.exe)))

Hence to define an a test a pair of alias and executable stanzas are required.
To simplify this common pattern, dune provides a :ref:`tests-stanza` stanza to
define multiple tests and their aliases at once:

.. code:: scheme

   (tests (names test1 test2))

Diffing the result
------------------

It is often the case that we want to compare the output of a test to
some expected one. For that, dune offers the ``diff`` command,
which in essence is the same as running the ``diff`` tool, except that
it is more integrated in dune and especially with the ``promote``
command. For instance let's consider this test:

.. code:: scheme

          (rule
           (with-stdout-to tests.output (run ./tests.exe)))

          (alias
           (name runtest)
           (action (diff tests.expected test.output)))

After having run ``tests.exe`` and dumping its output to ``tests.output``, dune
will compare the latter to ``tests.expected``. In case of mismatch, dune will
print a diff and then the ``dune promote`` command can be used to copy over the
generated ``test.output`` file to ``tests.expected`` in the source tree.

Alternatively, the :ref:`tests-stanza` also supports this style of tests.

.. code:: scheme

   (tests (names tests))

Where dune expects a ``tests.expected`` file to exist to infer that this is an
expect tests.

This provides a nice way of dealing with the usual *write code*,
*run*, *promote* cycle of testing. For instance:

.. code:: bash

          $ dune runtest
          [...]
          -tests.expected
          +tests.output
          File "tests.expected", line 1, characters 0-1:
          -Hello, world!
          +Good bye!
          $ dune promote
          Promoting _build/default/tests.output to tests.expected.

Note that if available, the diffing is done using the patdiff_ tool,
which displays nicer looking diffs that the standard ``diff``
tool. You can change that by passing ``--diff-command CMD`` to
dune.


.. _ppx_inline_test: https://github.com/janestreet/ppx_inline_test
.. _ppx_expect:      https://github.com/janestreet/ppx_expect
.. _qtest:           https://github.com/vincent-hugot/qtest
.. _patdiff:         https://github.com/janestreet/patdiff
