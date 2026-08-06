# Large learning gains from government-delivered school reform in Morocco

This repository contains the Stata and R code that reproduces the tables and
figures for a study of the one-year effects of Morocco's Pioneer School Program
(PSP), a government-implemented reform in public primary schools that combines
structured pedagogy with targeted remediation following the "Teaching at the
Right Level" approach. The evaluation uses a prospective, pre-registered matched
difference-in-differences design; learning outcomes are item-response-theory
(IRT) scored assessments in Arabic, French, and Mathematics; heterogeneity is
estimated with a causal forest.

The entry point `code/00_master.do` reproduces every exhibit from analysis-ready
("clean") data.

## Preregistration

The pre-analysis plan for this study is registered on the Open Science
Framework: <https://osf.io/zg5ry/>.

## Data availability

The datasets that support this study are **not** included in this repository and
are provided separately, subject to their ownership and access conditions.

- **Primary data (author-collected).** The baseline and endline student
  assessment data (the item responses underlying the IRT-scored Arabic, French,
  and Mathematics tests) were collected by the authors for this study. These can
  be shared for peer review and, after a deidentification pass, will be
  deposited openly.
- **Administrative data (restricted).** All other datasets (school
  administrative records, examination scores, student enrollment and dropout
  records, student lists, and the matched school sample derived from them) are
  owned by Morocco's Ministry of National Education. They cannot be
  redistributed and can be made available only to the journal's Data Editor
  under a data-use agreement.

The analysis reads the primary data through the global `$published` and the
administrative data through `$restricted` (both set in `paths.do`). Neither
directory is part of this repository. Raw source data and the upstream
cleaning/deidentification are not included; the package runs only from
analysis-ready data.

| Analysis-ready input | Owner | Access tier |
|---|---|---|
| Baseline student assessments | Authors | Primary (shareable) |
| Endline student assessments | Authors | Primary (shareable) |
| School administrative and classroom records | Ministry of National Education | Administrative (restricted) |
| Grade-6 examination scores | Ministry of National Education | Administrative (restricted) |
| Student enrollment and dropout records | Ministry of National Education | Administrative (restricted) |
| Matched school sample (with pair / stratum identifiers) | Derived from Ministry data | Administrative (restricted) |
| Student characteristics; school crosswalk | Ministry / derived | Administrative (restricted) |

## Software and reproducibility

- **Stata 18.** All user-written packages are vendored in `code/ado/` (reghdfe,
  ftools, pdslasso, lassopack, uirt, multproc, unique, egenmore, balancetable,
  and their dependencies), so no network install is needed; `00_master.do`
  points the session's `PLUS` directory at `code/ado/`. `diflogistic` / `difmh`
  ship with Stata 18.
- **R 4.6.0** for the causal-forest step (`code/analysis/05-Table4-...R`), with
  `grf`, `tidyverse`, `haven`, and `cowplot` pinned in `renv.lock`. Run
  `renv::restore()` to reproduce the library.
- **Seeds.** Stata estimation seed `2816`; causal-forest seed `1839`.
- **Sampling note.** The school matching/sampling is not re-run and is not part
  of this package: it was not done reproducibly (the Mahalanobis match was run
  without a seed). The realized matched sample, which carries the matched-pair
  and stratum identifiers, is taken as a fixed input.

## How to run

1. Obtain the data (see **Data availability**) and place the analysis-ready
   inputs where the paths point.
2. Copy `paths_example.do` to `paths.do` and `code/paths_example.R` to
   `code/paths.R`; edit them for your machine (data location, Stata and Rscript
   binaries).
3. From the repository root:

   ```bash
   "C:/Program Files/Stata18/StataSE-64.exe" -b do code/00_master.do
   ```

   This runs the Stata scripts in order, then shells out to `Rscript` for the
   causal forest. Tables are written to `output/tables/`, figures to
   `output/plots/`. If `Rscript` is unavailable, set `global run_R 0` in
   `00_master.do` and run `05-Table4-...R` separately.

