# Migration from Inline Tests to Alcotest
 
 ## Process for migrating libraries in src/lib from inline tests to Alcotest:
 
 1. **Analyze existing inline tests** in the library
 2. **Create Alcotest test files** with proper test/tests stanza
 3. **Order dependencies alphabetically** in dune files
 4. **Minimize modifications** to non-test code (only expose methods if needed)
 5. **Give up if semantic changes** are required in non-test files
 6. **Run tests**: `dune runtest` in the test location
 7. **Format code**: `dune fmt --auto-promote` in the library directory
 8. **Create branch**: prefix with library name, suffix with "move-to-alcotest"
 9. **Create commit and PR**: always branch from compatible, target compatible
 
 ## Branch naming convention:
 `{library-name}-move-to-alcotest`
 
 ## Testing commands:
 - `dune runtest` (in test location)
 - `dune fmt --auto-promote` (in library directory)