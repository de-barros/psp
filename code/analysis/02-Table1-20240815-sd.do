*******************************************************************************
* Author: Sarah Deschênes
* Date Created: 7 Aug 2024
* Last Modified by: 
* Creates table 1 of the PAP of DiD Morocco Pioneer School Project
********************************************************************************

********************************************************************************
                                 * Analysis *
********************************************************************************

clear 		all 
set more 	off 
set 		seed 2816 
version 	18

global setglobals	  "1"

* Note: For now, we're commenting out the GPA line due to data issues with this dataset / variable. Later, remove any "*gpa" to bring this line back in.

********************************************************************************
                  * Set file directories as globals *
********************************************************************************

if $setglobals==1 {

	do "code/_setup.do"

	// Clean input files
	//global input1			"$blclean/Baseline-tested-neam.dta" // clean baseline data
	//global input2 			"$blclean/Archives/Baseline-all-data.dta" // all observations, including duplicates and absent students
	
	// Temp files
	global temp6			"$eltemp/temp6.dta" // long data with all test scores	
	
	// Table
	global table1			"${tables}/table1.txt" // table1 PAP: Baseline balance

}

********************************************************************************
							* TABLE 1 *
********************************************************************************
use "$temp6", clear

* create matched pair by grade indicator variable
egen temp = concat(grade pair_id), punct("-")
unique(temp) // we should have 828 matched pair by grade and we have 827
encode temp, gen(match_pair_grade)
drop temp

* check that the matched pair by grade identifier is unique
preserve
bys grade pair_id: gen temp2 =_n
keep if temp2 == 1
isid(match_pair_grade)
restore

label var match_pair_grade "Matched-pair by grade id"

//rename gpa score

global varlist "gender repeated tayssir theta_arabic theta_french theta_math attrition"
// global varlist "gender repeated score tayssir theta_arabic theta_french theta_math attrition"

gen fem = female * 100
gen rep = repeated * 100
gen tay = tayssir * 100
gen att = attrition * 100
gen scoa = theta_arabic
gen scof = theta_french
gen scom = theta_math

//global varlistdup "fem rep score tay scoa scof scom att"
global varlistdup "fem rep tay scoa scof scom att"

global treat "Untreated Treated"

preserve
keep if baseline == 1

// Record the sample size, mean and sd at baseline as locals for each subject in control group
// Record sample size at baseline for treated group
// 1. Arabic, 2. French, 3. Math
forvalues i = 1/3 {
	foreach var of global varlistdup {
		qui: sum `var' if subject == `i' & treated == 0
		local untreated_`var'`i'_count: di %12.0f `r(N)'
		local untreated_`var'`i'_mean: di %12.2f r(mean)
		local untreated_`var'`i'_meanse: di %12.2f r(sd)
		local untreated_`var'`i'_meanse `untreated_`var'`i'_meanse'
		
		qui: sum `var' if subject == `i' & treated == 1
		local treated_`var'`i'_count: di %12.0f `r(N)'		
		}

	foreach var of global varlistdup {
		capture: qui: areg `var' treated if subject == `i', absorb(match_pair_grade) vce(cluster pair_id)
		if _rc == 2000 {
			continue
		}
		if _rc == 0 {
			
			local tc_`var'_`i' = _b[treated]
			local tc_`var'_`i' : di %12.2f `tc_`var'_`i''
			local tc_`var'_`i' `tc_`var'_`i''
			
			local tc_`var'_se_`i' = _se[treated]
			local tc_`var'_se_`i' : di %12.2f `tc_`var'_se_`i''
			local tc_`var'_se_`i' `tc_`var'_se_`i''
			
			local t = _b[treated] / _se[treated]
			local pval = 2 * ttail(e(df_r), abs(`t'))
		
			if `pval' <= 0.01 {
				local tc_`var'_sig_`i' "***"
				}
			else if `pval' <= 0.05 {
				local tc_`var'_sig_`i' "**"
				}
			else if `pval' <= 0.10 {
				local tc_`var'_sig_`i' "*"
				}
			else {
				local tc_`var'_sig_`i' ""
				}
		}
	}	

	
	if `i' == 1 {
		qui: areg treated theta_arabic female repeated tayssir attrition if subject == `i', absorb(match_pair_grade) vce(cluster pair_id)
		qui test
		local ft_pval`i': di %12.2f `r(p)'
		}
	else if `i' == 2 {
		qui: areg treated theta_french female repeated tayssir attrition if subject == `i', absorb(match_pair_grade) vce(cluster pair_id)
		qui test
		local ft_pval`i': di %12.2f `r(p)'
		}	
	else {
		qui: areg treated theta_math female repeated tayssir attrition if subject == `i', absorb(match_pair_grade) vce(cluster pair_id)
		qui test
		local ft_pval`i': di %12.2f `r(p)'
		}	

	}