The full run is heavy (the IRT scoring alone takes a few hours and writes
intermediate panels to disk). `code/_finish.do` re-runs only the table and
figure steps from those cached intermediates. Generated tables and figures from
a complete run are included in `output/`, so the code's outputs can be inspected
without re-running.

## Repository layout

```
psp/
├── code/
│   ├── 00_master.do          entry point (runs everything in order)
│   ├── _setup.do / _setup.R  path configuration
│   ├── _finish.do            resume driver (tables/figures only)
│   ├── paths_example.R       per-machine R path template
│   ├── analysis/             the scripts that build each exhibit
│   └── ado/                  vendored Stata packages (self-contained)
├── output/
│   ├── tables/               code-generated table snippets (.txt)
│   └── plots/                code-generated figures (.pdf / .png)
├── renv/, renv.lock, .Rprofile   pinned R environment
├── paths_example.do          per-machine Stata path template
└── LICENSE.txt               MIT (code); data not included
```

## Program-to-output map

Each script writes to `output/`; match the content to the corresponding exhibit
in the manuscript.

| Script (`code/analysis/`) | Produces | Output file(s) |
|---|---|---|
| `02-Table1-...do` | Student sample and balance | `tables/table1.txt` |
| `04-Table3-...do` | Main ITT effects on learning (overall and by subject; by gender; by baseline quartile; difference-in-effects rows) | `tables/table2a.txt`, `table2b.txt`, `table2c.txt` |
| `11-TableA3-...do` | Nature of the learning gains: reading fluency, content and cognitive subdomains, at- vs below-grade level | `tables/tablea3_1.txt`, `tablea3_2.txt`, `tablea3_3.txt` |
| `04b-Robustness-...do` | Robustness of the learning effects to the specification (pre-registered vs. no controls vs. raw matched-pair difference) | `tables/tablerobust.txt` |
| `13-Scoring-...do` | Effects on mechanically- vs judgment-scored items (scorer-discretion robustness) | `tables/tablescoring.txt` |
| `06-Table6-...do` | ITT on enrollment and grade progression (school universe) | `tables/table3.txt` |
| `07-Placebo-...do` | Placebo / pre-trend test (treatment moved one year earlier) | `tables/tableplacebo.txt` |
| `09-TableA1-...do` | School representativeness and balance | `tables/tablea1.txt` |
| `10-TableA2-...do` | Student attrition balance | `tables/tablea2.txt` |
| `05-Table4-...R` | Heterogeneous treatment effects (causal forest / CATE) | `tables/tablea4_forest.txt` |
| `01-Testscores-...do` (measurement block, flag `$measure`) | Psychometric properties of the assessments; reliability across ability | `tables/tableb1.txt`; `plots/figureb1_{arabic,french,math}.pdf` |
| `08-Figure1-...do` | Parallel trends (pre-program examination scores) | `plots/figure1.pdf` |
| `08b-FigureA2-...do` | Event-study / differences pre-trend, with a joint no-differential-pre-trend test | `plots/figurea2.pdf` |
| `12-FigureA1-...do` | Implementation duration of the "Teaching at the Right Level" component | `plots/figurea1.pdf` |

`01-Testscores-...do` builds the IRT scores and the analysis panel that the
downstream scripts read; its measurement block (gated by `$measure`) also
produces the psychometric exhibits.

## Multiple-hypothesis testing

The confirmatory learning and enrollment tables report Westfall-Young stepdown
adjusted p-values (family-wise error rate, cluster bootstrap on the matched
pair); the causal-forest table reports Benjamini-Yekutieli q-values. Simple
matched-pair-clustered standard errors are used elsewhere.

## License

Code is released under the MIT License (see `LICENSE.txt`). The confidential data
are not included and are governed by the data providers' terms.
