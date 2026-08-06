* ============================================================
* _setup.do — central path configuration for the analysis code chain.
*
* Sourced at the top of the analysis dofiles (it replaces the per-user
* "if `c(username)'... global work ..." blocks). Run everything from the
* repository root, either via code/00_master.do or
* by hand:   do "paths.do"   then   do "code/_setup.do".
* Forward slashes throughout, even on Windows.
* ============================================================

* --- machine roots (per-machine; gitignored) ------------------------------
* paths.do defines $root,$data,$datarepo,$published,$restricted,$temp,$code,$output,$paper,
* $stata_bin. Re-sourcing is idempotent; bootstrap it for standalone runs.
if "$root" == "" {
    do "paths.do"
}

* --- project base location -------------------------------------------------
* $data = ".../DiD - Morocco Pioneer School" (the project folder; set in paths.do).
global proj "$data"
global repo "$data"   // alias used by the cleaning/construction dofiles
global path "$data"   // alias used by the matching dofile
* $work = the Dropbox root (parent of the project folder); the Pattern-1
* analysis dofiles build paths as ${work}/DiD - Morocco Pioneer School/...
global work = subinstr("$data", "/DiD - Morocco Pioneer School", "", .)

* --- analysis-ready INPUT location ----------------------------------------
* $use_deposit 0 (default): read from the live "4 - Data processing" working
*   folders on Dropbox, exactly as the chain is run today.
* $use_deposit 1: read from the AEA deposit -- $published (author-owned baseline
*   & endline tests) and $restricted (Ministry-owned data) in the Data repository.
if "$use_deposit" == "" global use_deposit 0

* Live working-folder tree. $proc is always defined (the analysis dofiles that
* read ancillary inputs derive their own globals from it). Process monitoring
* (Figure A1) is not part of the curated deposit, so it always points at the live
* "4 - Data processing" tree. Dropout IS staged into the deposit, so $dropoutclean
* reads from the replication package ($restricted/dropout) in both modes.
global proc         "$data/4 - Data processing"
global dropoutclean "$restricted/dropout"
global monitor      "$proc/Process monitoring (INE)"

if $use_deposit == 0 {
    global sampling "$proc/Sampling"
    global blclean  "$proc/Baseline/Clean"
    global bltemp   "$proc/Baseline/Temp"
    global elclean  "$proc/Endline/Clean"
    global eltemp   "$proc/Endline/Temp"
}
else {
    global sampling "$restricted/sampling"   // Ministry-owned
    global blclean  "$published/baseline"    // author-owned (publishable)
    global bltemp   "$temp/baseline"
    global elclean  "$published/endline"     // author-owned (publishable)
    global eltemp   "$temp/endline"
}

* --- code OUTPUTS land in the repo (the paper reads from output/) ----------
global tables  "$output/tables"   // esttab snippets -> output/tables/*.txt
global figures "$output/plots"    // graph export    -> output/plots/*.pdf
