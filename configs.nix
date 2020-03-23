let default_ghcver = "ghc865";
in

{ nixpkgs ? <nixpkgs>
# ---- release arguments ----
, ghcver ? default_ghcver
, variant ? "master"
# ---- release inputs ----
, matterhorn-src ? null
, mattermost-api-src ? null
, mattermost-api-qc-src ? null
, aspell-pipe-src ? null
# ---- arguments for jobset mode ----
, hydra-jobsets ? false
, master-tree ? null
, develop-tree ? null
# ---- standard inputs ----
, system ? null
, pkgOverrides ? null
, hydraRun ? false
, freshHaskellHashes ? false
, devnix ? builtins.fetchTarball { url = https://api.github.com/repos/kquick/devnix/tarball; }
, pkgs ? import nixpkgs ((import devnix).defaultPkgArgs system pkgOverrides freshHaskellHashes)
, project ? null # unused, but needed to cause a rebuild on hydra if this repo changes.
}:

with (import devnix);

let

  master-srcs =
    params:   # input parameters like variant and ghcver
    let variant = params.variant or "master";
        variantParts = splitBy "\\|" variant;
        ghcver = params.ghcver or default_ghcver;
        branch = let bvp = assocEqListLookup "branch" variantParts;
                 in if bvp == null
                    then removeSuffix "-latest" variant
                    else bvp;
        github = githubsrc "matterhorn-chat";
    in
      {
        haskell-packages = {
          matterhorn = github "matterhorn" branch;
          mattermost-api = github "mattermost-api" branch;
          mattermost-api-qc = github "mattermost-api-qc" branch;
          aspell-pipe = github "aspell-pipe";
        }
        //
        ({ "ghc822" = {
             cereal = hackageVersion "0.5.8.0";
             skylighting-core = hackageVersion "0.7.6";  # 0.7.7 broken for GHC 8.2.2
           };
           "ghc844" = { cereal = hackageVersion "0.5.8.0"; };
           # ghc 8.6.x does not need a cereal override
           "ghc881" = {
             # The nix GHC 8.8 overrides with an undefined symbol for unordered-containers.
             unordered-containers = hackageVersion "0.2.10.0";
             # Newer microlens needed for monadfail changes.
             microlens = hackageVersion "0.4.11.2";
             # Newer microlens-ghc needed for newer microlens
             microlens-ghc = hackageVersion "0.4.11.1";
             # The cabal-doctest_1_0_7 was removed, but not the GHC 8.8 config reference.
             cabal-doctest = hackageVersion "1.0.7";
             # Newer version of microlens-th needed for new template-haskell compatibility
             microlens-th = hackageVersion "0.4.3.2";
             # Newer version to match microlens
             microlens-platform = hackageVersion "0.4.0";
             # Newer version to match microlens-platform
             microlens-mtl = hackageVersion "0.2.0.1";
             # Newer version of vty for microlens >= 0.4.11 compatibility
             # vty = hackageVersion "5.26";
             # vty = pkgs.callPackage ./vty-5.26.nix {};
           };
         }."${ghcver}" or {})
        //
        (if branch == "develop"
         then {
           # vty = hackageVersion "5.26";
           # vty = pkgs.callPackage ./vty-5.26.nix {};
         } else {});
      };


  jdefs = { inherit pkgs;
            addSrcs = master-srcs;
            parameters = {
              system = [ "x86_64-linux" ]; # "x86_64-darwin" ];
              ghcver = [ "ghc865" "ghc844" "ghc822" ];
            };
            project = gitProjectFromDecl ./mh-decl.json;
          };

  rdefs = { inherit pkgs hydraRun;
            srcs = {
              inherit matterhorn-src
                mattermost-api-src
                mattermost-api-qc-src
                aspell-pipe-src;
            };
            addSrcs = master-srcs;
            parameters = { inherit ghcver system variant; };
            overrides = {
              haskell-packages = params: self: super:
                with pkgs.haskell.lib;
                {
                  # mattermost-api tests try to run a sample server; disable
                  mattermost-api = dontCheck super.mattermost-api;

                  Diff = if builtins.elem ghcver ["ghc822" "ghc844"]
                         then dontCheck super.Diff  # incompatible with QuickCheck changes
                         else super.Diff;

                  aeson = dontCheck super.aeson; # QuickCheck version incompatibility
                  Unique = notBroken (dontCheck super.Unique);

                  # Time-compat v1.9.2.2 has test dependencies on
                  # base-compat >= 0.10.5 && <0.11, but the newest
                  # base-compat is 0.11.1, so it will fail to
                  # configure.  Disabling the tests avoids this
                  # conflict.  Should be fixed in time-compat 1.9.3.
                  time-compat =
                    let spl = builtins.splitVersion super.time-compat.version;
                        majA = builtins.head spl;
                        majB = builtins.elemAt spl 1;
                        minor = builtins.elemAt spl 2;
                        broken = majA == "1" &&
                                 (majB < "9" ||  # this works for single digits
                                  (majB == "9" && minor <= "2"));
                    in if broken
                       then dontCheck super.time-compat
                       else super.time-compat;

                } //
                (if ghcver == "ghc844"
                 then {
                   hspec = dontCheck super.hspec; # needs QuickCheck == 2.12.*
                   hspec-expectations = dontCheck super.hspec-expectations;
                   hspec-discover = dontCheck super.hspec-discover;
                   hspec-core = dontCheck super.hspec-core;
                   hspec-meta = dontCheck super.hspec-meta;
                   hspec-tdfa = dontCheck super.hspec-tdfa;
                 } else
                   (if ghcver == "ghc881"
                    then {
                      # The http-media base upper-bound was revised on
                      # Hackage to allow GHC 8.8, but nix doesn't see
                      # these revisions, so jailbreak to achieve the
                      # same result.
                      http-media = doJailbreak super.http-media;
                      vty = self.callPackage ./vty-5.26.nix {};
                    } else {})
                ) //
                (let variant = params.variant or "master"; in
                 if (variant == "develop" ||
                     variant == "develop-latest" ||
                     builtins.elem "branch=develop" (splitBy "\\|" variant))
                 then {
                   # brick = self.callPackage ./brick_0_52.nix {};
                   vty = self.callPackage ./vty-5.28.nix {};
                 } else {
                   # Merged develop to master on 2019 Sep 13, so
                   # dependencies are the same.
                   # brick = self.callPackage ./brick_0_52.nix {};
                   vty = self.callPackage ./vty-5.28.nix {};
                 })
              ;
            };
          };

  jobsets =
  {
    jobsets = mkJobsetsDrv pkgs
    [
      (mkJobset (jdefs // { variant = "master-latest";  }))
      (mkJobset (jdefs // { variant = "develop-latest";  }))
      (enableEmail (mkJobset (jdefs // { variant = "master";  gitTree = master-tree; })))
      (enableEmail (mkJobset (jdefs // { variant = "develop"; gitTree = develop-tree; })))
    ];
  };

  packagesets = {
    master = mkRelease (rdefs // { gitTree = master-tree; });
    master-latest = mkRelease rdefs;
    develop = mkRelease (rdefs // { gitTree = develop-tree; });
    develop-latest = mkRelease rdefs;
  };

in if hydra-jobsets then jobsets else packagesets."${variant}" or packagesets.master-latest