restore

// Write table to .txt file (to be used in LaTeX)
cap: file close a
cap: erase "${table1}"
		
file open a using "${table1}" , write append

forvalues i = 1/3 { 
	if `i' == 1 {
		*-----------------------------------------------------------------------
		* Panel A
		file write a "\multicolumn{1}{l}{\textbf{Panel A: Arabic}} &      &       &  	&  & &	\\"  _n

		file write a "\multicolumn{1}{l}{\% Female} &  & `untreated_fem`i'_count'	&  `treated_fem`i'_count'   &  & `untreated_fem`i'_mean' &  `tc_fem_`i''`tc_fem_sig_`i'' \\" _n
		file write a "	& 	&   &  & & [`untreated_fem`i'_meanse'] &  (`tc_fem_se_`i'')  \\" _n
		
		file write a "\multicolumn{1}{l}{\% Ever repeated} &  & `untreated_rep`i'_count'	&  `treated_rep`i'_count'   &  &`untreated_rep`i'_mean' &  `tc_rep_`i''`tc_rep_sig_`i'' \\" _n
		file write a "	& 	&   & & & [`untreated_rep`i'_meanse'] &  (`tc_rep_se_`i'')  \\" _n
		
*gpa		file write a "\multicolumn{1}{l}{Grade point average} &  & `untreated_score`i'_count'	&  `treated_score`i'_count'   & &  `untreated_score`i'_mean' &  `tc_score_`i''`tc_score_sig_`i'' \\" _n
*gpa		file write a "	& 	&   & & & [`untreated_score`i'_meanse'] &  (`tc_score_se_`i'')  \\" _n
		
		file write a "\multicolumn{1}{l}{\% Qualified for Tayssir} &   & `untreated_tay`i'_count'	&  `treated_tay`i'_count'  &  &  `untreated_tay`i'_mean' &  `tc_tay_`i''`tc_tay_sig_`i'' \\" _n
		file write a "	& 	&   & 	& 	& [`untreated_tay`i'_meanse'] &  (`tc_tay_se_`i'')  \\" _n	
		
		file write a "\multicolumn{1}{l}{Baseline test score} &  & `untreated_scoa`i'_count' &  `treated_scoa`i'_count' &  &  `untreated_scoa`i'_mean' &  `tc_scoa_`i''`tc_scoa_sig_`i'' \\" _n
		file write a "	& 	&   &	&	& [`untreated_scoa`i'_meanse'] &  (`tc_scoa_se_`i'')  \\" _n			
		file write a "\multicolumn{1}{l}{\% Attrited} &	& `untreated_att`i'_count'	&  `treated_att`i'_count'   &  & `untreated_att`i'_mean' &  `tc_att_`i''`tc_att_sig_`i'' \\" _n
		file write a "	& 	&   &  & & [`untreated_att`i'_meanse'] &  (`tc_att_se_`i'')  \\" _n
		
		file write a "Joint F-test (p-value) & 	&   &   &	&	& `ft_pval`i'' \\" _n
		
		file write a " & 	&   &   &	&	&  \\" _n		
	 	}
	else if `i' == 2 {
		*-----------------------------------------------------------------------
		* Panel B
		file write a "\multicolumn{1}{l}{\textbf{Panel B: French}} &       &       &  	&	&	&	\\"  _n

		file write a "\multicolumn{1}{l}{\% Female} &  & `untreated_fem`i'_count'	&  `treated_fem`i'_count'   &  & `untreated_fem`i'_mean' &  `tc_fem_`i''`tc_fem_sig_`i'' \\" _n
		file write a "	& 	&   &  & & [`untreated_fem`i'_meanse'] &  (`tc_fem_se_`i'')  \\" _n
		
		file write a "\multicolumn{1}{l}{\% Ever repeated} &  & `untreated_rep`i'_count'	&  `treated_rep`i'_count'   &  &`untreated_rep`i'_mean' &  `tc_rep_`i''`tc_rep_sig_`i'' \\" _n
		file write a "	& 	&   & & & [`untreated_rep`i'_meanse'] &  (`tc_rep_se_`i'')  \\" _n
		
*gpa		file write a "\multicolumn{1}{l}{Grade point average} &  & `untreated_score`i'_count'	&  `treated_score`i'_count'   & &  `untreated_score`i'_mean' &  `tc_score_`i''`tc_score_sig_`i'' \\" _n
*gpa		file write a "	& 	&   & & & [`untreated_score`i'_meanse'] &  (`tc_score_se_`i'')  \\" _n
		
		file write a "\multicolumn{1}{l}{\% Qualified for Tayssir} &   & `untreated_tay`i'_count'	&  `treated_tay`i'_count'  &  &  `untreated_tay`i'_mean' &  `tc_tay_`i''`tc_tay_sig_`i'' \\" _n
		file write a "	& 	&   & 	& 	& [`untreated_tay`i'_meanse'] &  (`tc_tay_se_`i'')  \\" _n	
		
		file write a "\multicolumn{1}{l}{Baseline test score} &  & `untreated_scof`i'_count' &  `treated_scof`i'_count' &  &  `untreated_scof`i'_mean' &  `tc_scof_`i''`tc_scof_sig_`i'' \\" _n
		file write a "	& 	&   &	&	& [`untreated_scof`i'_meanse'] &  (`tc_scof_se_`i'')  \\" _n			
		file write a "\multicolumn{1}{l}{\% Attrited} &	& `untreated_att`i'_count'	&  `treated_att`i'_count'   &  & `untreated_att`i'_mean' &  `tc_att_`i''`tc_att_sig_`i'' \\" _n
		file write a "	& 	&   &  & & [`untreated_att`i'_meanse'] &  (`tc_att_se_`i'')  \\" _n
		
		file write a "Joint F-test (p-value) 	& 	&   &   &	&	& `ft_pval`i'' \\" _n	
		file write a " & 	&   &   &	&	&  \\" _n				
		}	
	else if `i' == 3 {
		*-----------------------------------------------------------------------
		* Panel C
		file write a "\multicolumn{1}{l}{\textbf{Panel C: Math}} &       &       &  	& & &	\\"  _n

		file write a "\multicolumn{1}{l}{\% Female} &  & `untreated_fem`i'_count'	&  `treated_fem`i'_count'   &  & `untreated_fem`i'_mean' &  `tc_fem_`i''`tc_fem_sig_`i'' \\" _n
		file write a "	& 	&   &  & & [`untreated_fem`i'_meanse'] &  (`tc_fem_se_`i'')  \\" _n
		
		file write a "\multicolumn{1}{l}{\% Ever repeated} &  & `untreated_rep`i'_count'	&  `treated_rep`i'_count'   &  &`untreated_rep`i'_mean' &  `tc_rep_`i''`tc_rep_sig_`i'' \\" _n
		file write a "	& 	&   & & & [`untreated_rep`i'_meanse'] &  (`tc_rep_se_`i'')  \\" _n
		
*gpa		file write a "\multicolumn{1}{l}{Grade point average} &  & `untreated_score`i'_count'	&  `treated_score`i'_count'   & &  `untreated_score`i'_mean' &  `tc_score_`i''`tc_score_sig_`i'' \\" _n
*gpa		file write a "	& 	&   & & & [`untreated_score`i'_meanse'] &  (`tc_score_se_`i'')  \\" _n
		
		file write a "\multicolumn{1}{l}{\% Qualified for Tayssir} &   & `untreated_tay`i'_count'	&  `treated_tay`i'_count'  &  &  `untreated_tay`i'_mean' &  `tc_tay_`i''`tc_tay_sig_`i'' \\" _n
		file write a "	& 	&   & 	& 	& [`untreated_tay`i'_meanse'] &  (`tc_tay_se_`i'')  \\" _n	
		
		file write a "\multicolumn{1}{l}{Baseline test score} &  & `untreated_scom`i'_count' &  `treated_scom`i'_count' &  &  `untreated_scom`i'_mean' &  `tc_scom_`i''`tc_scom_sig_`i'' \\" _n
		file write a "	& 	&   &	&	& [`untreated_scom`i'_meanse'] &  (`tc_scom_se_`i'')  \\" _n			
		file write a "\multicolumn{1}{l}{\% Attrited} &	& `untreated_att`i'_count'	&  `treated_att`i'_count'   &  & `untreated_att`i'_mean' &  `tc_att_`i''`tc_att_sig_`i'' \\" _n
		file write a "	& 	&   &  & & [`untreated_att`i'_meanse'] &  (`tc_att_se_`i'')  \\" _n
		
		file write a "Joint F-test (p-value) 	& 	&   &   &	&	& `ft_pval`i'' \\" _n		
		}	
}

file close a
