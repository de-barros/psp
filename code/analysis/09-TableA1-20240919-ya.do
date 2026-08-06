/*******************************************************************************
********************************************************************************
	                    PSP Endline Report - Table A1
********************************************************************************						
********************************************************************************

  Title:                Endline Report Table A1
  Author:               Youssef Assarssah
  Creation Date:        Sep 09 2024 (2024-09-09)
  Modification Date:    Sep 19 2024 (2024-09-19)
  Modification by:      Youssef Assarssah
  Description:          This do file takes clean data and creates table A1 of endline report.
  Purpose: 	            Data analysis, following data prep.
  Requires:             - School-level data (Dropbox/DiD - Morocco Pioneer School/4 - Data processing/Sampling/Clean/Master PSP schools)
                        - School-by-classroom level data (Dropbox/DiD - Morocco Pioneer School/4 - Data processing/Sampling/Clean/Classrooms data)
						- Clean baseline data (Dropbox/DiD - Morocco Pioneer School/4 - Data processing/Baseline/Clean)
  
  
********************************************************************************
*******************************************************************************/

********************************************************************************
**#                                Outline 
********************************************************************************
clear all
version 15.0
set more off

	* 0) Globals: Set globals for tables
	global setglobals 						"1"
	* 1) Representativeness (overall)
	global table         				    "1"  		
 			 	
	
	
********************************************************************************
**#                    Globals: Setting Globals 
********************************************************************************

if "$setglobals" == "1" {

	do "code/_setup.do"

	*---------------------------------------------------------------------------
	
	/// file globals

	** Input files
	
	// school-level data
	global input0 			"$sampling/Clean/Master PSP schools/Merged PSP Schools.dta" 
	
	// school-by-classroom level data	
	global input1 			"$sampling/Clean/Classrooms data/Schools-2023-06-13-fg.dta" 
	
	// clean baseline data
	global input2 			"$blclean/Baseline-tested-neam.dta" 

	
	// new student-level 6AP exam data (exam_average) + full school crosswalk (all schools)
	global exam6ap    "$restricted/exam_6ap/clean_exam_6AP_20260504_ll.dta"
	global xwalk_schF "$restricted/crosswalk/IDSchool.dta"

	* Temp files (generated in 1_Prep)
	global tempdata1		"${temp}/temp1.dta"	
	
	*---------------------------------------------------------------------------
	
	* Output globals - tables	
	global tablea1     				"${tables}/tablea1.txt"
	
	*---------------------------------------------------------------------------
}	

********************************************************************************
**#                    Table A1 (Final Report) 
********************************************************************************

