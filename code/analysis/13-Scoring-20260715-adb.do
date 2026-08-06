********************************************************************************
* 13-Scoring-20260715-adb.do
* Robustness of the learning effects to scorer discretion.
*
* The assessments were administered and scored one-on-one by enumerators who
* were not blind to a school's program status. To gauge whether that could
* account for the effects, this file re-scores the ENDLINE assessment twice:
* once restricted to mechanically-scored ("objective") items, which admit a
* unique correct answer and leave no room for scorer discretion, and once to
* judgment-scored ("subjective") items (spoken production, composition, open
* responses). It then estimates the main Table 2 ITT on each subscore.
* Mathematics is scored entirely mechanically, so its objective effect is the
* full theta_math and it has no subjective counterpart.
*
* Method (mirrors the retired 13a/13b Appendix-G subscore machinery, trimmed to
* the objective/subjective split; the exam-reconciliation content, correlation,
* and gender-gap blocks are dropped):
*   1. Blank the complementary item set at ENDLINE only (baseline left full) and
*      EAP-score with the FIXED IRT parameters saved by 01-Testscores
*      (irt_arabic.ster, irt_french.ster); standardize within the comparison
*      group at endline.
*   2. Run the EXACT main ITT specification (student + pair-by-grade-by-post cell
*      FE, per-outcome post-double-selection LASSO controls, matched-pair-
*      clustered SEs), identical to 04-Table3.
*
* Item classification: scoring_itemlists.doh (endline Subjectivity flag).
* Output: output/tables/tablescoring.txt  (objective | subjective columns).
*
* Fast path: reads the on-disk .ster and temp3/temp4/temp6 in $eltemp; NO IRT
* rerun. If the .ster files are absent, re-enable the estimates-save lines in
* 01-Testscores and rerun its IRT once, then rerun this file.
*
* Author: Andy de Barros (adb)   Created: 15 Jul 2026
********************************************************************************
version 18
clear all
set more off
set seed 2816

do "code/_setup.do"
sysdir set PLUS "$code/ado"
include "code/analysis/scoring_itemlists.doh"

global tablescoring "$tables/tablescoring.txt"

*------------------------------------------------------------------------------
* 1. Re-score objective / subjective subscores (Arabic, French) from the .ster.
*    Blank the complementary endline item set (baseline left full), EAP-score
*    with the fixed parameters, standardize within the comparison group at
*    endline. Math is 100% mechanically scored -> no subscore needed.
*------------------------------------------------------------------------------
tempfile combined
local first 1
foreach s in arabic french {
    if "`s'"=="arabic" {
        local tf "$eltemp/temp3.dta"
        local pfx a
    }
    if "`s'"=="french" {
        local tf "$eltemp/temp4.dta"
        local pfx f
    }
    use "`tf'", clear
    estimates use "$eltemp/irt_`s'.ster"
    estimates store irt`s'

    * end-to-end check: reproduce the full theta and correlate with the stored one
    preserve
        estimates restore irt`s'
        capture uirt_theta, eap suffix(_chk)
        qui corr theta__chk theta_`s'
        di as result "CHECK `s': full-theta reproduce corr = " %8.5f r(rho) "  (want ~1.0)"
    restore

    foreach g in obj subj {
        local KEEP "`keep_`s'_`g'_el'"
        preserve
            capture ds `pfx'2*
            local ALL `r(varlist)'
            foreach v of local ALL {
                local base = subinstr("`v'","bldf_","",1)
                if regexm("`base'","^(`pfx'2[0-9]+)_[0-9]+$") local base = regexs(1)
                if !`: list base in KEEP' capture replace `v' = . if baseline==0
            }
            estimates restore irt`s'
            capture uirt_theta, eap suffix(`s'_`g')
            keep student_id baseline theta_`s'_`g'
            tempfile t_`g'
            save `t_`g''
        restore
        merge 1:1 student_id baseline using `t_`g'', nogen
    }

    * standardize new subscores within the comparison group at endline
    foreach v of varlist theta_`s'_* {
        qui sum `v' if treated==0 & baseline==0
        replace `v' = `v' - r(mean)
        qui sum `v' if treated==0 & baseline==0
        replace `v' = `v' / r(sd)
    }
    keep student_id baseline theta_`s'_*
    if `first' {
        save `combined', replace
        local first 0
    }
    else {
        merge 1:1 student_id baseline using `combined', nogen
        save `combined', replace
    }
}

*------------------------------------------------------------------------------
* 2. Estimate the main Table 2 ITT on each subscore (identical to 04-Table3).
*------------------------------------------------------------------------------
use "$eltemp/temp6.dta", clear
merge 1:1 student_id baseline using `combined', nogen

