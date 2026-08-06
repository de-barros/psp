**************************************************************************
** File:    00_master.do
** Purpose: Entry point. Reproduces the study's tables and figures from
**          clean (analysis-ready) data. Run from the repository root.
**************************************************************************
*
*   "C:/Program Files/Stata18/StataSE-64.exe" -b do code/00_master.do
*
* First copy paths_example.do -> paths.do and code/paths_example.R -> code/paths.R
* and edit them for your machine.
*
* SCOPE: this package runs ONLY from analysis-ready ("clean") data and produces
* ONLY the study's exhibits. The school matching/sampling is NOT re-run: it was
* not done reproducibly (no seed before the Mahalanobis match), so the realized
* evaluation sample, which carries the matched-pair and stratum identifiers, is
* used as a FIXED input.
*
* Required Stata packages (vendored in code/ado): reghdfe, ftools, estout
* (esttab), pdslasso (lassopack), uirt, multproc, unique, egenmore, balancetable.
* R (causal forest only): grf, tidyverse, haven, cowplot.
*
* Globals are shared WITHIN this Stata session: 01 builds $eltemp/temp6,temp7
* and sets $irta..; 04 builds $controls_*. Keep the order below.
*-------------------------------------------------------------------------*

version 18
clear all
set more off
do "paths.do"
cd "$root"
* global use_deposit 1   // read inputs from the AEA deposit ($published/$restricted) instead of the live folders
do "code/_setup.do"
sysdir set PLUS "$code/ado"   // use the vendored packages in code/ado (session-scoped; does not persist)

global run_R 1   // 1 = run the R causal forest (via $rscript_bin)

local A "$code/analysis"

* --- Build the analysis panel (IRT scores; writes $eltemp/temp6,temp7; sets $irta..) ---
do "`A'/01-Testscores-20251008-adb.do"

* --- Tables and figures ---------------------------------------------------
do "`A'/02-Table1-20240815-sd.do"     // student sample & balance
do "`A'/04-Table3-20240907-adb.do"    // main ITT effects on learning; builds $controls_*
do "`A'/04b-Robustness-20260715-adb.do" // robustness of the learning effects to the specification
do "`A'/11-TableA3-20240815-adb.do"   // nature of the learning gains: fluency, content, grade level
do "`A'/06-Table6-20260702-adb.do"    // school-universe DiD: enrollment and grade progression
do "`A'/13-Scoring-20260715-adb.do"   // mechanically- vs judgment-scored items (scorer-discretion robustness)
do "`A'/07-Placebo-20260710-adb.do"   // placebo / pre-trend test (treatment moved one year earlier)
do "`A'/09-TableA1-20240919-ya.do"    // school-level representativeness & balance
do "`A'/10-TableA2-20240913-sd.do"    // baseline balance, non-attriting students
do "`A'/08-Figure1-20251007-adb.do"   // parallel trends (pre-program exam scores)
do "`A'/08b-FigureA2-20260715-adb.do" // event-study / differences pre-trend, joint test
do "`A'/12-FigureA1-20250827-adb.do"  // implementation duration (Teaching at the Right Level)

* --- Causal-forest heterogeneity: the R forest builds its table directly ---
if $run_R == 1 {
    shell "$rscript_bin" "code/analysis/05-Table4-20250401-adb.R"   // grf; writes output/tables/table4_forest.txt + $eltemp/temp8.csv
}
* $rscript_bin is set in paths.do. If R is unavailable, set run_R 0 above and run
* Table 4 by hand (with an Rscript whose R has grf, tidyverse, haven, cowplot):
*   <Rscript> "code/analysis/05-Table4-20250401-adb.R"

display as result "00_master.do complete."
