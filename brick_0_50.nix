{ mkDerivation, base, bytestring, config-ini, containers
, contravariant, data-clist, deepseq, directory, dlist, filepath
, microlens, microlens-mtl, microlens-th, QuickCheck, stdenv, stm
, template-haskell, text, text-zipper, transformers, unix, vector
, vty, word-wrap
}:
mkDerivation {
  pname = "brick";
  version = "0.50";
  sha256 = "c9ef6555f5d2a086d4f322b53481482d1d416b8592d0e2c7465beefb81204c3c";
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    base bytestring config-ini containers contravariant data-clist
    deepseq directory dlist filepath microlens microlens-mtl
    microlens-th stm template-haskell text text-zipper transformers
    unix vector vty word-wrap
  ];
  testHaskellDepends = [
    base containers microlens QuickCheck vector
  ];
  homepage = "https://github.com/jtdaugherty/brick/";
  description = "A declarative terminal user interface library";
  license = stdenv.lib.licenses.bsd3;
}
