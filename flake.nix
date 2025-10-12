{
  description = "PayMintRails";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";

    crane.url = "github:ipetkov/crane";

    flake-utils.url = "github:numtide/flake-utils";

    advisory-db.url = "github:rustsec/advisory-db";
    advisory-db.flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      fenix,
      crane,
      flake-utils,
      advisory-db,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        overlays = [
          (final: prev: {
            cargo-llvm-cov = prev.callPackage ./.cargo/cargo-llvm-cov.nix { };
          })
        ];

        pkgs = import nixpkgs {
          inherit system overlays;
        };

        unstable = nixpkgs-unstable.legacyPackages.${system};

        inherit (pkgs) lib;

        # Use the same toolchain as rust-toolchain.toml
        toolchain = fenix.packages.${system}.fromToolchainFile {
          file = ./rust-toolchain.toml;
          sha256 = "sha256-SJwZ8g0zF2WrKDVmHrVG3pD2RGoQeo24MEXnNx5FyuI=";
        };

        # craneLib, but with our toolchain overridden to the fenix toolchain
        craneLib = (crane.mkLib pkgs).overrideToolchain (p: toolchain);

        # Source filtering so Cargo/Crane only sees relevant files
        src = craneLib.cleanCargoSource ./.;

        # Common arguments can be set here to avoid repeating them later
        commonArgs = {
          inherit src;
          strictDeps = true;

          buildInputs = [
            # Add additional build inputs here
          ]
          ++ lib.optionals pkgs.stdenv.isDarwin [
            # Additional darwin specific inputs can be set here
            pkgs.libiconv
          ];

          # Additional environment variables can be set directly
          # MY_CUSTOM_VAR = "some value";
        };

        # Build *just* the cargo dependencies, so we can reuse
        # all of that work (e.g. via cachix) when running in CI
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        individualCrateArgs = commonArgs // {
          inherit cargoArtifacts;
          inherit (craneLib.crateNameFromCargoToml { inherit src; }) version;
          # disable tests since we'll run them all via cargo-nextest
          doCheck = false;
        };

        fileSetForCrate =
          crate:
          lib.fileset.toSource {
            root = ./.;
            fileset = lib.fileset.unions [
              ./Cargo.toml
              ./Cargo.lock
              (craneLib.fileset.commonCargoSources ./crates/core)
              (craneLib.fileset.commonCargoSources crate)
            ];
          };

        # Build the top-level crates of the workspace as individual derivations.
        # This allows consumers to only depend on (and build) only what they need.
        paymintd = craneLib.buildPackage (
          individualCrateArgs
          // {
            pname = "paymintd";
            cargoExtraArgs = "-p paymint-server --locked";
            src = fileSetForCrate ./crates/server;
          }
        );
        paymintctl = craneLib.buildPackage (
          individualCrateArgs
          // {
            pname = "paymintctl";
            cargoExtraArgs = "-p paymint-cli --locked";
            src = fileSetForCrate ./crates/cli;
          }
        );
      in
      {
        checks = {
          # Build the crates as part of `nix flake check` for convenience
          inherit paymintd paymintctl;

          # Run clippy (and deny all warnings) on the crate source,
          # again, reusing the dependency artifacts from above.
          #
          # Note that this is done as a separate derivation so that
          # we can block the CI if there are issues here, but not
          # prevent downstream consumers from building our crate by itself.
          workspace-clippy = craneLib.cargoClippy (
            commonArgs
            // {
              inherit cargoArtifacts;
              cargoClippyExtraArgs = "--all-targets -- --deny warnings";
            }
          );

          workspace-doc = craneLib.cargoDoc (
            commonArgs
            // {
              inherit cargoArtifacts;
              # This can be commented out or tweaked as necessary, e.g. set to
              # `--deny rustdoc::broken-intra-doc-links` to only enforce that lint
              env.RUSTDOCFLAGS = "--deny warnings";
            }
          );

          # Check formatting
          workspace-fmt = craneLib.cargoFmt {
            inherit src;
          };

          workspace-toml-fmt = craneLib.taploFmt {
            src = pkgs.lib.sources.sourceFilesBySuffices src [ ".toml" ];
            # taplo arguments can be further customized below as needed
            # taploExtraArgs = "--config ./taplo.toml";
          };

          # Audit dependencies
          workspace-audit = craneLib.cargoAudit {
            inherit src advisory-db;
          };

          # Audit licenses
          workspace-deny = craneLib.cargoDeny {
            inherit src;
          };

          # Run tests with cargo-nextest
          # Consider setting `doCheck = false` on other crate derivations
          # if you do not want the tests to run twice
          workspace-nextest = craneLib.cargoNextest (
            commonArgs
            // {
              inherit cargoArtifacts;
              partitions = 1;
              partitionType = "count";
              cargoNextestPartitionsExtraArgs = "--no-tests=pass";
            }
          );
        };

        packages = {
          inherit paymintd paymintctl;
        };

        apps = {
          paymintd =
            (flake-utils.lib.mkApp {
              drv = paymintd;
            })
            // {
              meta = {
                description = "PayMintRails server binary";
              };
            };
          paymintctl =
            (flake-utils.lib.mkApp {
              drv = paymintctl;
            })
            // {
              meta = {
                description = "PayMintRails CLI client";
              };
            };
        };

        # Formatter used by `nix fmt`
        formatter = pkgs.nixfmt-rfc-style;

        devShells.default = craneLib.devShell {
          # Inherit inputs from checks.
          checks = self.checks.${system};

          # Additional dev-shell environment variables can be set directly
          # MY_CUSTOM_DEVELOPMENT_VAR = "something else";

          # Extra interactive-only tools; cargo and rustc are provided by default.
          packages = with pkgs; [
            sccache

            # Nightly rust-analyzer, llvm-tools-preview, and rustfmt
            fenix.packages.${system}.rust-analyzer
            fenix.packages.${system}.latest.llvm-tools-preview
            fenix.packages.${system}.latest.rustfmt

            # From nixpkgs-unstable
            unstable.gh
            unstable.git-cliff
            unstable.just
            unstable.typos
          ];

          # Caching: use sccache automatically
          RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
          SCCACHE_CACHE_SIZE = "10G";
          CARGO_INCREMENTAL = "true";

          # Ensure nightly rustfmt from fenix takes precedence on PATH
          shellHook = ''
            export PATH=${fenix.packages.${system}.latest.rustfmt}/bin:$PATH
          '';
        };
      }
    );
}
