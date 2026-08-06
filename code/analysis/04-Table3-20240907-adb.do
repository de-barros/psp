*******************************************************************************
* Author : Sarah Deschênes
* Date Created: 15 Aug 2024
* Last Modified by: adb, 2 Jul 2026 -- multiple-hypothesis testing switched from
*   Benjamini-Yekutieli (q-values) to the pre-registered Westfall-Young stepdown
*   (family-wise error rate), computed by cluster bootstrap on the matched pair.
*   Graduated families: (1a) subjects among all students; (1b) the overall/index
*   effect within each subgroup; (2) subjects within each subgroup; plus the
*   difference-in-effects (contrast) families (C-idx, C-sub). The overall score
*   for all students is the primary index and is reported unadjusted.
* Prints as Table 2 (main ITT on learning) after the 2026-07-03 renumbering; the
* step keeps its name (04-Table3) and writes table2a/b/c.txt. (PAP shell: Table 3.)
********************************************************************************

********************************************************************************
                                 * Analysis *
********************************************************************************

clear 		all
set more 	off
set 		seed 2816
version 	18

global setglobals	  "1"

********************************************************************************
                  * Set file directories as globals *
********************************************************************************

if $setglobals==1 {

	do "code/_setup.do"
	sysdir set PLUS "$code/ado"   // vendored packages (reghdfe, pdslasso, wyoung); session-scoped, as in 00_master.do

	// Temp files
	global temp6			"$eltemp/temp6.dta" // long data with all test scores

	// Table
	global table2a			"${tables}/table2a.txt" // Panel A: overall / by subject
	global table2b			"${tables}/table2b.txt" // Panel B: by gender (+ contrast)
	global table2c			"${tables}/table2c.txt" // Panel C: baseline quartile (+ contrast)

	// Controls (to be picked by Lasso)
	global pupilcon "female grade1 grade2 grade3 grade4 grade5 grade6 gpa repeated tayssir theta_baseline" // student controls
	global schoolcon "n_teachers urban regional_dev total_enrolled7_sum perc_female perc_tayssir avg_score7_mu perc_ssbenef" // school controls
	global controls "$pupilcon $schoolcon" // all controls

}

********************************************************************************
use "$temp6", clear

// 0.1. Generate overall score by stacking scores
gen theta_overall = .
replace theta_overall = theta_arabic if subject == 1
replace theta_overall = theta_french if subject == 2
replace theta_overall = theta_math   if subject == 3
lab var theta_overall "Stacked score"

gen bottom_overall = .
replace bottom_overall = bottom_arabic if subject == 1
replace bottom_overall = bottom_french if subject == 2
replace bottom_overall = bottom_math   if subject == 3

gen top_overall = .
replace top_overall = top_arabic if subject == 1
replace top_overall = top_french if subject == 2
replace top_overall = top_math   if subject == 3

// Add variable with the baseline score for each subject
gen theta_baseline = .
replace theta_baseline = theta_arabic if subject == 1 & baseline == 1
replace theta_baseline = theta_french if subject == 2 & baseline == 1
replace theta_baseline = theta_math   if subject == 3 & baseline == 1
bysort student_id: egen max = max(theta_baseline)
bys student_id: replace theta_baseline = max if max<.
drop max

// 0.2. keep non-attriting students only
keep if attrition == 0

// 1. POST-DOUBLE-SELECTION LASSO FOR CONTROL VARIABLES
xtset student_id post
global subject "overall arabic french math"
foreach sub of global subject {
	gen change_`sub' = D.theta_`sub'
}
foreach sub of global subject {
	qui: reg change_`sub' i.grade##i.pair_id if treated == 0, cluster(pair_id)
	predict res_score_`sub', residuals
	pdslasso res_score_`sub' treated ($pupilcon $schoolcon), cluster(pair_id)
	global controls_`sub' "`e(xselected)'"
}
foreach sub of global subject {
	 mac list controls_`sub'
}

// 2. Predictor of interest (post X Treated) and contrast interactions
gen post_treat = post * treated
label var post_treat "Predictor of Interest"

* Gender contrast: coefficient on fXpt = (female DiD) - (male DiD).
gen fXpt = female * post_treat
gen fXpo = female * post

* Baseline contrast (per outcome): bottom_`sub' is the indicator on the bottom|top
* subsample (1=bottom, 0=top). Coefficient on bpt_`sub' = (bottom DiD) - (top DiD).
foreach sub of global subject {
	gen bpt_`sub' = bottom_`sub' * post_treat
	gen bpo_`sub' = bottom_`sub' * post
}

