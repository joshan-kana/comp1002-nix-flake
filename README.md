# COMP1002 practicals development environment

Nix flake for COMP1002 practicals.

## Setup

Create a practical directory from the template:

```bash
nix flake init -t 'git+ssh://git@github.com/joshan-kana/comp1002-nix-flake.git'
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

Update an existing practical from the latest template:

```bash
nix run 'git+ssh://git@github.com/joshan-kana/comp1002-nix-flake.git#sync'
direnv allow
```

Without direnv:

```bash
nix develop -c $SHELL
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

Format supported Python, Nix, TOML and Markdown files with:

```bash
nix fmt
```

or:

```bash
fmt
```

Check staged files with:

```bash
chk
```

Run the full repository checks with:

```bash
nix flake check
```

## VS Code and Remote Development

Install the recommended VS Code extensions for this repository, including
Remote-SSH when opening the practical through an SSH remote host.

If you also want your normal local extensions available in the remote window,
run `Remote: Install Local Extensions in 'SSH: <host>'`, choose **Select All**,
and choose **Install**.
