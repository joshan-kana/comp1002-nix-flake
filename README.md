# COMP1002 practicals development environment

Nix flake COMP1002 practicals

## Included

- Python 3 and NumPy
- Ruff Python linting, import sorting, fixes and formatting
- mypy static type checking
- pytest and optional coverage reports
- treefmt-nix for coordinated Python, Nix and TOML formatting
- Statix Nix linting and automatic fixes
- nixfmt Nix formatting
- Taplo TOML formatting because this repository has `pyproject.toml`
- nixd Nix language-server support in VS Code
- direnv activation through `.envrc`
- VS Code extensions, settings, tasks and debugger configurations

## VS Code and Remote Development

Install the recommended VS Code extensions for this repository, including
Remote-SSH when opening the practical through an SSH remote host.

If you also want your normal local extensions available in the remote window,
run `Remote: Install Local Extensions in 'SSH: <host>'`, choose **Select All**,
and choose **Install**.

## Commands

```bash
# Enter the environment manually when not using direnv
nix develop

# Apply fixes and format Python, Nix and TOML (mutating)
nix fmt

# Ruff, Statix and mypy
nix run .#lint

# Pytest, or skip successfully when no tests exist
nix run .#test

# Verify formatting, linting, typing and tests
nix flake check
```

## Test naming

Pytest automatically discovers files named `test_*.py` and `*_test.py`.
