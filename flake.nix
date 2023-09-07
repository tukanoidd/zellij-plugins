{
  description = "Zellij Plugins Collection";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zellij = {
      url = "github:zellij-org/zellij";
      flake = false;
    };
    zfzf = {
      url = "github:tukanoidd/zfzf";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        rust-overlay.follows = "rust-overlay";
        zellij.follows = "zellij";
      };
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    rust-overlay,
    zellij,
    zfzf,
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

          zfzf = zfzf.packages.${pkgs.system}.default;
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
          inherit (self.outputs.packages.${system}) monocle room zfzf;
        };
        formatter = pkgs.alejandra;
      }
    );
}
