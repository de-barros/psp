
********************************************************************************
* Author : Andy de Barros
* Date Created: 15 Aug 2024
* Last Modified by: Andy de Barros
* Creates table A4 of the PAP of DiD Morocco Pioneer School Project (A3 in the paper, since there is no differential attrition)
********************************************************************************

********************************************************************************
                                 * Analysis *
********************************************************************************

clear 		all 
set more 	off 
set 		seed 2816 
version 	16

global setglobals	"1"

** Analyis Globals
global taba4   	  	"1" // Generate the Appendix table

********************************************************************************
                  * Set file directories as globals *
********************************************************************************

if $setglobals == 1 {
	
	do "code/_setup.do"
	sysdir set PLUS "$code/ado"   // vendored pdslasso/reghdfe, as in 04-Table3

	// Clean input files
	
	global input0 			"$sampling/Clean/Master PSP schools/Merged PSP Schools.dta" // school-level data
	global input1 			"$sampling/Clean/Classrooms data/Schools-2023-06-13-fg.dta" // school-by-classroom level data
	global input2 			"$blclean/Baseline-tested-neam.dta" // clean baseline data
	global input3 			"$elclean/Endline-tested-neam.dta" // clean endline data
	global input4 			"$sampling/Selected schools/Regional and outcome strata/Evaluation sample (300 schools).dta" // school sample
	global input5 			"$sampling/Clean/Student test scores/testscore-2023-06-13.dta" // admin data with student end-of-year test scores
	
	// Temp files	
	global temp1 			"$eltemp/temp1.dta" // temp file
	global temp2 			"$eltemp/temp2.dta" // temp file
	global temp3 			"$eltemp/temp3.dta" // long data with Arabic test scores
	global temp4 			"$eltemp/temp4.dta" // long data with French test scores
	global temp5 			"$eltemp/temp5.dta" // long data with Math test scores
	global temp6 			"$eltemp/temp6.dta" // long data with all test scores
	global temp7 			"$eltemp/temp7.dta" // wide test-score residuals, used in causal forests 
	
	// Tables
	* n/a
	global tablea3_1 		"$tables/tablea3_1.txt" // Table snippet to be used in Overleaf, Panel A
	global tablea3_2 		"$tables/tablea3_2.txt" // Table snippet to be used in Overleaf, Panel B
	global tablea3_3 		"$tables/tablea3_3.txt" // Table snippet to be used in Overleaf, Panel C
	
	// Figures
	* n/a
	
	// Controls (to be picked by Lasso)
	global pupilcon "female grade1 grade2 grade3 grade4 grade5 grade6 gpa repeated tayssir theta_baseline" // student controls
	global schoolcon "n_teachers urban regional_dev total_enrolled7_sum perc_female perc_tayssir avg_score7_mu perc_ssbenef" // school controls  
	global controls "$pupilcon $schoolcon" // all controls
	
	// Dependent variables
	global panel1deps "wrc_arabic theta_arabicat theta_arabicbelow"
	global panel2deps "wrc_french"
	global panel3deps "theta_mathat theta_mathbelow theta_numbers theta_geometry theta_knowing theta_applying theta_numgeo"
	
}

********************************************************************************
                         * Select covariates *
********************************************************************************

// Post-double-selection LASSO control selection, replicated from 04-Table3 so
// this dofile runs on its own. This is the fast rlasso selection only; it is NOT
// the days-long Westfall-Young bootstrap, which lives only in 04-Table3. It
// reproduces the same controls_arabic/french/math the regressions below use.

use "$temp6", clear

// Baseline score for each subject (a candidate control), as in 04-Table3
gen theta_baseline = .
replace theta_baseline = theta_arabic if subject == 1 & baseline == 1
replace theta_baseline = theta_french if subject == 2 & baseline == 1
replace theta_baseline = theta_math   if subject == 3 & baseline == 1
bysort student_id: egen max = max(theta_baseline)
bys student_id: replace theta_baseline = max if max<.
drop max

