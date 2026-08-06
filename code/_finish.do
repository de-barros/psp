**************************************************************************
** _finish.do  —  RESUME driver (not part of the replication entry point).
**
** 01-Testscores (the multi-hour IRT) already completed; temp1..temp7 are on
** disk in $eltemp. This runs ONLY the remaining steps (tables + figures +
** Table 4), which each re-source _setup.do and read the panel from disk.
** capture-noisily so one failing step does not abort the rest; every step's
** return code is logged. Launch in GUI mode (NO -b) so it is immune to the
** console-break issue:
**     StataSE-64.exe do "code/_finish.do"
**************************************************************************
version 18
clear all
do "paths.do"
cd "$root"
do "code/_setup.do"
sysdir set PLUS "$code/ado"

* 01-Testscores already ran (temp1..temp7 on disk). Set its run-flags so the
* table/figure steps that branch on them (e.g. 08-Figure1: if $irta==1) execute.
global setglobals 1
global irta  1
global irtf  1
global irtm  1
global egr   1
global comb  1
global resid 1

capture log close _all
log using "_finish.log", replace text
di as txt "=== _finish.do START " c(current_date) " " c(current_time) " ==="

local A "$code/analysis"
foreach step in ///
    02-Table1-20240815-sd     ///
    04-Table3-20240907-adb    ///
    04b-Robustness-20260715-adb ///
    11-TableA3-20240815-adb   ///
    06-Table6-20260702-adb    ///
    13-Scoring-20260715-adb   ///
    07-Placebo-20260710-adb   ///
    09-TableA1-20240919-ya    ///
    10-TableA2-20240913-sd    ///
    08-Figure1-20251007-adb   ///
    08b-FigureA2-20260715-adb ///
    12-FigureA1-20250827-adb  {
    di as txt _n "=== STEP `step' START " c(current_time) " ==="
    capture noisily do "`A'/`step'.do"
    di as result "=== STEP `step' rc=" _rc " ==="
}

di as txt _n "=== R STEP 05-Table4 (causal forest) START " c(current_time) " ==="
capture noisily shell "$rscript_bin" "code/analysis/05-Table4-20250401-adb.R"
di as result "=== R STEP rc=" _rc " ==="

di as result _n "=== _finish.do COMPLETE " c(current_date) " " c(current_time) " ==="
log close _all
exit, clear
