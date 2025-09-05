# Changelog

## v0.2.1
 - updated version bounds for PrettyTables to include v3
 - updated PrettyTables API calls to be compatible with v3.x
 - replaced deprecated parameters: `columns_width` → `fixed_data_column_widths`, `noheader` → `show_column_labels`, `row_names` → `row_labels`, `header` → `column_labels`, `Highlighter` → `TextHighlighter`
 - note: single-column tables now always show column headers due to PrettyTables v3 limitations
 - updated tests to address changed `__init__` behavior on Julia v1.11 and new world-age semantics for bindings

## v0.2.0
 - now three different tree hashes: head, directory and manifest (see README)
 - (heavy) workaround to compute consistent directory tree hashes on Windows
 - more testing of tree hash behavior (in case it ever changes again)
 - updated version bounds for PrettyTables

## v0.1.0
 - first tagged release
 - new features: all of them
