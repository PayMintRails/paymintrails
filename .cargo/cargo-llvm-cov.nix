{
  stdenv,
  lib,
  fetchFromGitHub,
  rustPlatform,
  llvmPackages_19,
  gitMinimal,
}:

let
  pname = "cargo-llvm-cov";
  version = "0.6.21";

  owner = "taiki-e";
  homepage = "https://github.com/${owner}/${pname}";

  inherit (llvmPackages_19) llvm;
in

rustPlatform.buildRustPackage (finalAttrs: {
  inherit pname version;

  # Use `fetchFromGitHub` instead of `fetchCrate` because the latter does not
  # pull in fixtures needed for the test suite
  src = fetchFromGitHub {
    inherit owner;
    repo = "cargo-llvm-cov";
    rev = "v${version}";
    sha256 = "sha256-aQy9fWIdgyay9HDNxzes67pO/L2RQI5l5OWf4OV5wjY=";
  };

  # Upstream doesn't include the lockfile so we need to add it back
  postPatch = ''
    ln -s ${./Cargo.lock} Cargo.lock
  '';

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "test-helper-0.0.0" = "sha256-MjylM9agdGIGMp1Iip/jolHCzErST2XiEl5PIqt+ykg=";
    };
  };

  # `cargo-llvm-cov` reads these environment variables to find these binaries,
  # which are needed to run the tests
  LLVM_COV = "${llvm}/bin/llvm-cov";
  LLVM_PROFDATA = "${llvm}/bin/llvm-profdata";

  nativeCheckInputs = [
    gitMinimal
  ];

  doCheck = !stdenv.isDarwin;

  # `cargo-llvm-cov` tests rely on `git ls-files.
  preCheck = ''
    git init -b main
    git add .
  '';

  meta = {
    inherit homepage;
    changelog = homepage + "/blob/v${version}/CHANGELOG.md";
    description = "Cargo subcommand to easily use LLVM source-based code coverage";
    mainProgram = "cargo-llvm-cov";
    longDescription = ''
      In order for this to work, you either need to run `rustup component add llvm-
      tools-preview` or install the `llvm-tools-preview` component using your Nix
      library (e.g. fenix or rust-overlay)
    '';
    license = with lib.licenses; [
      asl20 # or
      mit
    ];
    maintainers = with lib.maintainers; [
      wucke13
      matthiasbeyer
      CobaltCause
    ];
  };
})
