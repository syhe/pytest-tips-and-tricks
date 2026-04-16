{
  description = "Pytest Tips & Tricks";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.systems.url = "github:nix-systems/default";
  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
    inputs.systems.follows = "systems";
  };
  inputs.git-hooks = {
    url = "github:cachix/git-hooks.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      git-hooks,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        hooks_package = pkgs.pre-commit;
        python_package = pkgs.python314;
        packages =
          with pkgs;
          [
            uv
          ]
          ++ lib.optionals (hooks_package == pkgs.prek) [
            # Wrapper to make pre-commit accessible when using prek
            (writeShellScriptBin "_pre-commit" ''
              exec ${lib.getExe pkgs.pre-commit} "$@"
            '')
          ];
        default_libraries = with pkgs; [
          ## Common Defaults
          stdenv.cc.cc
          zlib
          # zstd
          # curl
          # openssl
          # libssh
          # bzip2
          # libxml2
          # libsodium
          # util-linux
          # xz
        ];
        python_libraries = [ python_package ];
        libraries = default_libraries ++ python_libraries;
        pythonldlibpath = pkgs.lib.makeLibraryPath libraries;
        # Darwin requires a different library path prefix
        wrapPrefix = if (!pkgs.stdenv.isDarwin) then "LD_LIBRARY_PATH" else "DYLD_LIBRARY_PATH";
        patchedpython = (
          pkgs.symlinkJoin {
            name = "python";
            paths = [ python_package ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram "$out/bin/python3.14" --prefix ${wrapPrefix} : "${pythonldlibpath}"
            '';
          }
        );
      in
      {
        checks = {
          git-hooks = git-hooks.lib.${system}.run {
            src = ./.;
            configPath = ".nix-pre-commit-config.yaml";
            package = hooks_package;
            default_stages = [
              "pre-commit"
              "pre-push"
            ];
            hooks = {
              check-merge-conflicts.enable = true;
              check-case-conflicts.enable = true;
              mixed-line-endings.enable = true;
              trim-trailing-whitespace.enable = true;
              check-executables-have-shebangs.enable = true;
              check-shebang-scripts-are-executable.enable = true;
              editorconfig-checker.enable = true;
              commitizen.enable = true;
              nixfmt.enable = true;
              shellcheck.enable = true;
              shfmt = {
                enable = true;
                # Make sure shfmt is reading the .editorconfig file by not including any parser or printer flags
                entry = "${pkgs.shfmt}/bin/shfmt -l -w";
              };
              markdownlint = {
                enable = true;
                settings.configuration = {
                  "MD013" = false;
                };
              };
              actionlint.enable = true;
              check-yaml.enable = true;
              ruff.enable = true;
              ruff-format.enable = true;
              pyright.enable = true;
              uv-lock.enable = true;
              zizmor.enable = true;
              python-debug-statements.enable = true;
            };
          };
        };

        devShells =
          let
            mkShell = nixpkgs.legacyPackages.${system}.mkShell;
            inherit (self.checks.${system}.git-hooks) shellHook enabledPackages;
            lib_path = pkgs.lib.makeLibraryPath (libraries ++ packages ++ enabledPackages);
            commonShellAttributes = {
              inherit (self.checks.${system}.git-hooks) shellHook;
              packages = packages ++ [
                patchedpython
              ];
              buildInputs = enabledPackages;
              LD_LIBRARY_PATH = lib_path;
              DYLD_LIBRARY_PATH = lib_path;
            };
          in
          {
            default = mkShell commonShellAttributes;
            ci = mkShell (
              commonShellAttributes
              // {
                # Skip these checks in CI
                # pyright doesn't work without the installed dependencies
                SKIP = "pyright";
              }
            );
          };

        formatter = pkgs.nixfmt;
      }
    );
}
