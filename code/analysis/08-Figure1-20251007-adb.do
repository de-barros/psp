
********************************************************************************
* Author : Andy de Barros
* Date Created: 15 Aug 2024
* Last Modified: 6 Jul 2026 -- Figure 1 is now a 2x2 of parallel-trends panels:
*   overall (a) plus Arabic / French / Math (b-d), each built on the student-level
*   6AP exam data, 276 study schools via the cd_etab crosswalk, matched-pair-
*   clustered means, a common y-axis, 2014/15-2022/23. Panels are exported
*   separately as figure1_<overall|arabic|french|math>.pdf and assembled 2x2 in
*   paper/figures/figure1.tex.
* Analyzes data for DiD Morocco Pioneer School Project, generates Figure 1
********************************************************************************

********************************************************************************
                                 * Analysis *
********************************************************************************

clear 		all
set more 	off
set 		seed 2816
version 	18

global setglobals	  "1"

** Analyis Globals
global fig1   	  "1" // Figure 1

********************************************************************************
                  * Set file directories as globals *
********************************************************************************

if $setglobals==1 {

	do "code/_setup.do"

	// Clean input files

	global input0 			"$sampling/Clean/Master PSP schools/Merged PSP Schools.dta" // school-level data
	global input1 			"$sampling/Clean/Classrooms data/Schools-2023-06-13-fg.dta" // school-by-classroom level data
	global input2 			"$blclean/Baseline-tested-neam.dta" // clean baseline data (school_id, treat, pair_id)
	global input3 			"$elclean/Endline-tested-neam.dta" // clean endline data
	global input4 			"$sampling/Selected schools/Regional and outcome strata/Evaluation sample (300 schools).dta" // school sample
	global input5 			"$sampling/Clean/Student test scores/testscore-2023-06-13.dta" // admin data with student end-of-year test scores
	global input6 			"$sampling/Raw/No PII/Classrooms data/studentclasses-2023-06-13-fg.dta" // (superseded) classroom-level grade-6 exam scores; no longer used by Figure 1
	global exam6ap 			"$restricted/exam_6ap/clean_exam_6AP_20260504_ll.dta"      // student-level 6AP exam data (exam_average) -- Figure 1 source
	global xwalk_sch 		"$restricted/crosswalk/IDSchool_effective_sample_neam.dta" // cd_etab <-> school_id for the 276 study schools

	// Temp files
	global temp1 			"$eltemp/temp1.dta" // temp file
	global temp2 			"$eltemp/temp2.dta" // temp file
	global temp3 			"$eltemp/temp3.dta" // long data with Arabic test scores
	global temp4 			"$eltemp/temp4.dta" // long data with French test scores
	global temp5 			"$eltemp/temp5.dta" // long data with Math test scores
	global temp6 			"$eltemp/temp6.dta" // long data with all test scores, demographics, and school background information
	global temp7 			"$eltemp/temp7.dta" // wide test-score residuals, used in causal forests

	// Tables
	* n/a

	// Figures
	global figure1 			"$figures/figure1.pdf" // parallel trends in grade-6 exam scores, 276 study schools

}

********************************************************************************
                         * Figure 1 *
********************************************************************************

if $fig1== 1 {

	set scheme cleanplots                      // paper figure scheme (vendored in code/ado/s/)
	graph set window fontface "Garamond"       // serif font, to match the paper figures

	*--- 276 study schools: school-level treatment + matched pair, bridged to cd_etab ---
	use "$input2", clear                                       // baseline: school_id, treat, pair_id
	bysort school_id: keep if _n==1
	keep school_id treat pair_id
	rename treat treated
	merge 1:1 school_id using "$xwalk_sch", keep(match) nogen  // -> cd_etab (the 276 study schools)
	assert !missing(pair_id) & _N==276
	tempfile schools276
	save `schools276'

	*--- NEW student-level grade-6 (6AP) exam data (overall + the 3 targeted subjects) ---
	use cd_etab year exam_average exam_ar exam_fr exam_math using "$exam6ap", clear
	keep if inrange(year, 2, 10)                               // 2014/15..2022/23 (pre-program); 2019/20 (=7) has no exam
	merge m:1 cd_etab using `schools276', keep(match) nogen    // restrict to the 276 study schools
	tempfile exdata
	save `exdata'

	*--- one parallel-trends panel per outcome: overall, then Arabic / French / Math.
	*    Same estimator, window, and Covid gap as before, on a COMMON y-axis across
	*    panels; each is exported separately and assembled 2x2 in paper/figures/figure1.tex.
	*    The overall panel is also written to figure1.pdf so the single-panel wrapper
	*    fallback stays current. ---
	local outc  "exam_average exam_ar exam_fr exam_math"
	local names "overall arabic french math"
	local nout : word count `outc'
	forvalues k = 1/`nout' {
		local y  : word `k' of `outc'
		local nm : word `k' of `names'

		use `exdata', clear
		keep if `y' < .

		reg `y' i.year##i.treated, vce(cluster pair_id)         // year-by-group means, matched-pair-clustered SEs
		levelsof year, local(yrs)
		tempname pf
		tempfile res
		postfile `pf' byte treated int year double avg_score double se using `res', replace
		foreach yy of local yrs {
			forvalues t = 0/1 {
				margins, at(year=`yy' treated=`t')
				post `pf' (`t') (`yy') (el(r(b),1,1)) (sqrt(el(r(V),1,1)))
			}
		}
		postclose `pf'
		use `res', clear
		gen lower = avg_score - 1.96 * se                       // 95% CI (matched-pair-clustered)
		gen upper = avg_score + 1.96 * se

		twoway (rarea lower upper year if treated==0, color(blue%15)) ///
		       (rarea lower upper year if treated==1, color(red%15))  ///
		       (line  avg_score  year if treated==0, lc(blue))        ///
		       (line  avg_score  year if treated==1, lc(red)),        ///
		       ytitle("Average grade-6 score", size(small)) ylabel(3(1)7, labsize(small)) ///
		       xtitle("") ///
		       xlabel(2 "2014/15" 3 "2015/16" 4 "2016/17" 5 "2017/18" 6 "2018/19" ///
		              7 "Covid year" 8 "2020/21" 9 "2021/22" 10 "2022/23", labsize(vsmall) angle(45)) ///
		       legend(order(1 "Comparison" 2 "Program") size(small) rows(1))
		graph export "$figures/figure1_`nm'.pdf", replace
		if "`nm'" == "overall" graph export "$figure1", replace
		graph close
	}
}