********************************************************************************
* Reusable pieces
********************************************************************************
* EXACT main-table specification (kept identical so adjusted p-values correspond
* to the reported coefficients).
* The cell effects are ABSORBED rather than entered as ~1,900 dummy regressors:
* identical model and post_treat coefficient (the `post' term in the models below
* drops out as collinear with the absorbed cells, exactly as it did before), but
* reghdfe computes the clustered-SE degrees of freedom correctly -- the cells are
* nested inside the pair cluster -- and each fit is ~300x faster, which is what
* makes the B=2500 Westfall-Young bootstrap feasible (the dummy form is ~2 months).
local FE  ""
local OPT "absorb(student_id post#grade#pair_id) vce(cluster pair_id)"

*------------------------------------------------------------------------------
* SMOKE TEST FIRST. Set B = 50, run the whole dofile (a few minutes), confirm it
* completes and the [adjusted p] rows are sane, and note the elapsed time. THEN
* set B = 5000 for the publication run (Westfall-Young needs many replications).
*------------------------------------------------------------------------------
local B = 2500    // Westfall-Young bootstrap replications (publication run)

* Format a single cell from the estimates in memory: returns r(b), r(se), r(st).
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

* One Westfall-Young family. Reads the compound-quoted model sequence in
* $WYMODELS and the familyp specification in $WYFP; returns r(p1)..r(p`nt') =
* the stepdown-adjusted p-values, in the order the models were supplied.
capture program drop wyfam
program define wyfam, rclass
	args B nt
	wyoung, cmd(`" $WYMODELS "') familyp($WYFP) cluster(pair_id) reps(`B') seed(2816)
	matrix R = r(table)
	local c = colnumb(R,"pwyoung")
	forvalues h = 1/`nt' {
		return scalar p`h' = R[`h',`c']
	}
end

********************************************************************************
* 3. POINT ESTIMATES (b / se / stars) for every reported cell
********************************************************************************
* Panel A: all students (overall + 3 subjects)
foreach sub of global subject {
	qui reghdfe theta_`sub' `FE' c.(${controls_`sub'})#i.post post post_treat if attrition==0, `OPT'
	fmtcell post_treat
	local b_`sub'_A "`r(b)'"
	local se_`sub'_A "`r(se)'"
	local st_`sub'_A "`r(st)'"
}

* Panels B/C subgroup rows: Female, Male, Bottom, Top
foreach sub of global subject {
	qui reghdfe theta_`sub' `FE' c.(${controls_`sub'})#i.post post post_treat if attrition==0 & female==1, `OPT'
	fmtcell post_treat
	local b_`sub'_F "`r(b)'"
	local se_`sub'_F "`r(se)'"
	local st_`sub'_F "`r(st)'"

	qui reghdfe theta_`sub' `FE' c.(${controls_`sub'})#i.post post post_treat if attrition==0 & female==0, `OPT'
	fmtcell post_treat
	local b_`sub'_M "`r(b)'"
	local se_`sub'_M "`r(se)'"
	local st_`sub'_M "`r(st)'"

	qui reghdfe theta_`sub' `FE' c.(${controls_`sub'})#i.post post post_treat if attrition==0 & bottom_`sub'==1, `OPT'
	fmtcell post_treat
	local b_`sub'_bot "`r(b)'"
	local se_`sub'_bot "`r(se)'"
	local st_`sub'_bot "`r(st)'"

	qui reghdfe theta_`sub' `FE' c.(${controls_`sub'})#i.post post post_treat if attrition==0 & top_`sub'==1, `OPT'
	fmtcell post_treat
	local b_`sub'_top "`r(b)'"
	local se_`sub'_top "`r(se)'"
	local st_`sub'_top "`r(st)'"
}

* Contrast rows: Female vs male (fXpt), Bottom vs top (bpt_`sub')
foreach sub of global subject {
	qui reghdfe theta_`sub' `FE' c.(${controls_`sub'})#i.post post post_treat fXpo fXpt if attrition==0, `OPT'
	fmtcell fXpt
	local b_`sub'_cg "`r(b)'"
	local se_`sub'_cg "`r(se)'"
	local st_`sub'_cg "`r(st)'"

	qui reghdfe theta_`sub' `FE' c.(${controls_`sub'})#i.post post post_treat bpo_`sub' bpt_`sub' if (bottom_`sub'==1|top_`sub'==1), `OPT'
	fmtcell bpt_`sub'
	local b_`sub'_cb "`r(b)'"
	local se_`sub'_cb "`r(se)'"
	local st_`sub'_cb "`r(st)'"
}

