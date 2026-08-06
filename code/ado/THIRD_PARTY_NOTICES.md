# Third-party software notices

The `code/ado/` directory vendors third-party Stata packages, and
`code/ado/s/scheme-cleanplots.scheme` a third-party graph scheme, so that the
analysis runs in a self-contained environment without a network install.

These components are **not** the work of this repository's authors and are
**not** covered by the repository's MIT license (see `../../LICENSE.txt`). They
are redistributed **unmodified**, solely for reproducibility. Copyright and
licensing of each remain with its original author(s); consult each package's own
help file (`*.sthlp`) and its distribution source for the governing terms.

Except for the graph scheme, all packages were obtained from the Statistical
Software Components (SSC) archive maintained by the Boston College Department of
Economics (installed via `ssc install`).

| Package | Author(s) | Source |
|---|---|---|
| `reghdfe` | Sergio Correia | SSC |
| `ftools` | Sergio Correia | SSC |
| `require` | Sergio Correia | SSC |
| `ivreg2` | Christopher F. Baum, Mark E. Schaffer, Steven Stillman | SSC |
| `ranktest` | Mark E. Schaffer, Frank Windmeijer | SSC |
| `pdslasso` | Achim Ahrens, Christian B. Hansen, Mark E. Schaffer | SSC |
| `lassopack` | Achim Ahrens, Christian B. Hansen, Mark E. Schaffer | SSC |
| `uirt` | Bartosz Kondratek | SSC |
| `unique` | see `u/unique.sthlp` | SSC |
| `egenmore` | Nicholas J. Cox | SSC |
| `missings` | Nicholas J. Cox | SSC |
| `balancetable` | see `b/balancetable.sthlp` | SSC |
| `smileplot` (provides `multproc`) | Roger Newson | SSC |
| `listtab` | Roger Newson | SSC |
| `scheme-cleanplots` (graph scheme) | Trenton D. Mize (based on `plotplain`, Bischof 2017) | third-party scheme |

Package names above are as recorded in `stata.trk`. If you would rather not rely
on the vendored copies, each can be installed from its source instead (for the
SSC packages, `ssc install <name>`).

If any author would prefer their package not be redistributed here, we will
remove the vendored copy and document the installation step instead.