if "$table" == "1" {
	
	*---------------------------------------------------------------------------
	
	** Firstly, we use the study schools' data (276 schools)
	
	use "$input2", clear
    bysort pair_id: egen N = nvals(school_id)
    keep if N == 2 
    collapse (sum) pair_id, by(school_id treat)
	generate drop = 0
	preserve
	
	** We generate data for the 5 dropped schools
	
	use "$input2", clear
    bysort pair_id: egen N = nvals(school_id)
    keep if N != 2 
    collapse (sum) pair_id, by(school_id treat)
    drop pair_id
	generate drop = 1
	tempfile five
    save `five', replace
	
	restore
	append using `five'
    tempfile data2
    save `data2', replace
	
	
	
	*---------------------------------------------------------------------------
	
	** We use the class-school data to retrieve the school-level variables
	
	use "$input1", clear
    keep if year ==7
	
	collapse (sum) total_enrolled girls_enrolled tayssir ss_beneficiary, by(school_id)
 	
	gen perc_female = (girls_enrolled/total_enrolled)*100
	label var perc_female "Female students (percentage, 2021/2022)"
		
	gen perc_tayssir  = (tayssir/total_enrolled)*100
	label var perc_tayssir "Qualified for Tayssir (percentage, 2021/2022)"
	replace perc_tayssir = 100 if perc_tayssir >100 & perc_tayssir<.

	gen perc_ssbenef = (ss_beneficiary/total_enrolled)*100
	replace perc_ssbenef = 100 if perc_ssbenef >100 & ss_beneficiary<.
	label var perc_ssbenef "Qualified for social security (percentage, 2021/2022)"

	rename total_enrolled total_enrolled7_sum
		
	label var total_enrolled7_sum "Total enrollment (2021/2022)"
		
	cap: drop _*
	
	*---------------------------------------------------------------------------
	
	** School-level data: 21077 schools
	preserve 
       use "$input0", clear
	   tempfile data0
	   save `data0', replace
    restore
	
	** Merge class-level data with unique school data to identify the PSP status, urban, and n° of teachers
	
	merge m:1 school_id using `data0', keepusing(urban n_teachers selected _merge_P)
	
	** We drop non matched schools from class level data

	drop if _merge ==1
	drop _merge 
	
	*---------------------------------------------------------------------------
	
	** Adding score
	
	preserve
		use cd_etab year exam_average using "$exam6ap", clear
		keep if inlist(year, 8, 9, 10)                 // 8=2020/21, 9=2021/22, 10=2022/23
		keep if exam_average < .
		collapse (mean) exam_average, by(cd_etab year)  // school-year mean (student-weighted)
		merge m:1 cd_etab using "$xwalk_schF", keepusing(school_id) keep(match) nogen
		reshape wide exam_average, i(school_id) j(year)
		rename (exam_average8 exam_average9 exam_average10) (exam_2021 exam_2122 exam_2223)
		label var exam_2021 "Average final grade-6 score (2020/2021)"
		label var exam_2122 "Average final grade-6 score (2021/2022)"
		label var exam_2223 "Average final grade-6 score (2022/2023)"	
		tempfile data1
		save `data1', replace
	restore
	
	** Merging to get the score varibale
	
	merge m:1 school_id using `data1'
	drop if _merge ==2
	drop _merge	
	
	*---------------------------------------------------------------------------
	
	* Generate additional variables: Study, PSP
	merge m:1 school_id using `data2'
	gen study =.
	replace study = 1 if treat !=. & drop == 0
	replace study = 0 if treat ==. | drop == 1
	label define study_label 0 "Not in Study" 1 "In Study"
	label values study study_label

	gen psp =.
	replace psp = 0
	replace psp = 1 if  selected == 1
	label define psp_label 0 "Non PSP School" 1 "PSP School"
	label values psp psp_label

	*---------------------------------------------------------------------------
	
	** Treatment variable label is wrong: we have untreated school are PSP and treated are not
	
	tab treat psp if study == 1
	
	** We change the treat label
	
	label define treat_label 0 "Untreated" 1 "Treated"
	label values treat treat_label

	*---------------------------------------------------------------------------
	
	** Create match pair grade

	preserve 
  	   use "$input2", clear
  	   bysort pair_id: egen N = nvals(school_id)
  	   keep if N == 2
  	   egen match_pair_grade = group(pair_id grade)
  	   tempfile pair
  	   save `pair'
	restore
	
	drop _merge

	*---------------------------------------------------------------------------
	
	** Define our variables
	
	global varlist n_teachers urban total_enrolled7_sum perc_female perc_tayssir perc_ssbenef exam_2021 exam_2122 exam_2223
	

    *---------------------------------------------------------------------------
	
    ** Create a text file

    file open a using "$tablea1", write replace

    foreach var in $varlist {
		local var_label : variable label `var'

		*-----------------------------------------------------------------------
		
	**# Representativeness (overall)
	
	**## Study 
	
		qui summ `var' if study == 1
		local study_m`var' : dis %3.2f round(r(mean), 0.01)
		local study_sd`var' : dis %3.2f round(r(sd), 0.01)

	**## Non-Study 
	
		qui summ `var' if study == 0
		local nstudy_m`var' : dis %3.2f round(r(mean), 0.01)
		local nstudy_sd`var' : dis %3.2f round(r(sd), 0.01)
	
	**## Difference
	
		qui reg `var' study
		local s_coef`var' : dis %3.2f round(_b[study], 0.01)
    	local s_se`var' : dis %3.2f round(_se[study], 0.01)
		local streat_t = _b[study] / _se[study]
		local study_p`var' = 2 * ttail(e(df_r), abs(`streat_t'))
		
		
	// Significance stars
	
    	local studystars`var' = cond(`study_p`var'' < 0.01, "***", cond(`study_p`var'' < 0.05, "**", cond(`study_p`var'' < 0.10, "*", "")))
	
	*---------------------------------------------------------------------------
	
	**# Representativeness (within PSP)
	
	**## Study-PSP 
	
		qui summ `var' if psp == 1 & study == 1
		local pstudy_m`var' : dis %3.2f round(r(mean), 0.01)
		local pstudy_sd`var' : dis %3.2f round(r(sd), 0.01)

	**## Other PSP
	
		qui summ `var' if psp == 1 & study == 0
		local pnstudy_m`var' : dis %3.2f round(r(mean), 0.01)
		local pnstudy_sd`var' : dis %3.2f round(r(sd), 0.01)
	
	**## Difference
	
		qui reg `var' study if psp == 1
		local ps_coef`var' : dis %3.2f round(_b[study], 0.01)
    	local ps_se`var' : dis %3.2f round(_se[study], 0.01)
		local pstreat_t = _b[study] / _se[study]
		local pstudy_p`var' = 2 * ttail(e(df_r), abs(`pstreat_t'))
	
	// Significance stars
	
    	local pstudystars`var' = cond(`pstudy_p`var'' < 0.01, "***", cond(`pstudy_p`var'' < 0.05, "**", cond(`pstudy_p`var'' < 0.10, "*", "")))
	
	*---------------------------------------------------------------------------
	
	**# Balance
	
	**## Comparaison 
	
		qui summ `var' if treat == 0
		local com_m`var' : dis %3.2f round(r(mean), 0.01)
		local com_sd`var' : dis %3.2f round(r(sd), 0.01)
	
	**## Difference
	
		qui areg `var' treat if study == 1, absorb(pair_id) 
		local comp_coef`var' : dis %3.2f round(_b[treat], 0.01)
    	local comp_se`var' : dis %3.2f round(_se[treat], 0.01)
		local comptreat_t = _b[treat] / _se[treat]
		local comp_p`var' = 2 * ttail(e(df_r), abs(`comptreat_t'))
		
	
	// Significance stars
    	local compstars`var' = cond(`comp_p`var'' < 0.01, "***", cond(`comp_p`var'' < 0.05, "**", cond(`comp_p`var'' < 0.10, "*", "")))
		
	*---------------------------------------------------------------------------
	
	// Write results to segment txt

		file write a "`var_label' &       & `study_m`var''  & `nstudy_m`var''  & `s_coef`var''`studystars`var'' &       & `pstudy_m`var''  & `pnstudy_m`var''  & `ps_coef`var''`pstudystars`var''&       & `com_m`var''  & `comp_coef`var''`compstars`var'' \\" _n
    	file write a     " &       & [`study_sd`var'']  & [`nstudy_sd`var'']  & (`s_se`var'') &       & [`pstudy_sd`var'']  & [`pnstudy_sd`var'']  & (`ps_se`var'') &       & [`com_sd`var'']  & (`comp_se`var'') \\" _n
		
		}
		
		
	file close a
	
	}