keep if attrition == 0
xtset student_id post
foreach sub in arabic french math {
	cap drop change_`sub' res_score_`sub'
	gen change_`sub' = D.theta_`sub'
	qui: reg change_`sub' i.grade##i.pair_id if treated == 0, cluster(pair_id)
	predict res_score_`sub', residuals
	pdslasso res_score_`sub' treated ($pupilcon $schoolcon), cluster(pair_id)
	global controls_`sub' "`e(xselected)'"
	di as txt "Selected controls (`sub'): ${controls_`sub'}"
}

********************************************************************************
                         * Generate the Appendix Table *
********************************************************************************

if ${taba4} == 1 {
	
	use "${temp6}", replace

	// create predictor of interest (post X Treated)
	gen post_treat = post * treated
	label var post_treat "Predictor of Interest"
	
	// Re-label variables, to match what we want in the table
	
	label var wrc_arabic "Words read correctly / minute"
	label var wrc_french "Words read correctly / minute"
	
	label var theta_arabicat "At grade"
	label var theta_arabicbelow "Below grade"
	
	label var theta_mathat "At grade"
	label var theta_mathbelow "Below grade"	
	
	label var theta_numbers "Calculation and numeracy"
	label var theta_geometry "Geometry, measures, and data"
	label var theta_knowing "Knowing"
	label var theta_applying "Applying and reasoning"
	label var theta_numgeo "Equal weights to content domains"
	
	// Add variable with the baseline score for each subject
	gen theta_baseline = .
	replace theta_baseline = theta_arabic if subject == 1 & baseline == 1
	replace theta_baseline = theta_french if subject == 2 & baseline == 1
	replace theta_baseline = theta_math if subject == 3 & baseline == 1

	bysort student_id: egen max = max(theta_baseline)
	bys student_id: replace theta_baseline = max if max<.
	drop max	
	
	// Loop over three panels, write three .txt snippets (one per panel)
	
	forvalues k = 1/3 {
		
		local sub = word("arabic french math", `k')
			
		// Panel `k'
		cap: file close a
		cap: erase "${tablea3_`k'}"
				
		file open a using "${tablea3_`k'}" , write append	
		
		foreach var of global panel`k'deps {
			
			local lab: variable label `var'
			
			// Column 1: all students (grades 1-6)
			reghdfe `var' i.post#i.grade#i.pair_id i.post#i.grade i.post#i.pair_id c.(${controls_`sub'})#i.post post post_treat if attrition == 0, absorb(student_id) vce(cluster pair_id)
			local b1  : di %12.2f _b[post_treat]
			local se1 : di %12.2f _se[post_treat]
			qui: lincom post_treat
			local a1 = cond(`r(p)'<=0.01,"***",cond(`r(p)'<=0.05,"**",cond(`r(p)'<=0.10,"*","")))
			local b1  = trim("`b1'")
			local se1 = trim("`se1'")
			
			// Column 2: grade 6 only (same spec; collinear cell FE dropped by reghdfe)
			local b2 ""
			local se2 ""
			local a2 ""
			cap reghdfe `var' i.post#i.grade#i.pair_id i.post#i.grade i.post#i.pair_id c.(${controls_`sub'})#i.post post post_treat if attrition == 0 & grade == 6, absorb(student_id) vce(cluster pair_id)
			if _rc == 0 & e(N) > 0 {
				local b2  : di %12.2f _b[post_treat]
				local se2 : di %12.2f _se[post_treat]
				qui: lincom post_treat
				local a2 = cond(`r(p)'<=0.01,"***",cond(`r(p)'<=0.05,"**",cond(`r(p)'<=0.10,"*","")))
				local b2  = trim("`b2'")
				local se2 = "(" + trim("`se2'") + ")"
			}
			
			file write a "`lab' &   `b1'`a1' & `b2'`a2' \\"  _n
			file write a " &   (`se1') & `se2' \\"  _n
			
		}
	
		file close a
	
	}
	
	
}


