# OCA Days 2023 - How to organize an Odoo project as a regular Python app

This is a demo Odoo project to demonstrate the use of standard Python tooling for
Odoo development.

It is used as support for the eponymous [OCA Days 2023 talk](https://docs.google.com/presentation/d/1Ku1e9HI2M992Q81eXbnwtX1vKm8wgarVsmaHSKKEHrM).

## Develop in a virtual environment

### Prerequisites

- Python 3.11
- Postgres
- The usual Odoo build dependencies
- pip-deepfreeze (`pipx install pip-deepfreeze`)

### Create and activate a virtualenv

    python3.11 -m venv .venv
    source .venv/bin/activate

### Install

    pip-deepfreeze sync

### Run

    odoo -d odoodemodb

## Develop in a devcontainer

### Prerequisites

- docker-compose
- vscode (other tools that support devcontainers should work)

### Install and run

- Open in vscode.
- Run the `>Dev Containers: Open Folder in Container...`.
- Open a VS Code terminal in the devcontainer and run `odoo`.

## Common operations

### Adding a dependency

Update `odoo/addons/my_custom_addon/__manifest__.py` to add `mis_builder` to the
`depends` section.

Open a terminal, make sure the virtualenv is activated, and run `pip-deepfreeze sync`.

Notice that MIS Builder and its dependencies are installed, and that `requirements.txt`
is updated with the exact versions installed.

### Removing a dependency

Update `odoo/addons/my_custom_addon/__manifest__.py` to remove `mis_builder` from the
`depends` section.

Open a terminal, make sure the virtualenv is activated, and run `pip-deepfreeze sync`.

Notice it proposes to uninstall `odoo-addon-mis_builder` and it's dependencies.
If you accept, `requirements.txt` is updated.

### Updating a dependency

There are two possibilities:

- Remove the dependency from `requirements.txt` and re-run `pip-deepfreeze sync`, to force it to reinstall from the latest version.
- Run `pip-deepfreeze sync --upgrade {packagename}`.
