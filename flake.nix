{
  description = "fuzzing-xxd dev environment (flake)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  # Pull select toolchains (e.g. newer Zig/Go) from nixpkgs-unstable while keeping the base system on 24.05.
  inputs.unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs, unstable }: let
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          # Imported separately so we can cherry-pick bleeding-edge compilers without upgrading everything.
          unstablePkgs = import unstable { inherit system; };
        in f { inherit system pkgs unstablePkgs; });

    mkZzd = { pkgs, unstablePkgs }: pkgs.stdenv.mkDerivation {
      pname = "zzd";
      version = "0.0.0-8a281ef";

      src = pkgs.fetchFromGitHub {
        owner = "eapolinario";
        repo = "zzd";
        rev = "8a281efb6a2fd10a4f01f419395a348176f7e556";
        hash = "sha256-uS+Is/R7zvH6Riy3gEQdF7+zZwL0PHz4qDh2qaLqp24=";
      };

      nativeBuildInputs = [ unstablePkgs.zig ];
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

    mkGgd = { pkgs, unstablePkgs }: let
      buildGoModule = pkgs.buildGoModule.override { go = unstablePkgs.go; };
    in buildGoModule {
      pname = "ggd";
      version = "0.0.0-eda25b8";

      src = pkgs.fetchFromGitHub {
        owner = "eapolinario";
        repo = "ggd";
        rev = "eda25b832585cc33edde2d9468b66fc808a0cd5f";
        hash = "sha256-56JwKlO0b1jPJZ9nEPY/+qwPa0+sMhMw9qWNcbddd1E=";
      };

      vendorHash = "sha256-xIenFxYqheY67U/Eivmmicfwy/mGCkKMCdv9fR3OKoY=";
      subPackages = [ "cmd/ggd" ];

      meta = with pkgs.lib; {
        description = "Go implementation of xxd";
        homepage = "https://github.com/eapolinario/ggd";
        license = licenses.unlicense;
        mainProgram = "ggd";
      };
    };
  in {
    packages = forAllSystems ({ pkgs, unstablePkgs, system }: let
      zzd = mkZzd { inherit pkgs unstablePkgs; };
      ggd = mkGgd { inherit pkgs unstablePkgs; };
    in {
      default = zzd;
      inherit zzd ggd;
    });

    devShells = forAllSystems ({ pkgs, system, unstablePkgs }: {
      default = pkgs.mkShell {
        packages = [
          pkgs.radamsa
          self.packages.${system}.zzd
          self.packages.${system}.ggd
        ];
      };
    });
  };
}