* baseline score for each subject (a covariate in the LASSO pool)
gen theta_baseline = .
replace theta_baseline = theta_arabic if subject==1 & baseline==1
replace theta_baseline = theta_french if subject==2 & baseline==1
replace theta_baseline = theta_math   if subject==3 & baseline==1
bysort student_id: egen _m = max(theta_baseline)
bysort student_id: replace theta_baseline = _m if _m<.
drop _m

keep if attrition==0
global pupilcon  "female grade1 grade2 grade3 grade4 grade5 grade6 gpa repeated tayssir theta_baseline"
global schoolcon "n_teachers urban regional_dev total_enrolled7_sum perc_female perc_tayssir avg_score7_mu perc_ssbenef"
xtset student_id post
gen post_treat = post*treated

capture program drop fmtcell
program define fmtcell, rclass
    args term
    local b  = _b[`term']
    local se = _se[`term']
    local t  = `b'/`se'
    local p  = 2*ttail(e(df_r), abs(`t'))
    local st = ""
    if `p'<=0.01      local st "***"
    else if `p'<=0.05 local st "**"
    else if `p'<=0.10 local st "*"
    local bf : di %4.2f `b'
    local sf : di %4.2f `se'
    return local b  = strtrim("`bf'")
    return local se = strtrim("`sf'")
    return local st "`st'"
end

* _itt <name> <outcome> : main spec, stash b_/se_/st_ in globals
capture program drop _itt
program define _itt
    args nm v
    qui reg D.`v' i.grade##i.pair_id if treated==0, cluster(pair_id)
    cap drop _res
    predict _res, residuals
    qui pdslasso _res treated ($pupilcon $schoolcon), cluster(pair_id)
    local c "`e(xselected)'"
    qui reghdfe `v' c.(`c')#i.post post post_treat if attrition==0, absorb(student_id post#grade#pair_id) vce(cluster pair_id)
    fmtcell post_treat
    global b_`nm'  "`r(b)'"
    global se_`nm' "`r(se)'"
    global st_`nm' "`r(st)'"
end

_itt math theta_math
foreach s in arabic french {
    _itt `s'_obj  theta_`s'_obj
    _itt `s'_subj theta_`s'_subj
}

*------------------------------------------------------------------------------
* 3. Write the snippet (objective | subjective; math has no subjective column).
*------------------------------------------------------------------------------
cap file close fh
file open fh using "${tablescoring}", write replace
file write fh "\multicolumn{1}{l}{Arabic} & $b_arabic_obj$st_arabic_obj & $b_arabic_subj$st_arabic_subj \\" _n
file write fh "  & ($se_arabic_obj) & ($se_arabic_subj) \\" _n
file write fh "\multicolumn{1}{l}{French} & $b_french_obj$st_french_obj & $b_french_subj$st_french_subj \\" _n
file write fh "  & ($se_french_obj) & ($se_french_subj) \\" _n
file write fh "\multicolumn{1}{l}{Mathematics} & $b_math$st_math & -- \\" _n
file write fh "  & ($se_math) &  \\" _n
file close fh

di as result "tablescoring.txt WRITTEN"
di as result "  Arabic  obj=$b_arabic_obj ($se_arabic_obj)  subj=$b_arabic_subj ($se_arabic_subj)"
di as result "  French  obj=$b_french_obj ($se_french_obj)  subj=$b_french_subj ($se_french_subj)"
di as result "  Math    obj=$b_math ($se_math)  subj=--"
