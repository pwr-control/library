# LaTeX template — copy of the pwr-control document template

Copy of `AAA_template_latex_settings/` of
[repositories-documentation](https://github.com/pwr-control/repositories-documentation), kept
here so that the documents of `documentation/<name>/` compile from the same source in both
repositories: every one of them starts with `\input{../../AAA_template_latex_settings/settings}`,
two levels up from its folder, and loads the title page with
`\input{../../AAA_template_latex_settings/titlepage}`.

| File | Purpose |
|---|---|
| `settings.tex` | Packages, page geometry, header/footer, theorem environments, `mybox`, SI units, colors. |
| `titlepage.tex` | Title page built from the `\Doc...` macros defined by the document, including the revision history table. |
| `pwr-control_logo_doc.png` | Logo placed in the header of every page. |

Keep the three files identical to those of repositories-documentation: edit them there first,
then copy them here. The older title pages of the original folder are not needed by the
documents kept in this repository and are not copied.
