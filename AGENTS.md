# Repository instructions

This is an SAP ABAP Product Catalog project. The ABAP source code lives in `src/` and follows the abapGit file naming convention (namespace-prefixed with `#` delimiters).

## Project structure

- `src/` — ABAP source files (`.clas.abap` classes, `.ddls.asddls` CDS views)
- `abaplint.json` — Linter configuration for abaplint
- `package.json` — Node.js dev dependencies (abaplint CLI)

## Development commands

- **Lint**: `npm run lint` (runs abaplint against all files in `src/`)
- **Lint with auto-fix**: `npm run lint:fix`

## Cursor Cloud specific instructions

- This is an SAP ABAP project. ABAP code executes on SAP Application Servers (e.g. SAP BTP ABAP Environment or S/4HANA) and cannot be compiled, built, or run locally.
- The only local tooling available is **abaplint** (`npm run lint`) for static analysis and linting of ABAP source files. There is no local build, test runner, or application server.
- The `abaplint.json` config uses `errorNamespace: "^(/BITMYM/|Z|Y|LCL_|TY_|LIF_)"` to recognize the project's `/BITMYM/` namespace. The syntax version is set to `v758` (SAP S/4HANA).
- CDS view definitions (`.ddls.asddls`) define the data model; ABAP classes (`.clas.abap`) implement RAP query providers.
- When modifying ABAP code, always run `npm run lint` before committing to catch syntax and style issues.
- No Docker, databases, or external services are needed for the local dev workflow.
