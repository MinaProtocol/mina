-- filepath: /home/darek/work/minaprotocol/mina/buildkite/src/Pipeline/TagTest.dhall
let Tag = ./Tag.dhall

let fastTag = Tag.Type.Fast

let longTag = Tag.Type.Long

let lintTag = Tag.Type.Lint

let testTag = Tag.Type.Test

let dockerTag = Tag.Type.Docker

let emptyTagList = [] : List Tag.Type

let testContainsAnyTrue =
      assert : Tag.containsAny [ fastTag ] [ fastTag, longTag ] === True

let testContainsAnyFalse =
      assert : Tag.containsAny [ testTag ] [ fastTag, longTag ] === False

let testContainsAnyMultipleTrue =
        assert
      : Tag.containsAny [ fastTag, testTag ] [ fastTag, longTag ] === True

let testContainsAnyMultipleFalse =
        assert
      : Tag.containsAny [ testTag, dockerTag ] [ fastTag, longTag ] === False

let testContainsAnyEmpty =
      assert : Tag.containsAny emptyTagList [ fastTag, longTag ] === False

let testContainsAnyAgainstEmpty =
      assert : Tag.containsAny [ fastTag ] emptyTagList === False

let testContainsAllTrue =
      assert : Tag.containsAll [ fastTag ] [ fastTag, longTag ] === True

let testContainsAllFalse =
        assert
      : Tag.containsAll [ fastTag, testTag ] [ fastTag, longTag ] === False

let testContainsAllMultipleTrue =
        assert
      :     Tag.containsAll [ fastTag, longTag ] [ fastTag, longTag, lintTag ]
        ===  True

let testContainsAllMultipleFalse =
        assert
      : Tag.containsAll [ fastTag, testTag ] [ fastTag, longTag ] === False

let testContainsAllEmpty =
      assert : Tag.containsAll emptyTagList [ fastTag, longTag ] === True

let testContainsAllAgainstEmpty =
      assert : Tag.containsAll [ fastTag ] emptyTagList === False

in  { testContainsAnyTrue = testContainsAnyTrue
    , testContainsAnyFalse = testContainsAnyFalse
    , testContainsAnyMultipleTrue = testContainsAnyMultipleTrue
    , testContainsAnyMultipleFalse = testContainsAnyMultipleFalse
    , testContainsAnyEmpty = testContainsAnyEmpty
    , testContainsAnyAgainstEmpty = testContainsAnyAgainstEmpty
    , testContainsAllTrue = testContainsAllTrue
    , testContainsAllFalse = testContainsAllFalse
    , testContainsAllMultipleTrue = testContainsAllMultipleTrue
    , testContainsAllMultipleFalse = testContainsAllMultipleFalse
    , testContainsAllEmpty = testContainsAllEmpty
    , testContainsAllAgainstEmpty = testContainsAllAgainstEmpty
    }
