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
        ghcver = params.ghcver or default_ghcver;
        branch = removeSuffix "-latest" variant;
        github = githubsrc "matterhorn-chat";
    in
      {
        haskell-packages = {
          matterhorn = github "matterhorn" branch;
          mattermost-api = github "mattermost-api" branch;
          mattermost-api-qc = github "mattermost-api-qc" branch;
          aspell-pipe = github "aspell-pipe";
          aeson = hackageVersion "1.4.2.0";
          th-abstraction = hackageVersion "0.2.11.0";
        }
        //
        (let develop =
               {
                 brick = hackageVersion "0.47";
                 freshHaskellHashes = true;  # for brick 0.47
               };
             master = develop;
         in {
           "develop" = develop;
           "develop-latest" = develop;
           "master" = master;
           "master-latest" = master;
         }."${variant}" or {})
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
           };
         }."${ghcver}" or {});
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

                } //
                (if ghcver == "ghc844"
                 then {
                   hspec = dontCheck super.hspec; # needs QuickCheck == 2.12.*
                   hspec-expectations = dontCheck super.hspec-expectations;
                   hspec-discover = dontCheck super.hspec-discover;
                   hspec-core = dontCheck super.hspec-core;
                   hspec-meta = dontCheck super.hspec-meta;
                   hspec-tdfa = dontCheck super.hspec-tdfa;
                 } else {}
                );
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

in if hydra-jobsets then jobsets else packagesets."${variant}"
