{
  description = "COMP1002 practicals: Python 3, NumPy, tests, formatting and linting";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      treefmt-nix,
      pre-commit-hooks,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib;
        overrides = import ./overrides.nix { inherit lib pkgs; };

        rootMarkerFile = ".comp1002-practical";

        templateFiles = [
          rootMarkerFile
          ".envrc"
          ".gitignore"
          ".vscode/extensions.json"
          ".vscode/launch.json"
          ".vscode/settings.json"
          ".vscode/tasks.json"
          "flake.lock"
          "flake.nix"
          "pyproject.toml"
        ];

        globalExcludes = [
          ".direnv"
          "unit_materials"
        ];

        mkAlias =
          alias: package:
          pkgs.writeShellScriptBin alias ''
            exec ${pkgs.lib.getExe package} "$@"
          '';
        findPruneArgs = pkgs.lib.concatMapStringsSep " " (dir: "-path ./${dir} -prune -o") globalExcludes;
        gitPathspecExcludeArgs = lib.concatMapStringsSep " " (
          dir: lib.escapeShellArg ":(exclude)${dir}/**"
        ) globalExcludes;
        markdownOptions = [
          "--disable"
          "MD013"
        ];

        baseConfig = final: {
          pythonPackages =
            ps: with ps; [
              mypy
              numpy
              pytest
              pytest-cov
            ];

          treefmtConfig = {
            projectRootFile = "flake.nix";

            programs = {
              deadnix.enable = true;
              nixfmt.enable = true;
              prettier = {
                enable = true;
                excludes = [ "*.md" ];
              };
              ruff-check.enable = true;
              ruff-format.enable = true;
              rumdl-check.enable = true;
              rumdl-format.enable = true;
              shellcheck = {
                enable = true;
                includes = [
                  ".envrc"
                  "**/*.sh"
                ];
              };
              statix.enable = true;
              taplo.enable = true;
              typos.enable = true;
            };

            settings = {
              excludes = map (dir: "${dir}/**") globalExcludes;
              formatter = {
                ruff-format.priority = 1;
                statix.priority = 1;
                nixfmt.priority = 2;
                rumdl-format.options = markdownOptions;
                rumdl-check = {
                  options = markdownOptions;
                  priority = 2;
                };
                shellcheck.options = [
                  "-s"
                  "bash"
                ];
                typos = {
                  includes = [ "*.md" ];
                  priority = 1;
                };
              };
            };
          };

          devShellConfig = {
            packages = [
              final.python
              pkgs.nixd
              pkgs.nixfmt
              pkgs.ruff
              pkgs.statix
              (mkAlias "rn" final.python)
              (mkAlias "lt" lint)
              (mkAlias "tt" test)
              (mkAlias "fmt" final.treefmt.config.build.wrapper)
              (mkAlias "chk" check)
              final.treefmt.config.build.wrapper
            ];

            inherit
              (
                (pre-commit-hooks.lib.${system}.run {
                  src = self;
                  hooks = {
                    repo-quality = {
                      enable = true;
                      name = "Repository formatting and linting";
                      entry = "nix build --no-link .#checks.${system}.repo-quality";
                      files = "\\.(json|lock|md|nix|py|sh|toml)$|^\\.envrc$";
                      excludes = map (dir: "^${lib.escapeRegex dir}/") globalExcludes;
                      pass_filenames = false;
                    };

                    staged-whitespace = {
                      enable = true;
                      name = "Staged whitespace";
                      entry = "${pkgs.lib.getExe pkgs.git} diff --check --cached -- . ${gitPathspecExcludeArgs}";
                      pass_filenames = false;
                      always_run = true;
                    };
                  };
                })
              )
              shellHook
              ;

            PYTHONNOUSERSITE = "1";
          };

          python = pkgs.python3.withPackages final.pythonPackages;
          treefmt = treefmt-nix.lib.evalModule pkgs final.treefmtConfig;
        };

        config = (lib.makeExtensible baseConfig).extend overrides;
        inherit (config) python treefmt;

        lint = pkgs.writeShellApplication {
          name = "lint";
          runtimeInputs = [
            pkgs.ruff
            pkgs.statix
            python
          ];
          text = ''
            ruff check .
            statix check flake.nix
            if find . ${findPruneArgs} -name '*.py' -print -quit | grep -q .; then mypy .; else echo 'No Python files found; skipping mypy.'; fi
          '';
        };

        test = pkgs.writeShellApplication {
          name = "test";
          runtimeInputs = [ python ];
          text = ''pytest "$@" || { [ "$?" -eq 5 ] && echo 'No tests found; skipped.'; }'';
        };

        check = pkgs.writeShellScriptBin "check" ''
          exec nix flake check "$@"
        '';

        sync = pkgs.writeShellApplication {
          name = "sync";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.rsync
          ];
          text = ''
            root="$(pwd -P)"

            while [[ "$root" != "/" && ! -f "$root/${rootMarkerFile}" ]]; do
              root="$(dirname "$root")"
            done

            if [[ ! -f "$root/${rootMarkerFile}" ]]; then
              echo "error: could not find template root (${rootMarkerFile})" >&2
              exit 1
            fi

            rsync -rlpc --chmod=u+w \
              --files-from=${pkgs.writeText "template-files" (pkgs.lib.concatStringsSep "\n" templateFiles)} \
              ${self.outPath}/ "$root/"
          '';
        };

        runCheck =
          pkg:
          pkgs.runCommand "comp1002-${pkg.name}-check" { nativeBuildInputs = [ pkg ]; } ''
            cp -R ${self} source
            chmod -R u+w source
            cd source
            ${pkg}/bin/${pkg.name}
            touch "$out"
          '';

      in
      {
        devShells.default = pkgs.mkShell config.devShellConfig;

        formatter = treefmt.config.build.wrapper;

        # `nix run .#name` can run these packages directly
        packages = {
          inherit
            lint
            test
            check
            sync
            ;
          default = lint;
        };

        checks = {
          repo-quality = treefmt.config.build.check self;
          formatting = treefmt.config.build.check self;
          lint = runCheck lint;
          tests = runCheck test;
          inherit sync;
        };
      }
    )
    // {
      templates.default = {
        path = ./.;
        description = "COMP1002 practical: Python + NumPy + pytest + formatters";
      };
    };
}
