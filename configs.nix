{ nixpkgs ? <nixpkgs>
# ---- release arguments ----
, ghcver ? "ghc863"
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
, freshHaskellHashes ? false
, devnix ? builtins.fetchTarball { url = https://api.github.com/repos/kquick/devnix/tarball; }
, pkgs ? (import devnix).defaultPkgs nixpkgs system pkgOverrides freshHaskellHashes
, project ? null # unused, but needed to cause a rebuild on hydra if this repo changes.
}:

with (import devnix);

let

  master-srcs = params:
                  let variant = params.variant or "master";
                      ghcver = params.ghcver or "ghc864";
                      branch = replacePrefix "latest-" "" variant;
                      githubsrc = r: { type = "github";
                                       team = "matterhorn-chat";
                                       repo = r;
                                       ref = "master";
                                       __functor = self: r: self // { ref = r; };
                                     };
                      hackageVersion = v: { type = "hackageVersion"; version = v; };
                  in
                  {
                  haskell-packages = {
                    matterhorn = githubsrc "matterhorn" branch;
                    mattermost-api = githubsrc "mattermost-api" branch;
                    mattermost-api-qc = githubsrc "mattermost-api-qc" branch;
                    aeson = hackageVersion "1.4.2.0";
                  }
                  //
                  (let develop =
                       {
                         brick = hackageVersion "0.47";
                         freshHaskellHashes = true;  # for brick 0.47
                       };
                   in {
                        "develop" = develop;
                        "latest-develop" = develop;
                      }."${variant}" or {})
                  //
                  ({ "ghc822" = { cereal = hackageVersion "0.5.8.0"; };
                     "ghc844" = { cereal = hackageVersion "0.5.8.0"; };
                     # ghc 8.6.x does not need a cereal override
                   }."${ghcver}" or {});
                  };


  jdefs = { inherit pkgs;
            addSrcs = master-srcs;
            parameters = {
                           system = [ "x86_64-linux" "x86_64-darwin" ];
                           ghcver = [ "ghc864" "ghc844" "ghc822" ];
                         };
            project = gitProject "https://github.com/kquick/mhnix" //
                      {
                        entrypoint = "./configs.nix";
                        extraReleaseInputs = {
                          master-tree = {
                            type = "gittree";
                            value = "git@semmc-github:GaloisInc/semmc master";
                            emailresponsible = false;
                          };
                          develop-tree = {
                            type = "gittree";
                            value = "https://github.com/matterhorn-chat/matterhorn develop";
                            emailresponsible = false;
                          };
                        };
                      };
          };

  rdefs = { inherit pkgs;
            srcs = { inherit matterhorn-src
                             mattermost-api-src
                             mattermost-api-qc-src
                             aspell-pipe-src; };
            addSrcs = master-srcs;
            parameters = { inherit ghcver system variant; };
          };

  jobsets = {
    jobsets = mkJobsetsDrv pkgs
      (map mkJobset
      [
      (jdefs // { variant = "latest-master";  })
      (jdefs // { variant = "latest-develop"; })
      (jdefs // { variant = "master";  gitTree = master-tree;  })
      (jdefs // { variant = "develop"; gitTree = develop-tree; })
      ]);
  };

  packagesets = {
    master = mkRelease (rdefs // { gitTree = master-tree; });
    latest-master = mkRelease rdefs;
    develop = mkRelease (rdefs // { gitTree = develop-tree; });
    latest-develop = mkRelease rdefs;
  };

in if hydra-jobsets then jobsets else packagesets."${variant}"