********************************************************************************
* 4. WESTFALL-YOUNG ADJUSTED p-VALUES, family by family
********************************************************************************
global WYFP "post_treat"

* Family 1a: subjects among all students (3 tests). Overall/index is the primary
* and is NOT adjusted, so it is not part of any family.
global WYMODELS ""
foreach sub in arabic french math {
	local m `"reghdfe theta_`sub' `FE' c.(${controls_`sub'})#i.post post post_treat if attrition==0, `OPT'"'
	global WYMODELS `"$WYMODELS `"`m'"'"'
}
wyfam `B' 3
local ap_arabic_A = strtrim(string(r(p1),"%5.3f"))
local ap_french_A = strtrim(string(r(p2),"%5.3f"))
local ap_math_A   = strtrim(string(r(p3),"%5.3f"))

* Family 1b: the overall/index effect within each subgroup (4 tests: F, M, bot, top).
global WYMODELS ""
foreach cond in "female==1" "female==0" "bottom_overall==1" "top_overall==1" {
	local m `"reghdfe theta_overall `FE' c.(${controls_overall})#i.post post post_treat if attrition==0 & `cond', `OPT'"'
	global WYMODELS `"$WYMODELS `"`m'"'"'
}
wyfam `B' 4
local ap_overall_F   = strtrim(string(r(p1),"%5.3f"))
local ap_overall_M   = strtrim(string(r(p2),"%5.3f"))
local ap_overall_bot = strtrim(string(r(p3),"%5.3f"))
local ap_overall_top = strtrim(string(r(p4),"%5.3f"))

* Family 2: subjects within each subgroup (12 tests: subject x {F,M,bot,top}).
global WYMODELS ""
foreach sub in arabic french math {
	foreach cond in "female==1" "female==0" "bottom_`sub'==1" "top_`sub'==1" {
		local m `"reghdfe theta_`sub' `FE' c.(${controls_`sub'})#i.post post post_treat if attrition==0 & `cond', `OPT'"'
		global WYMODELS `"$WYMODELS `"`m'"'"'
	}
}
wyfam `B' 12
local h = 0
foreach sub in arabic french math {
	foreach g in F M bot top {
		local ++h
		local ap_`sub'_`g' = strtrim(string(r(p`h'),"%5.3f"))
	}
}

* Family C-idx: contrasts on the overall/index (2 tests: gender, baseline).
global WYMODELS ""
local m `"reghdfe theta_overall `FE' c.(${controls_overall})#i.post post post_treat fXpo fXpt if attrition==0, `OPT'"'
global WYMODELS `"$WYMODELS `"`m'"'"'
local m `"reghdfe theta_overall `FE' c.(${controls_overall})#i.post post post_treat bpo_overall bpt_overall if (bottom_overall==1|top_overall==1), `OPT'"'
global WYMODELS `"$WYMODELS `"`m'"'"'
global WYFP `""fXpt" "bpt_overall""'
wyfam `B' 2
local ap_overall_cg = strtrim(string(r(p1),"%5.3f"))
local ap_overall_cb = strtrim(string(r(p2),"%5.3f"))

* Family C-sub: contrasts within each subject (6 tests: subject x {gender, baseline}).
global WYMODELS ""
global WYFP ""
foreach sub in arabic french math {
	local m `"reghdfe theta_`sub' `FE' c.(${controls_`sub'})#i.post post post_treat fXpo fXpt if attrition==0, `OPT'"'
	global WYMODELS `"$WYMODELS `"`m'"'"'
	global WYFP `"$WYFP "fXpt""'
	local m `"reghdfe theta_`sub' `FE' c.(${controls_`sub'})#i.post post post_treat bpo_`sub' bpt_`sub' if (bottom_`sub'==1|top_`sub'==1), `OPT'"'
	global WYMODELS `"$WYMODELS `"`m'"'"'
	global WYFP `"$WYFP "bpt_`sub'""'
}
wyfam `B' 6
local h = 0
foreach sub in arabic french math {
	foreach c in cg cb {
		local ++h
		local ap_`sub'_`c' = strtrim(string(r(p`h'),"%5.3f"))
	}
}

********************************************************************************
* 5. WRITE THE THREE PANEL SNIPPETS  (columns: label & overall & (gap) & Ar & Fr & Math)
********************************************************************************
* ---- Panel A -----------------------------------------------------------------
cap file close a
file open a using "${table2a}", write replace
file write a "\textbf{Panel A: Overall} &       &       &  &  & 	\\" _n
file write a "\multicolumn{1}{l}{All students} & `b_overall_A'`st_overall_A' & & `b_arabic_A'`st_arabic_A' & `b_french_A'`st_french_A' & `b_math_A'`st_math_A' \\" _n
file write a "  & (`se_overall_A') & & (`se_arabic_A') & (`se_french_A') & (`se_math_A') \\" _n
file write a "  &  & & [`ap_arabic_A'] & [`ap_french_A'] & [`ap_math_A'] \\" _n
file close a

* ---- Panel B: gender + contrast ----------------------------------------------
cap file close b
file open b using "${table2b}", write replace
file write b "\textbf{Panel B: By gender} &       &       &  &  & 	\\" _n
* Female
file write b "\multicolumn{1}{l}{Female} & `b_overall_F'`st_overall_F' & & `b_arabic_F'`st_arabic_F' & `b_french_F'`st_french_F' & `b_math_F'`st_math_F' \\" _n
file write b "  & (`se_overall_F') & & (`se_arabic_F') & (`se_french_F') & (`se_math_F') \\" _n
file write b "  & [`ap_overall_F'] & & [`ap_arabic_F'] & [`ap_french_F'] & [`ap_math_F'] \\" _n
* Male
file write b "\multicolumn{1}{l}{Male} & `b_overall_M'`st_overall_M' & & `b_arabic_M'`st_arabic_M' & `b_french_M'`st_french_M' & `b_math_M'`st_math_M' \\" _n
file write b "  & (`se_overall_M') & & (`se_arabic_M') & (`se_french_M') & (`se_math_M') \\" _n
file write b "  & [`ap_overall_M'] & & [`ap_arabic_M'] & [`ap_french_M'] & [`ap_math_M'] \\" _n
* Female vs male
file write b "\multicolumn{1}{l}{Female vs male} & `b_overall_cg'`st_overall_cg' & & `b_arabic_cg'`st_arabic_cg' & `b_french_cg'`st_french_cg' & `b_math_cg'`st_math_cg' \\" _n
file write b "  & (`se_overall_cg') & & (`se_arabic_cg') & (`se_french_cg') & (`se_math_cg') \\" _n
file write b "  & [`ap_overall_cg'] & & [`ap_arabic_cg'] & [`ap_french_cg'] & [`ap_math_cg'] \\" _n
file close b

* ---- Panel C: baseline quartile + contrast -----------------------------------
cap file close c
file open c using "${table2c}", write replace
file write c "\textbf{Panel C: By baseline performance} &       &       &  &  & 	\\" _n
* Bottom quartile
file write c "\multicolumn{1}{l}{Bottom quartile} & `b_overall_bot'`st_overall_bot' & & `b_arabic_bot'`st_arabic_bot' & `b_french_bot'`st_french_bot' & `b_math_bot'`st_math_bot' \\" _n
file write c "  & (`se_overall_bot') & & (`se_arabic_bot') & (`se_french_bot') & (`se_math_bot') \\" _n
file write c "  & [`ap_overall_bot'] & & [`ap_arabic_bot'] & [`ap_french_bot'] & [`ap_math_bot'] \\" _n
* Top quartile
file write c "\multicolumn{1}{l}{Top quartile} & `b_overall_top'`st_overall_top' & & `b_arabic_top'`st_arabic_top' & `b_french_top'`st_french_top' & `b_math_top'`st_math_top' \\" _n
file write c "  & (`se_overall_top') & & (`se_arabic_top') & (`se_french_top') & (`se_math_top') \\" _n
file write c "  & [`ap_overall_top'] & & [`ap_arabic_top'] & [`ap_french_top'] & [`ap_math_top'] \\" _n
* Bottom vs top
file write c "\multicolumn{1}{l}{Bottom vs top} & `b_overall_cb'`st_overall_cb' & & `b_arabic_cb'`st_arabic_cb' & `b_french_cb'`st_french_cb' & `b_math_cb'`st_math_cb' \\" _n
file write c "  & (`se_overall_cb') & & (`se_arabic_cb') & (`se_french_cb') & (`se_math_cb') \\" _n
file write c "  & [`ap_overall_cb'] & & [`ap_arabic_cb'] & [`ap_french_cb'] & [`ap_math_cb'] \\" _n
file close c
