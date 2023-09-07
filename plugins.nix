{
  pkgs,
  rustc,
  cargo,
  protobuf,
  stdenv,
  binaryen,
  optimize ? true,
}: let
  makePlugin = {name, url, rev}:
  let
    pluginSrc = builtins.fetchGit {
      inherit url rev;

      name = "zp_${name}";
    };
    cargoLock = {
      lockFile = builtins.path {
        path = pluginSrc + "/Cargo.lock";
        name = "Cargo.lock";
      };
      allowBuiltinFetchGit = true;
    };
  in
    (pkgs.makeRustPlatform {inherit cargo rustc;}).buildRustPackage {
      inherit cargoLock name stdenv;
      
      src = pluginSrc;
      
      nativeBuildInputs = [binaryen protobuf];
      buildPhase = ''
        cargo build --package ${name} --release --target=wasm32-wasi
        mkdir -p $out/bin;
      '';
      installPhase =
        if optimize
        then ''
          wasm-opt \
          -Oz target/wasm32-wasi/release/${name}.wasm \
          -o $out/bin/${name}.wasm \
          --enable-bulk-memory
        ''
        else ''
          mv \
          target/wasm32-wasi/release/${name}.wasm \
          $out/bin/${name}.wasm
        '';
      doCheck = false;
    };
in {
  room = makePlugin {
    name = "room";
    url = "https://github.com/rvcas/room";
    rev = "d9de88466354e4d7898b8ae5e6497c8266366524";
  };
}
