
********************************************************************************
* Author : Andy de Barros
* Date Created: 27 Aug 2025
* Last Modified by: Andy de Barros
* Creates figure A1 of the paper (adding to the in-text statistics, which together replace Table 2 of the pre-registration)
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
global figa1   	  	"1" // Generate the Appendix figure

********************************************************************************
                  * Set file directories as globals *
********************************************************************************

if $setglobals == 1 {
	
	do "code/_setup.do"

	global monitor      	"${work}/DiD - Morocco Pioneer School/4 - Data processing/Process monitoring (INE)"

	// Clean input files
	
	global input0 			"$sampling/Clean/Master PSP schools/Merged PSP Schools.dta" // school-level data
	global input1 			"$sampling/Clean/Classrooms data/Schools-2023-06-13-fg.dta" // school-by-classroom level data
	global input2 			"$blclean/Baseline-tested-neam.dta" // clean baseline data
	global input3 			"$elclean/Endline-tested-neam.dta" // clean endline data
	global input4 			"$sampling/Selected schools/Regional and outcome strata/Evaluation sample (300 schools).dta" // school sample
	global input5 			"$sampling/Clean/Student test scores/testscore-2023-06-13.dta" // admin data with student end-of-year test scores
	global input6 			"$monitor/Clean/headmaster_20250826.dta" // headmaster interviews
	
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
	global figurea1 		"$figures/figurea1.pdf" // Appendix Figure A1
	
	// Controls (to be picked by Lasso)
	global pupilcon "female grade1 grade2 grade3 grade4 grade5 grade6 tayssir" // student controls
	global schoolcon "n_teachers urban regional_dev total_enrolled7_sum perc_female perc_tayssir avg_score7_mu perc_ssbenef" // school controls  
	global controls "$pupilcon $schoolcon" // all controls
	
	// Dependent variables
	global panel1deps "wrc_arabic theta_arabicat theta_arabicbelow"
	global panel2deps "wrc_french"
	global panel3deps "theta_mathat theta_mathbelow theta_numbers theta_geometry theta_knowing theta_applying theta_numgeo"
	
}

********************************************************************************
                         * Generate the Appendix Figure *
********************************************************************************

if ${figa1} == 1 {
	
	use "${input6}", clear
	
	graph set window fontface "Garamond"
	set scheme cleanplots                      // paper figure scheme (vendored in code/ado/s/)

	histogram num_tarl_days, width(1) fcolor(navy) lcolor(navy) xtitle("Number of days") ytitle("Proportion of schools")
	
	graph export "$figurea1", replace
	graph export "$figures/figurea1.png", replace width(2000)
	
}	

