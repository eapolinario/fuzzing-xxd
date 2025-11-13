{
  description = "fuzzing-xxd dev environment (flake)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.zigpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs, zigpkgs }: let
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          zigPkgs = import zigpkgs { inherit system; };
        in f { inherit system pkgs zigPkgs; });

    mkZzd = { pkgs, zigPkgs }: pkgs.stdenv.mkDerivation {
      pname = "zzd";
      version = "0.0.0-8a281ef";

      src = pkgs.fetchFromGitHub {
        owner = "eapolinario";
        repo = "zzd";
        rev = "8a281efb6a2fd10a4f01f419395a348176f7e556";
        hash = "sha256-uS+Is/R7zvH6Riy3gEQdF7+zZwL0PHz4qDh2qaLqp24=";
      };

      nativeBuildInputs = [ zigPkgs.zig ];
      dontConfigure = true;

      buildPhase = ''
        runHook preBuild
        export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
        export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-cache"
        zig build -Doptimize=ReleaseSafe
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
        export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-cache"
        zig build install -Doptimize=ReleaseSafe --prefix "$out"
        ln -s eapolinario_zzd "$out/bin/zzd"
        runHook postInstall
      '';

      meta = with pkgs.lib; {
        description = "Zig implementation of xxd";
        homepage = "https://github.com/eapolinario/zzd";
        license = licenses.unlicense;
        platforms = platforms.unix;
        mainProgram = "zzd";
      };
    };
  in {
    packages = forAllSystems ({ pkgs, zigPkgs, system }: let
      zzd = mkZzd { inherit pkgs zigPkgs; };
    in {
      default = zzd;
      inherit zzd;
    });

    devShells = forAllSystems ({ pkgs, system, zigPkgs }: {
      default = pkgs.mkShell {
        packages = [
          pkgs.radamsa
          self.packages.${system}.zzd
        ];
      };
    });
  };
}
