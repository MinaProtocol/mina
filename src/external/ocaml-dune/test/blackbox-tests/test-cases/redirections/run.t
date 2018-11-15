  $ dune runtest --display short 2>&1 | sed "s/ cmd /  sh /"
            sh stderr,stdout
            sh stderr,stdout
          diff alias runtest
            sh both
            sh both
          diff alias runtest
          diff alias runtest
