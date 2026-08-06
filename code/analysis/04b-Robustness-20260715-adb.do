*******************************************************************************
* Appendix robustness table: the main learning effect under the pre-registered
* specification and two transparency checks. NOT competing specifications: the
* pre-registered spec (column 1) is the result reported in Table 2; columns 2-3
* confirm it is not an artifact of the data-driven controls or of the modeling
* choices.
*   (1) Pre-registered: student FE + matched-pair-by-grade-by-post cell FE +
*       post-double-selection-LASSO-selected controls x post. (Reproduces Table 2,
*       Panel A.)
*   (2) Without the selected controls.
*   (3) Raw matched-pair difference: the student's baseline-to-endline score
*       change regressed on program status with matched-pair fixed effects only.
* Rows: overall (stacked) and by subject. Reads the cached IRT panel ($eltemp/temp6).
*
* Author: Andy de Barros (adb)   Created: 15 Jul 2026
* Data prep and the pre-registered spec are reproduced verbatim from 04-Table3.
*******************************************************************************

version 18
clear all
set more off
set seed 2816

do "code/_setup.do"
sysdir set PLUS "$code/ado"

global temp6       "$eltemp/temp6.dta"
global pupilcon    "female grade1 grade2 grade3 grade4 grade5 grade6 gpa repeated tayssir theta_baseline"
global schoolcon   "n_teachers urban regional_dev total_enrolled7_sum perc_female perc_tayssir avg_score7_mu perc_ssbenef"
global tablerobust "$tables/tablerobust.txt"

* ---- data prep (verbatim from 04-Table3) ---------------------------------
use "$temp6", clear
gen theta_overall = .
replace theta_overall = theta_arabic if subject == 1
replace theta_overall = theta_french if subject == 2
replace theta_overall = theta_math   if subject == 3
gen theta_baseline = .
replace theta_baseline = theta_arabic if subject == 1 & baseline == 1
replace theta_baseline = theta_french if subject == 2 & baseline == 1
replace theta_baseline = theta_math   if subject == 3 & baseline == 1
bysort student_id: egen max = max(theta_baseline)
bys student_id: replace theta_baseline = max if max<.
drop max
keep if attrition == 0

xtset student_id post
global subject "overall arabic french math"
foreach sub of global subject {
	gen change_`sub' = D.theta_`sub'
}
* PDS-LASSO control selection (deterministic; verbatim)
foreach sub of global subject {
	qui reg change_`sub' i.grade##i.pair_id if treated == 0, cluster(pair_id)
	predict res_score_`sub', residuals
	qui pdslasso res_score_`sub' treated ($pupilcon $schoolcon), cluster(pair_id)
	global controls_`sub' "`e(xselected)'"
}
gen post_treat = post * treated

* ---- cell formatter (verbatim from 04-Table3) ----------------------------
capture program drop fmtcell
program define fmtcell, rclass
	args term
	local b  = _b[`term']
	local se = _se[`term']
	local df = e(df_r)
	local t  = `b'/`se'
	local p  = 2*ttail(`df', abs(`t'))
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

* ---- three columns per outcome -------------------------------------------
foreach sub of global subject {
	* (1) pre-registered specification (identical to Table 2, Panel A)
	qui reghdfe theta_`sub' c.(${controls_`sub'})#i.post post post_treat if attrition==0, ///
		absorb(student_id post#grade#pair_id) vce(cluster pair_id)
	fmtcell post_treat
	local b1_`sub' "`r(b)'"
	local se1_`sub' "`r(se)'"
	local st1_`sub' "`r(st)'"

	* (2) without the LASSO-selected controls
	qui reghdfe theta_`sub' post post_treat if attrition==0, ///
		absorb(student_id post#grade#pair_id) vce(cluster pair_id)
	fmtcell post_treat
	local b2_`sub' "`r(b)'"
	local se2_`sub' "`r(se)'"
	local st2_`sub' "`r(st)'"

	* (3) raw matched-pair difference in baseline-to-endline change
	qui reghdfe change_`sub' treated if attrition==0, absorb(pair_id) vce(cluster pair_id)
	fmtcell treated
	local b3_`sub' "`r(b)'"
	local se3_`sub' "`r(se)'"
	local st3_`sub' "`r(st)'"

	di as result "`sub': (1) `b1_`sub'' (2) `b2_`sub'' (3) `b3_`sub''"
}

* ---- write the snippet ----------------------------------------------------
cap file close a
file open a using "$tablerobust", write replace
foreach sub in overall arabic french math {
	if "`sub'"=="overall" local lab "Overall"
	if "`sub'"=="arabic"  local lab "Arabic"
	if "`sub'"=="french"  local lab "French"
	if "`sub'"=="math"    local lab "Mathematics"
	file write a "\multicolumn{1}{l}{`lab'} & `b1_`sub''`st1_`sub'' & `b2_`sub''`st2_`sub'' & `b3_`sub''`st3_`sub'' \\" _n
	file write a "  & (`se1_`sub'') & (`se2_`sub'') & (`se3_`sub'') \\" _n
}
file close a
di as result "ROBUSTNESS TABLE WRITTEN"
