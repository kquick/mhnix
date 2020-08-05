{ mkDerivation, ansi-terminal, base, binary, blaze-builder
, bytestring, Cabal, containers, deepseq, directory, filepath
, hashable, HUnit, microlens, microlens-mtl, microlens-th, mtl
, parallel, parsec, QuickCheck, quickcheck-assertions, random
, smallcheck, stdenv, stm, string-qq, terminfo, test-framework
, test-framework-hunit, test-framework-smallcheck, text
, transformers, unix, utf8-string, vector
}:
mkDerivation {
  pname = "vty";
  version = "5.30";
  sha256 = "722add849aa620ca0f7fb8e5268a83c3b88ebea15aaf8612b0308d7b91ff4ab0";
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    ansi-terminal base binary blaze-builder bytestring containers
    deepseq directory filepath hashable microlens microlens-mtl
    microlens-th mtl parallel parsec stm terminfo text transformers
    unix utf8-string vector
  ];
  executableHaskellDepends = [
    base containers directory filepath microlens microlens-mtl mtl
  ];
  testHaskellDepends = [
    base blaze-builder bytestring Cabal containers deepseq HUnit
    microlens microlens-mtl mtl QuickCheck quickcheck-assertions random
    smallcheck stm string-qq terminfo test-framework
    test-framework-hunit test-framework-smallcheck text unix
    utf8-string vector
  ];
  homepage = "https://github.com/jtdaugherty/vty";
  description = "A simple terminal UI library";
  license = stdenv.lib.licenses.bsd3;
}
