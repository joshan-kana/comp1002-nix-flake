# COMP1002 practicals development environment

Nix flake for COMP1002 practicals.

## Setup

Create a practical directory from the template:

```bash
nix flake init -t 'git+ssh://git@github.com/joshan-kana/comp1002-nix-flake.git' --refresh
direnv allow
```

Optionally, set up a Git repository:

```bash
git init
git add .
git commit -m "initialised"
```

After that, entering the directory activates the development environment automatically.

## Update

Update an existing practical from the latest template.

Practicals created before the marker and per-practical config were added
need both files created once from the practical root:

```bash
touch .comp1002-practical
printf '_: _final: _prev:\n{ }\n' > overrides.nix
git add overrides.nix
```

Then update with:

```bash
nix run 'git+ssh://git@github.com/joshan-kana/comp1002-nix-flake.git#sync' --refresh
direnv allow
```

Without direnv:

```bash
nix develop -c $SHELL
```

## Per-practical configuration

New practicals include `overrides.nix`. It is deliberately not updated by
`sync`, so each practical can keep its own environment overrides. Older
practicals create the no-op overlay once using the command in **Update** above.

`overrides.nix` is a normal Nix overlay: `prev` is the shared template
configuration and `final` is the configuration after overrides. For example:

```nix
{ lib, pkgs }:
_final: prev: {
  pythonPackages = ps: prev.pythonPackages ps ++ [ ps.pandas ];

  treefmtConfig = lib.recursiveUpdate prev.treefmtConfig {
    programs.taplo.enable = false;
  };

  devShellConfig = prev.devShellConfig // {
    packages = prev.devShellConfig.packages ++ [ pkgs.graphviz ];
  };
}
```

## Python

The environment includes Python 3, NumPy, Ruff, mypy, pytest and pytest-cov.
VS Code support includes Python language features, debugging, tests, Ruff formatting
and linting, and mypy type checking.

Useful commands inside the development environment:

```bash
rn example.py  # run a Python file
lt             # Ruff, Statix and mypy
tt             # pytest
```

Pytest automatically discovers files named `test_*.py` and `*_test.py`.

## Formatting and checks

The flake provides repository-wide maintenance and checks:

```bash
# Fix and validate the repository
nix fmt
# or, from the development shell
fmt

# Check the repository
nix flake check
# or, from the development shell
chk
```

## VS Code and Remote Development

Install the recommended VS Code extensions for this repository, including
Remote-SSH when opening the practical through an SSH remote host.

If you also want your normal local extensions available in the remote window,
run `Remote: Install Local Extensions in 'SSH: <host>'`, choose **Select All**,
and choose **Install**.
