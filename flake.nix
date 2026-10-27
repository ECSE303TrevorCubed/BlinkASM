{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    { self, ... }@inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import inputs.nixpkgs { inherit system; };
        # Cross package set: builds 32-bit ARM (armv7l, hard-float) binaries
        # for the Raspberry Pi 3B from this machine's native toolchain.
        crossPkgs = pkgs.pkgsCross.armv7l-hf-multiplatform;
        treefmtconfig = inputs.treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs = {
            alejandra.enable = true;
            yamlfmt.enable = true;
            mdformat = {
              enable = true;
              plugins = ps: [
                ps.mdformat-gfm
              ];
              settings = {
                wrap = 88;
                end-of-line = "lf";
              };
            };
            nixfmt.enable = true;
            typstyle.enable = true;
          };
        };
        wiringpi' =
          let
            orig = pkgs.wiringpi;
            version = "3.20";
            src = pkgs.fetchFromGitHub {
              owner = "WiringPi";
              repo = "WiringPi";
              rev = "v${version}";
              hash = "sha256-9dOooR8XrhSfR+3g20HLy5kC5mnLHb1D+/uMlcqMPSk=";
            };
            mkSubProject =
              subprj: buildInputs:
              (orig.passthru.mkSubProject {
                inherit subprj src buildInputs;
              }).overrideAttrs
                (old: {
                  version = "3.20";
                  __intentionallyOverridingVersion = old.__intentionallyOverridingVersion or true;
                });
            wiringPi = mkSubProject "wiringPi" [ pkgs.libxcrypt ];
            devLib = mkSubProject "devLib" [ wiringPi ];
            wiringPiD = mkSubProject "wiringPiD" [
              pkgs.libxcrypt
              wiringPi
              devLib
            ];
            gpio = mkSubProject "gpio" [
              pkgs.libxcrypt
              wiringPi
              devLib
            ];
          in
          pkgs.symlinkJoin {
            pname = "wiringpi";
            inherit version;
            paths = [
              wiringPi
              devLib
              wiringPiD
              gpio
            ];
            passthru = {
              inherit src mkSubProject;
              inherit
                wiringPi
                devLib
                wiringPiD
                gpio
                ;
            };
            meta = orig.meta;
          };
      in
      {
        formatter = treefmtconfig.config.build.wrapper;
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            typst
            typstyle
            nil
            nixd
            # Cross assembler/linker for assembling the .s files by hand
            # (armv7l-unknown-linux-gnueabihf-gcc)
            crossPkgs.buildPackages.gcc
            wiringpi'
          ];
        };
        packages =
          let
            blink_apps = {
              blink_asm = crossPkgs.callPackage ./nix/blink.nix { };
              pwm_asm = crossPkgs.callPackage ./nix/pwm.nix { wiringPi = wiringpi'; };
            };
            blink_report = pkgs.callPackage ./nix/report.nix { };
            ci = pkgs.callPackage ./nix/ci.nix {
              apps = blink_apps;
              reports = blink_report;
            };
          in
          {
            default = blink_apps.blink_asm;
            inherit (blink_apps) blink_asm pwm_asm;
            blink_pwm = blink_apps.pwm_asm;
            inherit blink_report ci;
          };
        checks = {
          formatting = treefmtconfig.config.build.check self;
        };
      }
    );
}
