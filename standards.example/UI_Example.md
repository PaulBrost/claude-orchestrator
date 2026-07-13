# UI Standard — Example (template)

Copy this directory to `standards/` (which is gitignored) and write one UI standard per design system you maintain (e.g. `UI_Personal.md`, `UI_Work.md`). Link each to its projects via the `**UI Standard:**` field in the registry entry — projects without the field have no UI standard applied.

The rules below are illustrative placeholders — replace them with your own.

Applies to projects whose registry entry lists `**UI Standard:** standards/<this file>`. Delegation prompts for UI work must reference this file by absolute path.

## CSS / component library

- **Bootstrap is the preferred CSS library.** Use Bootstrap components and utility classes before writing custom CSS; custom styles are for gaps Bootstrap genuinely doesn't cover, not for restyling what it provides.
- Match the Bootstrap major version already used by the project; don't introduce a second CSS framework.

## Loading & slow data

- Data requiring significant load time must **not** block initial page render. Render the page shell first, then fetch the data via AJAX.
- While loading, display a visible loading indicator (Bootstrap spinner) in the space the data will occupy.
- On AJAX failure, show a user-visible error state in that space — never leave a spinner running forever.

## Tables

- Data tables must be **sortable** (by column) and **paginated**.
- Follow whatever table tooling the project already uses for sort/pagination; if introducing it fresh, prefer a lightweight approach consistent with the CSS library.

## Not yet decided (placeholders — extend this file, don't improvise per-project)

- Color palette / theming
- Graphics & iconography conventions
- Form layout and validation display conventions
- Accessibility requirements
