********************************************************************************
* Appendix Figure A2: event-study / differences counterpart to Figure 1.
* A 2x2 of panels (overall, then Arabic / French / Math, matching Figure 1),
* each plotting the program-minus-comparison difference in the grade-6 national
* examination score for every pre-program year (2014/15-2022/23), with 95%
* confidence intervals clustered at the matched pair, on a COMMON vertical scale
* across panels. Each also reports a joint Wald test of no differential
* pre-trend (all year x treated interactions jointly zero). Panels are exported
* separately as figurea2_<overall|arabic|french|math>.pdf and assembled 2x2 in
* paper/figures/figurea2.tex; the overall panel is also written to figurea2.pdf
* so the single-panel wrapper fallback stays current. Figure 1 is unchanged.
*
* No notes are baked into the graph output (project convention: figure notes
* live in the LaTeX wrapper). The four joint-test p-values are printed to the
* log for transcription into the wrapper note.
*
* Author: Andy de Barros (adb)   Created: 15 Jul 2026
********************************************************************************

version 18
clear all
set more off
set seed 2816

do "code/_setup.do"
sysdir set PLUS "$code/ado"

global exam6ap   "$restricted/exam_6ap/clean_exam_6AP_20260504_ll.dta"
global xwalk_sch "$restricted/crosswalk/IDSchool_effective_sample_neam.dta"
global figurea2  "$figures/figurea2.pdf"

set scheme cleanplots
graph set window fontface "Garamond"

*--- 276 study schools: treatment + matched pair, bridged to cd_etab ---
use "$blclean/Baseline-tested-neam.dta", clear
bysort school_id: keep if _n==1
keep school_id treat pair_id
rename treat treated
merge 1:1 school_id using "$xwalk_sch", keep(match) nogen
assert !missing(pair_id) & _N==276
tempfile schools276
save `schools276'

*--- student-level grade-6 (6AP) exam data (overall + the 3 targeted subjects) ---
use cd_etab year exam_average exam_ar exam_fr exam_math using "$exam6ap", clear
keep if inrange(year, 2, 10)                               // 2014/15..2022/23; 2019/20 (=7) has no exam
merge m:1 cd_etab using `schools276', keep(match) nogen
tempfile exdata
save `exdata'

*--- event study per outcome: program-comparison difference by year + joint test.
*    Post each panel's per-year difference and SE to a single dataset so the four
*    panels can share a common vertical scale. ---
local outc  "exam_average exam_ar exam_fr exam_math"
local names "overall arabic french math"
local nout : word count `outc'

tempname pf
tempfile res
postfile `pf' byte k int year double diff double se using `res', replace

forvalues j = 1/`nout' {
    local y  : word `j' of `outc'

    use `exdata', clear
    keep if `y' < .

    reg `y' i.year##i.treated, vce(cluster pair_id)         // year-by-group means, matched-pair-clustered SEs
    testparm i.year#i.treated                               // joint no-differential-pre-trend test
    local jp`j' : di %5.3f r(p)
    di as result "JOINT PRE-TREND TEST (`: word `j' of `names'') p = `jp`j''"

    levelsof year, local(yrs)
    local base : word 1 of `yrs'                           // smallest year = the omitted base level of i.year
    foreach yy of local yrs {
        if `yy' == `base' {
            lincom 1.treated                               // program-comparison difference in the base year
        }
        else {
            lincom 1.treated + `yy'.year#1.treated         // difference at year yy (base treated effect + interaction)
        }
        post `pf' (`j') (`yy') (r(estimate)) (r(se))
    }
}
postclose `pf'

*--- common vertical scale across the four panels (rounded to a 0.5 grid) ---
use `res', clear
gen lower = diff - 1.96 * se                               // 95% CI (matched-pair-clustered)
gen upper = diff + 1.96 * se
qui sum lower
local lo = floor(r(min)*2)/2
qui sum upper
local hi = ceil(r(max)*2)/2

*--- one differences panel per outcome, common y-axis, Figure-1 x-axis labels ---
forvalues j = 1/`nout' {
    local nm : word `j' of `names'

    preserve
        keep if k==`j'
        twoway (rcap lower upper year, lcolor(gs9))                    ///
               (scatter diff year, mcolor(navy) msymbol(O)),          ///
               yline(0, lpattern(dash) lcolor(gs11))                  ///
               ytitle("Program {&minus} comparison difference", size(small)) ///
               ylabel(`lo'(0.5)`hi', labsize(small)) yscale(range(`lo' `hi')) ///
               xtitle("") ///
               xlabel(2 "2014/15" 3 "2015/16" 4 "2016/17" 5 "2017/18" 6 "2018/19" ///
                      7 "Covid year" 8 "2020/21" 9 "2021/22" 10 "2022/23", labsize(vsmall) angle(45)) ///
               legend(off)
        graph export "$figures/figurea2_`nm'.pdf", replace
        if "`nm'" == "overall" graph export "$figurea2", replace
        graph close
    restore
}

di as result "FIGURE A2 joint pre-trend p-values -> overall `jp1'  Arabic `jp2'  French `jp3'  math `jp4'"
