* ============================================================
* paths_example.do — TEMPLATE for per-machine path globals.
* Copy this file to paths.do (same folder) and edit for your machine.
* paths.do is gitignored; this template is tracked.
* Forward slashes always, even on Windows.
* ============================================================

version 18

* Repository root (the folder containing code/ and output/)
global root  "[EDIT]/psp"

* Confidential project data (wherever you placed it; never tracked)
global data  "[EDIT]/DiD - Morocco Pioneer School"

* Analysis-ready data, split by who may share it (confidential; not tracked):
*   $published  = author-collected primary data (cleaned baseline & endline
*                 student assessments); may be shared, after deidentification.
*   $restricted = administrative datasets owned by the Ministry of National
*                 Education (school records, examination scores, student lists,
*                 enrollment/dropout, and the matched school sample derived from
*                 them); available only via the journal's Data Editor under a
*                 data-use agreement; not redistributable.
global datarepo   "$data/4 - Data processing/Data repository"
global published  "$datarepo/data/published"
global restricted "$datarepo/data/restricted"
global temp       "$datarepo/temp"              // regenerable intermediates; not deposited

* Derived globals (usually no edit needed)
global code   "$root/code"
global output "$root/output"

* Pinned Stata binary (edit to your install)
global stata_bin "C:/Program Files/Stata18/StataSE-64.exe"

* Pinned Rscript binary for the causal-forest R step (point at an Rscript.exe
* whose R has grf, tidyverse, haven, cowplot).
global rscript_bin "C:/Program Files/R/R-4.6.0/bin/Rscript.exe"
