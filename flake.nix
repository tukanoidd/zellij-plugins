{
  description = "Zellij Plugins Collection";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    flake-utils.url = "github:numtide/flake-utils";

    zellij = {
      url = "github:zellij-org/zellij";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    zellij,
    rust-overlay,
    flake-utils,
    ...
  }: let
    src = zellij;
    cargoTOML = builtins.fromTOML (builtins.readFile (src + "/Cargo.toml"));
    inherit (cargoTOML.package) name;
  in
    # flake outputs
    flake-utils.lib.eachDefaultSystem
    (
      system: let
        overlays = [(import rust-overlay)];

        pkgs = import nixpkgs {
          inherit system overlays;
        };

        rustToolchainTOML = pkgs.rust-bin.fromRustupToolchainFile (src + /rust-toolchain.toml);
        rustWasmToolchainTOML = rustToolchainTOML.override {
          extensions = [];
          targets = ["wasm32-wasi"];
        };

        devInputs = with pkgs; [
          rustToolchainTOML
          binaryen
          mkdocs
          just
          protobuf
        ];

        fmtInputs = with pkgs; [
          alejandra 
          treefmt
        ];

        customPlugins = pkgs.callPackage ./plugins.nix {
          rustc = rustWasmToolchainTOML;
          cargo = rustWasmToolchainTOML;
        };
      in {
        packages = {
          inherit (customPlugins) monocle room;
        };

        devShells = {
          default = pkgs.mkShell {
            inherit name;
            nativeBuildInputs = devInputs;
            RUST_BACKTRACE = 1;
          };
          fmtShell = pkgs.mkShell {
            buildInputs = fmtInputs;
          };
          actionlintShell = pkgs.mkShell {
            buildInputs = [pkgs.actionlint];
          };
        };

        checks = {
          inherit (self.outputs.packages.${system}) monocle;
        };
        formatter = pkgs.alejandra;
      }
    );
}
