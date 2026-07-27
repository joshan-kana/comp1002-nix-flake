{
  description = "COMP1002 practicals: Python 3, NumPy, tests, formatting and linting";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
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

        python = pkgs.python3.withPackages (
          ps: with ps; [
            mypy
            numpy
            pytest
            pytest-cov
          ]
        );

        treefmt = treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";

          programs = {
            nixfmt.enable = true;
            ruff-check.enable = true;
            ruff-format.enable = true;
            statix.enable = true;
            taplo.enable = true;
          };

          settings = {
            global.excludes = [ ".direnv/**" ];

            # Apply fixes before final formatting.
            formatter = {
              ruff-check.priority = 1;
              ruff-format.priority = 2;
              statix.priority = 1;
              nixfmt.priority = 2;
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
            if find . -name '*.py' -print -quit | grep -q .; then mypy .; else echo 'No Python files found; skipping mypy.'; fi
          '';
        };

        test = pkgs.writeShellApplication {
          name = "test";
          runtimeInputs = [ python ];
          text = ''pytest "$@" || { [ "$?" -eq 5 ] && echo 'No tests found; skipped.'; }'';
        };

        rn = pkgs.writeShellApplication {
          name = "rn";
          runtimeInputs = [ python ];
          text = ''exec python3 "$@"'';
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
            rn
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
