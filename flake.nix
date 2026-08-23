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
      url = "github:cachix/pre-commit-hooks.nix";
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

        templateFiles = [
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

        python = pkgs.python3.withPackages (
          ps: with ps; [
            mypy
            numpy
            pytest
            pytest-cov
          ]
        );

        mkAlias =
          alias: package:
          pkgs.writeShellScriptBin alias ''
            exec ${pkgs.lib.getExe package} "$@"
          '';
        findPruneArgs = pkgs.lib.concatMapStringsSep " " (dir: "-path ./${dir} -prune -o") globalExcludes;
        markdownOptions = [
          "--disable"
          "MD013"
        ];

        treefmt = treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";

          programs = {
            deadnix.enable = true;
            nixfmt.enable = true;
            ruff-check.enable = true;
            ruff-format.enable = true;
            rumdl-check.enable = true;
            rumdl-format.enable = true;
            statix.enable = true;
            taplo.enable = true;
            typos.enable = true;
          };

          settings = {
            global.excludes = map (dir: "${dir}/**") globalExcludes;
            formatter = {
              ruff-check.priority = 1;
              ruff-format.priority = 2;
              statix.priority = 1;
              deadnix.priority = 2;
              nixfmt.priority = 3;
              rumdl-format = {
                options = markdownOptions;
                priority = 1;
              };
              rumdl-check = {
                options = markdownOptions;
                priority = 2;
              };
              typos = {
                includes = [ "*.md" ];
                priority = 3;
              };
            };
          };
        };

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

        check = pkgs.writeShellApplication {
          name = "check";
          runtimeInputs = [ pkgs.pre-commit ];
          text = ''exec pre-commit run nix-flake-check "$@"'';
        };

        sync = pkgs.writeShellApplication {
          name = "sync";
          runtimeInputs = [
            pkgs.git
            pkgs.rsync
          ];
          text = ''
            root="$(git rev-parse --show-toplevel)"
            rsync -rltp --chmod=u+w --delete-missing-args \
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
        devShells.default = pkgs.mkShell {
          packages = [
            python
            pkgs.nixd
            pkgs.nixfmt
            pkgs.ruff
            pkgs.statix
            (mkAlias "rn" python)
            (mkAlias "lt" lint)
            (mkAlias "tt" test)
            (mkAlias "fmt" treefmt.config.build.wrapper)
            (mkAlias "chk" check)
            treefmt.config.build.wrapper
          ];

          inherit
            (
              (pre-commit-hooks.lib.${system}.run {
                src = self;
                hooks = {
                  nix-flake-check = {
                    enable = true;
                    name = "nix flake check";
                    entry = "nix flake check";
                    language = "system";
                    pass_filenames = false;
                  };
                };
              })
            )
            shellHook
            ;

          # Prevent packages installed with `pip install --user` outside Nix
          # from silently leaking into this environment.
          PYTHONNOUSERSITE = "1";
        };

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
          formatting = treefmt.config.build.check self;
          lint = runCheck lint;
          tests = runCheck test;
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
