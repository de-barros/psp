
********************************************************************************
* Author : Andy de Barros
* Date Created: 03 Aug 2024
* Last Modified by: Andy de Barros
* Analyzes data for DiD Morocco Pioneer School Project, generates IRT scores
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
global irta   	  "1" // IRT analysis Arabic
global irtf   	  "1" // IRT analysis French
global irtm   	  "1" // IRT analysis math
global egr   	  "1" // EGRA analysis 
global comb   	  "1" // Combine all three estimates
global resid   	  "1" // Create datasets with test-score residuals, for causal forests
	global measure	  "1" // Appendix B measurement exhibits (Table B1, Figure B1)

********************************************************************************
                  * Set file directories as globals *
********************************************************************************

if $setglobals==1 {

	do "code/_setup.do"

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
	global temp6 			"$eltemp/temp6.dta" // long data with all test scores, demographics, and school background information
	global temp7 			"$eltemp/temp7.dta" // wide test-score residuals, used in causal forests 
	global temp8 			"$eltemp/percent_correct.xlsx" // percent correct by round, grade, and subject 
	
	// Tables
	* n/a
	* global table1 			"$tables/data_irregularities.txt" // all observations, excluding duplicates and absent students	
	
	// Figures
	* n/a
	
}

********************************************************************************
                         * IRT analysis Arabic *
********************************************************************************

if $irta== 1 {

	// Dropping five schools without a match

	* Baseline
	use "$input2", clear
	bysort pair_id school_id: keep if _n ==1
	bysort pair_id: gen N = _N
	drop if N ==1
	tempfile tf 
	save `tf', replace
	use "$input2", clear
	merge m:1 pair_id school_id using `tf', keepusing(pair_id school_id)
	drop if _m !=3
	drop _m
	gen baseline = 1

	* Replacing all don't knows with 0
	foreach var of varlist a* {
		* tab `var' if `var' != ., m
		replace `var' = 0 if `var' == .a
	}

	* Dropping all non-binary variables (EGRA)

	drop a110 a111 a112 a121 a122 a123 a124 a125 a126 a127 a128 a129 a143 a144 a145 a146 a147 a148 a160 a161 a162 a163 a164 a165 a188 a189 a190 a191 a192 a193 a1126 a1127 a1128 a1129 a1130 a1131

	save "$temp1"  , replace

	* Endline
	use "$input3", clear

	merge 1:1 student_id using "$temp1", keepusing(student_id)
	keep if _m ==3 
	drop _m

	merge m:1 pair_id school_id using `tf', keepusing(pair_id school_id)
	drop if _m !=3
	drop _m
	gen baseline = 0

	* Replacing all don't knows with 0
	foreach var of varlist a* {
		* tab `var' if `var' != ., m
		replace `var' = 0 if `var' == .a
	}

	* Dropping all non-binary variables (EGRA)

	drop a225 a226 a227 a248 a249 a250 a279 a280 a281 a2112 a2113 a2114 a2148 a2149 a2150 a2183 a2184 a2185

	save "$temp2" , replace

	// Arabic Endline // 

	* Investigation of differential item functioning (DIF)

	tab grade, gen(grade)

	diflogistic a214 a215 a217 a218 a219 a229 a24 a25 a26 if inlist(grade,1,2), group(grade2) maxp(.05)
	difmh a214 a215 a217 a218 a219 a229 a24 a25 a26 if inlist(grade,1,2), group(grade2) maxp(.05)
	* Free up a229 

	diflogistic a214 a215 a217 a218 a219 a236 a237 a260 a261 if inlist(grade,2,3), group(grade3) maxp(.05)
	difmh a214 a215 a217 a218 a219 a236 a237 a260 a261 if inlist(grade,2,3), group(grade3) maxp(.05)
	* Free up a214 a219 a236 a237 a261

	diflogistic a269 a283 a284 a285 a286 a293 a294 if inlist(grade,3,4), group(grade4) maxp(.05)
	difmh a269 a283 a284 a285 a286 a293 a294 if inlist(grade,3,4), group(grade4) maxp(.05)
	* Free up a283 

	diflogistic a2122 a2123 a2124 a2130 a2131 a2132 a2133 if inlist(grade,4,5), group(grade5) maxp(.05)
	difmh a2122 a2123 a2124 a2130 a2131 a2132 a2133 if inlist(grade,4,5), group(grade5) maxp(.05)
	* Free up a2130 a2132

	diflogistic a2131 a2132 a2142 a2143 a2144 a2145 a2147 a2160 a2161 a2162 a2164 a2165 if inlist(grade,5,6), group(grade6) maxp(.05)
	difmh a2131 a2132 a2142 a2143 a2144 a2145 a2147 a2160 a2161 a2162 a2164 a2165 if inlist(grade,5,6), group(grade6) maxp(.05)

	* Free up a2130 a2142 a2143 a2144 a2145 a2147 a2162 a2164 a2165

	* Free up a229 
	foreach var of varlist a229 {
		gen `var'_1 = `var' if grade ==1
		replace `var' = . if grade ==1
		gen `var'_2 = `var' if grade ==2
		replace `var' = . if grade ==2
	}
	drop a229 

	* Free up a214 a219 a236 a237 a261
	foreach var of varlist  a214 a219 a236 a237 a261 {
		gen `var'_3 = `var' if grade ==3
		replace `var' = . if grade ==3
		gen `var'_2 = `var' if grade ==2
		replace `var' = . if grade ==2
	}

	drop a236 a237 a261

	* a214 a219 are stable across grades 1 and 2
	foreach var of varlist  a214 a219  {
		replace `var' = `var'_2 if grade ==2
		drop `var'_2
	}

	* Free up a283 
	foreach var of varlist a283 {
		gen `var'_3 = `var' if grade ==3
		replace `var' = . if grade ==3
		gen `var'_4 = `var' if grade ==4
		replace `var' = . if grade ==4
	}
	drop a283

	* Free up a2130 a2132
	foreach var of varlist a2130 a2132 {
		gen `var'_4 = `var' if grade ==4
		replace `var' = . if grade ==4
		* Note: a2132 is stable across grades 5, 6
	}

	* Free up a2142 a2143 a2144 a2145 a2147 a2162 a2164 a2165
	foreach var of varlist a2142 a2143 a2144 a2145 a2147 a2162 a2164 a2165 {
		gen `var'_5 = `var' if grade ==5
		replace `var' = . if grade ==5
		gen `var'_6 = `var' if grade ==6
		replace `var' = . if grade ==6
	}

	replace a2142 = a2142_5 if grade ==5
	replace a2143 = a2143_5 if grade ==5
	replace a2144 = a2144_5 if grade ==5
	replace a2145 = a2145_5 if grade ==5
	replace a2147 = a2147_5 if grade ==5

	drop a2142_5 a2143_5 a2144_5 a2145_5 a2147_5
	drop a2162 a2164 a2165

	drop grade?

	// Append with Arabic baseline // 

	preserve
		append using "$temp1"

		* Investigation of differential item functioning (DIF)

*		 uirt a2* a1* , group(baseline, ref(1) dif(a24 a25 a26 a213 a214 a215 a216 a217 a218 a219 a220 a221 a222 a223 a224 a229 a230 a231 a232 a236 a237 a238 a239 a254 a255 a256 a260 a261 a269 a270 a271 a282 a283 a284 a285 a286 a292 a293 a294 a297 a2101 a2102 a2103 a2104 a2105 a2106 a2108 a2109 a2110 a2111 a2119 a2120 a2121 a2130 a2131 a2208 a2134 a2142 a2143 a2144 a2145 a2146 a2147 a2178 a2179 a2180 a2182 a2191 a2192 a2193 a2194 a2195 a2196 a2197 a2198 a2199 a2200 a2201 a2202 a2203))

	restore

		* Free up variables with item drift

	preserve
		use "$temp1", clear
		foreach var of varlist a214 a215 a217 a218 a219 a221 a223 a224 a229 a230 a231 a232 a236 a237 a238 a239 a256 a260 a261 a269 a271 a283 a284 a285 a286 a293 a294 a297 a2101 a2103 a2106 a2108 a2109 a2110 a2111 a2119 a2121 a2130 a2131 a2208 a2144 a2145 a2146 a2147 a2178 a2179 a2180 a2191 a2192 a2195 a2197 {
				rename `var' bldf_`var'
		}
		tempfile bldf
		save `bldf', replace
	restore

	* Run IRT model, record item parameters

	append using `bldf'
	uirt a2* if baseline ==0

	uirt a2* a1* bldf_*, fix(prev)
	estimates store irtarabic
	estimates save "$eltemp/irt_arabic.ster", replace   // persist item params for the mechanically-/judgment-scored subscore re-scoring (13-Scoring)

	uirt_theta, eap

	* Appendix B (measurement): while the fitted model and se_theta are live
	* (se_theta is dropped further below), capture the item parameters and the
	* endline reliability. Guarded so it never interrupts the main scoring.
	if "$measure" == "1" {
		capture matrix mb_ip_arabic = e(item_par)
		if _rc == 0 {
			quietly summarize theta if baseline == 0
			scalar mb_v = r(Var)
			tempvar mbrr
			quietly generate double `mbrr' = mb_v/(mb_v + se_theta^2) if baseline == 0 & !missing(theta, se_theta)
			quietly summarize `mbrr'
			global mb_rel_arabic = r(mean)
			quietly count if baseline == 0 & !missing(theta)
			global mb_n_arabic = r(N)
			drop `mbrr'
		}
	}
	
	
	* Generate an estimate whose endline items consist of at-grade items only
	
	preserve // replace all other variables with missings (we'll pretend students took the other items only)
	
		* grade 1 arabic: All are at grade
		* grade 2 arabic
	
		foreach var in a24 a25 a26 a214 a215 a217 a218 a219 a229 {
			
			cap: replace `var' = . if grade ==2 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==2 & baseline == 0 
			
		}
		
		* grade 3 arabic
	
		foreach var in a236 a237 a214 a215 a217 a218 a219 a287 a288 a289 a290 a291 a260 a261 {
			
			cap: replace `var' = . if grade ==3 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==3 & baseline == 0 
			
		}
		
		* grade 4 arabic		
		
		foreach var in a269 a283 a284 a285 a286 a293 a294 {
			
			cap: replace `var' = . if grade ==4 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==4 & baseline == 0 
			
		}		
		
		* grade 5 arabic		
		
		foreach var in a2122 a2123 a2124 a2130 a2131 a2132 a2133 a2171 {
			
			cap: replace `var' = . if grade ==5 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==5 & baseline == 0 
			
		}	
		
		* grade 6 arabic		
		
		foreach var in a2142 a2143 a2144 a2145 a2176 a2147 a2160 a2161 a2162 a2164 a2165 a2130 a2131 a2132 a2208 a2172 {
   
			cap: replace `var' = . if grade ==6 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==6 & baseline == 0 
			
		}			
		
		estimates restore irtarabic
		cap: uirt_theta, eap suffix(arabicat)
		
		tempfile atgrade
		save `atgrade', replace	
	
	restore
	
	merge 1:1 student_id baseline using `atgrade', keepusing(*arabicat) nogen
		
	* Generate an estimate whose endline items consist of below-grade items only
	
	preserve // replace all other variables with missings (we'll pretend students took the other items only)
	
		* grade 1 arabic: All are at grade
		* grade 2 arabic
	
		foreach var in a236 a237 a238 a239 a248 a249 a250 a251 a252 a253 a254 a255 a256 a257 a258 a260 a261 a262 a263 a264 a265 a266 a267 a268 {
			cap: replace `var' = . if grade ==2 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==2 & baseline == 0 
			
		}
		
		* grade 3 arabic
	
		foreach var in a269 a270 a271 a279 a280 a281 a282 a283 a284 a285 a286 a292 a293 a294 a297 a298 a299 a2100 a2101 a2102 {
			cap: replace `var' = . if grade ==3 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==3 & baseline == 0 
			
		}
		
		* grade 4 arabic		
		
		foreach var in a2103 a2104 a2105 a2106 a2108 a2109 a2110 a2111 a2112 a2113 a2114 a2119 a2120 a2121 a2122 a2123 a2124 a2125 a2126 a2127 a2128 a2129 a2130 a2131 a2132 a2133 a2134 { 
			cap: replace `var' = . if grade ==4 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==4 & baseline == 0 
			
		}		
		
		* grade 5 arabic		
		
		foreach var in a2137 a2138 a2139 a2140 a2141 a2142 a2143 a2144 a2145 a2146 a2147 a2148 a2149 a2150 a2151 a2152 a2153 a2154 a2155 a2159 a2160 a2161 a2162 a2163 a2164 a2165 a2166 {
			cap: replace `var' = . if grade ==5 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==5 & baseline == 0 
			
		}	
		
		* grade 6 arabic		
		
		foreach var in a2178 a2179 a2180 a2181 a2182 a2183 a2184 a2185 a2191 a2192 a2193 a2194 a2195 a2196 a2197 a2198 a2199 a2200 a2201 a2202 a2203 a2206 {
			cap: replace `var' = . if grade ==6 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==6 & baseline == 0 
			
		}			
		
		estimates restore irtarabic
		keep if grade != 1
		cap: uirt_theta, eap suffix(arabicbelow)
		
		tempfile belowgrade
		save `belowgrade', replace	
	
	restore
	
	merge 1:1 student_id baseline using `belowgrade', keepusing(*arabicbelow) nogen				
	
	* Add treatment indicator, standardize
	drop treat treated
	merge m:1 school_id using "$input4", keepusing(treat)
	drop if _m ==2
	drop _m 	

	rename theta theta_arabic
	
	foreach var of varlist theta_* {
		sum `var' if treated ==0 & baseline == 0	
		replace `var' = `var' - `r(mean)'
		sum `var' if treated == 0 & baseline == 0		
		replace `var' = `var' / `r(sd)'
	}	
	
	drop se_theta
	
	* Generate attrition indicator, save temp file

	bysort student_id: gen attrition = _N != 2
	
	save "$temp3", replace

}

********************************************************************************
                         * IRT analysis French *
********************************************************************************

if $irtf== 1 {

	// Dropping five schools without a match

	* Baseline
	use "$input2", clear
	bysort pair_id school_id: keep if _n ==1
	bysort pair_id: gen N = _N
	drop if N ==1
	tempfile tf 
	save `tf', replace
	use "$input2", clear
	merge m:1 pair_id school_id using `tf', keepusing(pair_id school_id)
	drop if _m !=3
	drop _m
	gen baseline = 1

	* Replacing all don't knows with 0
	foreach var of varlist f* {
		tab `var' if `var' != ., m
		* replace `var' = 0 if `var' == .a
	}

	* Dropping all non-binary variables (EGRA)

	drop f2125 f2124 f1117 f1118 f1119 f1120 

	save "$temp1"  , replace

	* Endline
	use "$input3", clear

	merge 1:1 student_id using "$temp1", keepusing(student_id)
	keep if _m ==3 
	drop _m

	merge m:1 pair_id school_id using `tf', keepusing(pair_id school_id)
	drop if _m !=3
	drop _m
	gen baseline = 0

	* Replacing all don't knows with 0
	foreach var of varlist f2* {
		* tab `var' if `var' != ., m
		replace `var' = 0 if `var' == .a
	}

	* Dropping all non-binary variables (EGRA)

	drop f2121 f2123 f2124 f2125

	save "$temp2" , replace

	// French Endline // 

	* Investigation of differential item functioning (DIF)

	gen paper1_23 = inlist(grade,2,3) if grade<4
	gen paper23_456 = inlist(grade,4,5,6) if grade<. & grade >1
	gen paper1_456 = inlist(grade,4,5,6) if grade<. & !inlist(grade,2,3)
	
	diflogistic f21 f22 f23 f211 f232 f233 f235 f247 if inlist(grade,1,2,3), group(paper1_23) maxp(.05)
	difmh f21 f22 f23 f211 f232 f233 f235 f247 if inlist(grade,1,2,3), group(paper1_23) maxp(.05)
	* Free up f22 f233 f235 

	diflogistic f21 f23 f232 f233 f235 f294 f297 f298 f299 if grade<. & grade >1, group(paper23_456) maxp(.05)
	difmh f21 f23 f232 f233 f235 f294 f297 f298 f299 if grade<. & grade >1, group(paper23_456) maxp(.05)
	* Free up f294 f297  
	
	diflogistic f21 f23 f232 f233 f235 if grade<. & !inlist(grade,2,3), group(paper1_456) maxp(.05)
	difmh f21 f23 f232 f233 f235 if grade<. & !inlist(grade,2,3), group(paper1_456) maxp(.05)
	* Free up f232 f233 f235
	

	* Free up f233 f235
	foreach var of varlist f233 f235 {
		gen `var'_1 = `var' if grade ==1
		replace `var' = . if grade ==1
		gen `var'_23 = `var' if grade ==2 | grade ==3
		replace `var' = . if grade ==2 | grade ==2
		gen `var'_456 = `var' if inlist(grade,4,5,6)
		replace `var' = . if inlist(grade,4,5,6)
	}
	drop f233 f235

	* Free up f232 f294 f297 
	foreach var of varlist  f232 {
		gen `var'_456 = `var' if inlist(grade,4,5,6)
		replace `var' = . if inlist(grade,4,5,6)
	}

	* Free up f22
	foreach var of varlist f22 {
		gen `var'_1 = `var' if grade ==1
		replace `var' = . if grade ==1
	}

	drop paper*

	// Append with French Baseline // 

	preserve
		append using "$temp1"

		* Investigation of differential item functioning (DIF)

		uirt f2* f1*, group(baseline, slow ref(1) dif(f21 f22 f23 f211 f218 f219 f221 f222 f225 f227 f229 f232 f234 f242 f243 f249 f253 f255 f256 f257 f258 f264 f265 f266 f267 f268 f269 f270 f271 f272 f273 f274 f275 f276 f294 f295 f296 f297 f298 f299 f2100 f2118 f2119 f2120 f2128 f2129 f2130 f2131)) nit(1000)

	restore

		* Free up variables with item drift

	preserve
		use "$temp1", clear
		
		renvars f2* f1*, prefix(bldf_)	
		
		foreach var in f22 f253 f218 f270 f271 f274 f276 f295 f296 f2128 f2129 {
				rename bldf_`var' `var' 
		}
		tempfile bldf
		save `bldf', replace
	restore

	* Run IRT model, record item parameters

	append using `bldf'
	uirt f2* if baseline ==0

	uirt f2* bldf_*, fix(prev)

	estimates store irtfrench
	estimates save "$eltemp/irt_french.ster", replace   // persist item params for the mechanically-/judgment-scored subscore re-scoring (13-Scoring)

	uirt_theta, eap

	* Appendix B (measurement): capture item parameters + endline reliability
	* (see the Arabic block above for details).
	if "$measure" == "1" {
		capture matrix mb_ip_french = e(item_par)
		if _rc == 0 {
			quietly summarize theta if baseline == 0
			scalar mb_v = r(Var)
			tempvar mbrr
			quietly generate double `mbrr' = mb_v/(mb_v + se_theta^2) if baseline == 0 & !missing(theta, se_theta)
			quietly summarize `mbrr'
			global mb_rel_french = r(mean)
			quietly count if baseline == 0 & !missing(theta)
			global mb_n_french = r(N)
			drop `mbrr'
		}
	}
	
	* Add treatment indicator, standardize
	drop treat treated
	merge m:1 school_id using "$input4", keepusing(treat)
	drop if _m ==2
	drop _m 
	
	sum theta if treated ==0 & baseline == 0	
	replace theta = theta - `r(mean)'
	sum theta if treated == 0 & baseline == 0		
	replace theta = theta / `r(sd)'

	rename theta theta_french
	drop se_theta

	* Generate attrition indicator, save temp file

	bysort student_id: gen attrition = _N != 2

	save "$temp4", replace

}

********************************************************************************
                         * IRT analysis math *
********************************************************************************

if $irtm== 1 {

	// Dropping five schools without a match

	* Baseline
	use "$input2", clear
	bysort pair_id school_id: keep if _n ==1
	bysort pair_id: gen N = _N
	drop if N ==1
	tempfile tf 
	save `tf', replace
	use "$input2", clear
	merge m:1 pair_id school_id using `tf', keepusing(pair_id school_id)
	drop if _m !=3
	drop _m
	gen baseline = 1

	* Replacing all don't knows with 0
	foreach var of varlist m* {
		* tab `var' if `var' != ., m
		replace `var' = 0 if `var' == .a
	}
	
	save "$temp1"  , replace

	* Endline
	use "$input3", clear

	merge 1:1 student_id using "$temp1", keepusing(student_id)
	keep if _m ==3 
	drop _m

	merge m:1 pair_id school_id using `tf', keepusing(pair_id school_id)
	drop if _m !=3
	drop _m
	gen baseline = 0

	* Replacing all don't knows with 0
	foreach var of varlist m* {
		* tab `var' if `var' != ., m
		replace `var' = 0 if `var' == .a
	}

	save "$temp2" , replace

	// Math Endline // 

	* Investigation of differential item functioning (DIF)

	tab grade, gen(grade)

	diflogistic m22 m23 m24 m210 m221 m222 m223 m226 if inlist(grade,1,2), group(grade2) maxp(.05)
	difmh m22 m23 m24 m210 m221 m222 m223 m226 if inlist(grade,1,2), group(grade2) maxp(.05)
	* Free up m22 m23 m210 

	diflogistic m230 m231 m232 m233 m222 m252 m253 if inlist(grade,2,3), group(grade3) maxp(.05)
	difmh m230 m231 m232 m233 m222 m252 m253 if inlist(grade,2,3), group(grade3) maxp(.05)
	* Free up m230 m232 m233 m252 m253

	diflogistic m230 m259 m260 m261 m279 if inlist(grade,3,4), group(grade4) maxp(.05)
	difmh m230 m259 m260 m261 m279 if inlist(grade,3,4), group(grade4) maxp(.05)
	* Free up m230

	diflogistic m2101 m2104 m2107 m2108 m282 m286 m296 if inlist(grade,4,5), group(grade5) maxp(.05)
	difmh m2101 m2104 m2107 m2108 m282 m286 m296 if inlist(grade,4,5), group(grade5) maxp(.05)
	* Free up m2104 m282

	diflogistic m2107 m2111 m2119 m2133 m2139 m2140 m286 if inlist(grade,5,6), group(grade6) maxp(.05)
	difmh m2107 m2111 m2119 m2133 m2139 m2140 m286 if inlist(grade,5,6), group(grade6) maxp(.05)

	* Free up m2139 m2140 m286

	* Free up m22 m23 m210  
	foreach var of varlist m22 m23 m210  {
		gen `var'_1 = `var' if grade ==1
		replace `var' = . if grade ==1
		gen `var'_2 = `var' if grade ==2
		replace `var' = . if grade ==2
	}

	drop m22 m23 m210 
	
	* Free m230 m232 m233 m252 m253
	foreach var of varlist  m230 m232 m233 m252 m253 {
		gen `var'_3 = `var' if grade ==3
		replace `var' = . if grade ==3
		gen `var'_2 = `var' if grade ==2
		replace `var' = . if grade ==2
	}

	drop  m232 m233 m252 m253

	* Free up m230 
	
	* Free up m2139 m2140 m286
	foreach var of varlist m2139 m2140 m286 {
		gen `var'_5 = `var' if grade ==5
		replace `var' = . if grade ==5
		gen `var'_6 = `var' if grade ==6
		replace `var' = . if grade ==6
	}

	drop grade?

	// Append with arabic Baseline // 

	preserve
		append using "$temp1"

		* Investigation of differential item functioning (DIF)

*		uirt m2* m1* , group(baseline, slow ref(1) dif(m21 m24 m28 m29 m211 m221 m222 m223 m226 m2107 m230 m231 m234 m2108 m237 m290 m254 m259 m2147 m260 m261 m262 m284 m265 m266 m279 m280 m235 m282 m2110 m283 m286 m294 m295 m2115 m2116 m296 m2101 m2104 m236 m2112 m2114 m2118 m2119 m2149 m2120 m2121 m2128 m2131 m2160 m2141 m2143 m2144 m2150 m2151 m285 m2154 m2158 m2165 m2166 m2167)) nit(1000)

	restore

	preserve
		use "$temp1", clear
		drop m2107 m2108  m2111 m2112 m2114 m2118 m2119 m2149 m2120 m2121 m2128 m2131 m2133 m2160
		
		renvars m2* m1*, prefix(bldf_)	
		
		foreach var in m21 m223 m226 m237 m290 m259 m260 m261 m279 m282 m283 m235 m2115 m296 m2101 m2104 m2144 m2150 m2165 {
				rename bldf_`var' `var' 
		}		
		
		
		tempfile bldf2
		save `bldf2', replace
	restore
	
	preserve
		use "$temp1", clear
		
		renvars m2* m1*, prefix(bldf_)	
		
		foreach var in m2107 m2108  m2111 m2112 m2114 m2118 m2119 m2149 m2120 m2121 m2128 m2131 m2133 m2160 {
				rename bldf_`var' `var' 
		}		
		
		
		tempfile bldf3
		save `bldf3', replace
	restore	
	
	
	preserve
	
		renvars m2107 m2108 m2139 m2140 m2111 m2112 m2114 m2118 m2119 m2149 m2120 m2121 m2128 m2131 m2133 m2160, prefix(pre_)
	
*		uirt m2* if baseline ==0	
	
		append using `bldf2'
	
		cap: drop bldf_m199 
		cap: drop bldf_m1103 
		cap: drop m2140  
		cap: drop m2139	
	
*		uirt m2* bldf_* , fix(prev) nit(1000)	
		
		renvars pre_*, predrop(4)	
		drop if baseline == 1
		append using `bldf3'
		
		dropmiss, force
		
		cap: drop bldf_m199 
		cap: drop bldf_m1103 
		cap: drop m2140  
		cap: drop m2139			
		
*		uirt m2* bldf_*, fix(prev) group(baseline, slow ref(1) dif(m2107 m2108  m2111 m2112 m2114 m2118 m2119 m2149 m2120 m2121 m2128 m2131 m2133 m2160)) nit(1000)		

	restore
	
		* Free up variables with item drift

	preserve
		use "$temp1", clear
		
		renvars m2* m1*, prefix(bldf_)	
		
		foreach var in m21 m223 m226 m237 m290 m259 m260 m261 m279 m282 m283 m235 m2115 m296 m2101 m2114 m2120 m2121 m2144 m2150 m2165 {
				rename bldf_`var' `var' 
		}
		tempfile bldf4
		save `bldf4', replace
	restore

	* Run IRT model, record item parameters

	append using `bldf4'
	uirt m2* if baseline ==0

	cap: drop bldf_m199 
	cap: drop bldf_m1103 
	cap: drop m2140  
	cap: drop m2139		
	
	uirt m2* bldf_*, fix(prev) nit(1000)
	cap: estimates drop irtmath
	estimates store irtmath
	estimates save "$eltemp/irt_math.ster", replace   // persist item params (mathematics is fully mechanically scored; see 13-Scoring)

	uirt_theta, eap

	* Appendix B (measurement): capture item parameters + endline reliability
	* (see the Arabic block above for details).
	if "$measure" == "1" {
		capture matrix mb_ip_math = e(item_par)
		if _rc == 0 {
			quietly summarize theta if baseline == 0
			scalar mb_v = r(Var)
			tempvar mbrr
			quietly generate double `mbrr' = mb_v/(mb_v + se_theta^2) if baseline == 0 & !missing(theta, se_theta)
			quietly summarize `mbrr'
			global mb_rel_math = r(mean)
			quietly count if baseline == 0 & !missing(theta)
			global mb_n_math = r(N)
			drop `mbrr'
		}
	}
	
	* Generate an estimate that consists of Geometry, measures, data items only
	
	preserve // replace all other variables with missings (we'll pretend students took the other items only)
	
		foreach var in m21 m22 m23 m24 m25 m26 m27 m28 m29 m210 m211 m212 m213 m214 m215 m216 m217 m218 m219 m220 m22 m23 m24 m230 m231 m232 m233 m234 m235 m236 m237 m210 m242 m243 m252 m253 m254 m232 m233 m230 m231 m259 m260 m261 m262 m252 m253 m265 m266 m268 m222 m270 m230 m282 m283 m284 m285 m286 m260 m261 m289 m290 m291 m259 m293 m294 m295 m296 m297 m2107 m2108 m282 m2110 m2111 m2112 m286 m2114 m2115 m2116 m296 m2118 m2119 m2120 m2123 m2124 m2125 m2126 m2107 m2108 m2131 m2139 m2140 m2141 m2111 m2143 m2144 m286 m259 m2147 m2150 m2151 m2139 m2155 m2156 m2157 m2158 m2107 m21 m22 m23 m11 m24 m12 m13 m14 m15 m16 m17 m18 m19 m110 m28 m29 m210 m211 m111 m112 m113 m114 m115 m116 m117 m118 m119 m120 m123 m124 m2107 m2107 m125 m126 m127 m128 m230 m231 m232 m233 m129 m234 m130 m131 m2108 m2108 m132 m237 m133 m134 m135 m137 m138 m139 m140 m290 m151 m2139 m2139 m254 m152 m153 m154 m155 m156 m157 m158 m259 m2147 m260 m261 m262 m159 m160 m284 m2140 m161 m162 m163 m265 m164 m266 m165 m166 m169 m170 m171 m172 m173 m174 m235 m185 m186 m282 m2110 m283 m187 m188 m189 m190 m235 m191 m286 m192 m193 m194 m195 m196 m197 m198 m199 m1100 m1101 m1102 m1103 m1104 m1105 m294 m1108 m295 m2115 m2116 m296 m1109 m236 m236 m1133 m1134 m1135 m1136 m2111 m1137 m2112 m1138 m1139 m1140 m1141 m1142 m1143 m1144 m1145 m2114 m1146 m1147 m1148 m1149 m1150 m2118 m1151 m2119 m2149 m2120 m1153 m1154 m1155 m1156 m1157 m1158 m1165 m252 m252 m1166 m2131 m1167 m253 m253 m1183 m1184 m1185 m2141 m1186 m1187 m1188 m1189 m2143 m2144 m1191 m1192 m1193 m1194 m1195 m1196 m1197 m1198 m1199 m1200 m1201 m1202 m1203 m1204 m1205 m1206 m1209 m1210 m2150 m2151 m1211 m285 m285 m2158 m1218 m1219 {
			
			cap: replace `var' = . 
			cap: replace bldf_`var' = .
			
		}
		
		estimates restore irtmath
		cap: uirt_theta, eap suffix(geometry)
		
		tempfile geometry
		save `geometry', replace
	
	restore
	
	merge 1:1 student_id baseline using `geometry', keepusing(*geometry) nogen
	
	
	* Generate an estimate that consists of calculation and numeracy items only
	
	preserve // replace all other variables with missings (we'll pretend students took the other items only)
	
		foreach var in m1106 m1107 m1110 m1111 m1112 m1113 m1114 m1115 m1116 m1117 m1118 m1119 m1120 m1121 m1122 m1123 m1124 m1125 m1126 m1127 m1128 m1129 m1130 m1131 m1132 m1152 m1159 m1160 m1161 m1162 m1163 m1164 m1168 m1169 m1170 m1171 m1172 m1173 m1174 m1175 m1176 m1177 m1178 m1179 m1180 m1181 m1182 m1207 m1208 m121 m1212 m1213 m1214 m1215 m1216 m1217 m122 m1220 m1221 m1222 m1223 m1224 m1225 m1226 m1227 m1228 m1229 m1230 m136 m141 m142 m143 m144 m145 m146 m147 m148 m149 m150 m167 m168 m175 m176 m177 m178 m179 m180 m181 m182 m183 m184 m2100 m2101 m2102 m2103 m2104 m2105 m2119 m2121 m2122 m2128 m2133 m2134 m2135 m2136 m2137 m2138 m2140 m2149 m2154 m2160 m2161 m2163 m2164 m2165 m2166 m2167 m221 m222 m223 m224 m225 m226 m238 m239 m240 m247 m249 m250 m251 m267 m271 m272 m273 m274 m275 m276 m277 m278 m279 m280 m298 m299 {
			
			cap: replace `var' = . 
			cap: replace bldf_`var' = .
			
		}
	
		estimates restore irtmath
		cap: uirt_theta, eap suffix(numbers)
		
		tempfile numbers
		save `numbers', replace
	
	restore
	
	merge 1:1 student_id baseline using `numbers', keepusing(*numbers) nogen
	
	* Generate an estimate that consists of knowing items only
	
	preserve // replace all other variables with missings (we'll pretend students took the other items only)
	
		foreach var in m11 m1100 m1102 m1103 m1104 m1105 m1106 m1107 m1108 m111 m1111 m1112 m1113 m1114 m1115 m1116 m1117 m1118 m1119 m112 m1123 m1124 m1127 m1128 m1129 m113 m1130 m1131 m1132 m1133 m1134 m1135 m1136 m1137 m1138 m114 m1144 m1145 m1146 m1147 m1148 m1149 m115 m1150 m1151 m1152 m1153 m1154 m1155 m1156 m1157 m1158 m1159 m116 m1160 m1161 m1162 m1163 m1164 m1165 m1166 m1167 m1168 m1169 m117 m1170 m1171 m1172 m1173 m1174 m1175 m1176 m1177 m1178 m1179 m118 m1180 m1181 m1182 m1183 m1184 m1185 m1186 m1187 m1188 m1189 m119 m12 m120 m1202 m1203 m1204 m1205 m1206 m1207 m1208 m1209 m121 m1210 m1211 m1212 m1213 m1214 m1215 m1216 m1217 m1218 m1219 m122 m1220 m1221 m1222 m1223 m1224 m1225 m1226 m1227 m1228 m1229 m123 m1230 m124 m125 m126 m127 m128 m13 m130 m131 m132 m133 m134 m135 m136 m137 m138 m139 m14 m140 m141 m142 m143 m144 m145 m148 m149 m15 m150 m151 m152 m153 m154 m155 m156 m157 m158 m159 m16 m160 m161 m162 m163 m164 m165 m166 m167 m168 m169 m170 m171 m172 m173 m174 m175 m176 m177 m178 m179 m180 m181 m182 m183 m184 m185 m186 m187 m188 m189 m190 m191 m193 m194 m195 m196 m197 m198 m199 m210 m2101 m2104 m2105 m2107 m2108 m211 m2110 m2111 m2112 m2114 m2115 m2116 m2118 m2119 m212 m2120 m2121 m2122 m2123 m2124 m2125 m2126 m2128 m213 m2131 m2133 m2135 m2136 m2137 m2138 m2139 m214 m2140 m2141 m2143 m2144 m2149 m215 m2150 m2151 m2154 m2158 m216 m2160 m2161 m2163 m2164 m2165 m2166 m2167 m217 m218 m219 m22 m220 m224 m225 m226 m23 m230 m231 m232 m233 m235 m236 m237 m238 m239 m24 m240 m242 m243 m249 m25 m250 m251 m252 m253 m254 m260 m261 m262 m265 m266 m267 m268 m270 m271 m272 m273 m274 m275 m276 m277 m278 m279 m280 m282 m283 m284 m285 m289 m290 m291 m293 m294 m295 m296 m299 {
			
			cap: replace `var' = . 
			cap: replace bldf_`var' = .
			
		}
	
		estimates restore irtmath
		cap: uirt_theta, eap suffix(knowing)
		
		tempfile knowing
		save `knowing', replace
	
	restore
	
	merge 1:1 student_id baseline using `knowing', keepusing(*knowing) nogen
	
	* Generate an estimate that consists of applying and reasoning items only
	
	preserve // replace all other variables with missings (we'll pretend students took the other items only)
	
		foreach var in m110 m1101 m1109 m1110 m1120 m1121 m1122 m1125 m1126 m1139 m1140 m1141 m1142 m1143 m1191 m1192 m1193 m1194 m1195 m1196 m1197 m1198 m1199 m1200 m1201 m129 m146 m147 m17 m18 m19 m192 m21 m2100 m2102 m2103 m2134 m2147 m221 m222 m223 m234 m247 m259 m26 m260 m261 m27 m28 m286 m29 m297 m298 {
			
			cap: replace `var' = . 
			cap: replace bldf_`var' = .
			
		}
	
		estimates restore irtmath
		cap: uirt_theta, eap suffix(applying)
		
		tempfile applying
		save `applying', replace
	
	restore
	
	merge 1:1 student_id baseline using `applying', keepusing(*applying) nogen	
	
	* Generate an estimate whose endline items consist of at-grade items only
	
	preserve // replace all other variables with missings (we'll pretend students took the other items only)
	
		* grade 1 math: All are at grade
		* grade 2 math
	
		foreach var in m22 m23 m24 m221 m223 m226 m210 m235 m236 m242 m243 {
			
			cap: replace `var' = . if grade ==2 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==2 & baseline == 0 
			
		}
		
		* grade 3 math
	
		foreach var in m222 m222 m230 m231 m252 m252 m253 m232 m233 m254 m265 m267 m272 {
			
			cap: replace `var' = . if grade ==3 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==3 & baseline == 0 
			
		}
		
		* grade 4 math		
		
		foreach var in m230 m279 m259 m260 m261 m282 m286 m290 m285 m284 m283 m2105 m2102 m2103 {
			
			cap: replace `var' = . if grade ==4 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==4 & baseline == 0 
			
		}		
		
		* grade 5 math		
		
		foreach var in m282 m296 m2101 m2104 m2107 m2108 m286 m2111 m2119 m2110 m2115 m2128 m2120 m2121 m2134 m2135 m2125 m2126 m2136 {
			
			cap: replace `var' = . if grade ==5 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==5 & baseline == 0 
			
		}	
		
		* grade 6 math		
		
		foreach var in m259 m2107 m286 m2111 m2133 m2140 m2139 m2119 m2147 m2160 m2149 m2144 m2141 m2143 m2157 m2155 m2156 m2150 m2151 m2154 {
   
			cap: replace `var' = . if grade ==6 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==6 & baseline == 0 
			
		}			
		
		estimates restore irtmath
		cap: uirt_theta, eap suffix(mathat)
		
		tempfile atgrade
		save `atgrade', replace	
	
	restore
	
	merge 1:1 student_id baseline using `atgrade', keepusing(*mathat) nogen
	
	
	* Generate an estimate whose endline items consist of below-grade items only
	
	preserve // replace all other variables with missings (we'll pretend students took the other items only)
	
		* grade 1 math: All are at grade
		* grade 2 math
	
		foreach var in m230 m231 m253 m232 m233 m247 m234 m237 m238 m239 m240 m242 m243 m249 m250 m251 {
			
			cap: replace `var' = . if grade ==2 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==2 & baseline == 0 
			
		}
		
		* grade 3 math
	
		foreach var in m279 m259 m260 m261 m280 m262 m266 m267 m268 m270 m271 m272 m273 m274 m275 m276 m277 m278 {
			
			cap: replace `var' = . if grade ==3 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==3 & baseline == 0 
			
		}
		
		* grade 4 math		
		
		foreach var in m296 m2101 m2104 m2107 m2108 m294 m295 m289 m291 m293 m297 m298 m299 m2100 {
			
			cap: replace `var' = . if grade ==4 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==4 & baseline == 0 
			
		}		
		
		* grade 5 math		
		
		foreach var in m2133 m2140 m2139 m2116 m2112 m2131 m2114 m2118 m2122 m2123 m2124 m2137 m2138 {
			
			cap: replace `var' = . if grade ==5 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==5 & baseline == 0 
			
		}	
		
		* grade 6 math		
		
		foreach var in m2158 m2164 m2165 m2166 m2167 m2161 m2163 {
   
			cap: replace `var' = . if grade ==6 & baseline == 0 
			cap: replace bldf_`var' = . if grade ==6 & baseline == 0 
			
		}			
		
		estimates restore irtmath
		keep if grade != 1
		cap: uirt_theta, eap suffix(mathbelow)
		
		tempfile belowgrade
		save `belowgrade', replace	
	
	restore
	
	merge 1:1 student_id baseline using `belowgrade', keepusing(*mathbelow) nogen		
	
	
	* Add treatment indicator, standardize
	drop treat treated
	merge m:1 school_id using "$input4", keepusing(treat)
	drop if _m ==2
	drop _m 
	
	rename theta theta_math
	drop se_thet*	
	
	foreach var of varlist theta_* {
		sum `var' if treated ==0 & baseline == 0	
		replace `var' = `var' - `r(mean)'
		sum `var' if treated == 0 & baseline == 0		
		replace `var' = `var' / `r(sd)'
	}
	
	* Generating a variable with equal weight to numbers and geometry
	egen theta_numgeo =  rowmean(theta_geometry theta_numbers)
	
	foreach var of varlist theta_numgeo {
		sum `var' if treated ==0 & baseline == 0	
		replace `var' = `var' - `r(mean)'
		sum `var' if treated == 0 & baseline == 0		
		replace `var' = `var' / `r(sd)'
	}	
	
	* Generate attrition indicator, save temp file

	bysort student_id: gen attrition = _N != 2

	save "$temp5", replace

}

********************************************************************************
                         * EGRA *
********************************************************************************

if $egr== 1 {

// Dropping five schools without a match

	* Baseline
	use "$input2", clear
	bysort pair_id school_id: keep if _n ==1
	bysort pair_id: gen N = _N
	drop if N ==1
	tempfile tf 
	save `tf', replace
	use "$input2", clear
	merge m:1 pair_id school_id using `tf', keepusing(pair_id school_id)
	drop if _m !=3
	drop _m
	gen baseline = 1

	* Replacing all don't knows with 0
	foreach var of varlist a* {
		* tab `var' if `var' != ., m
		replace `var' = 0 if `var' == .a
	}

	* Keeping all non-binary variables (EGRA)

	keep student_id subject grade a110 a111 a112 a121 a122 a123 a124 a125 a126 a127 a128 a129 a143 a144 a145 a146 a147 a148 a160 a161 a162 a163 a164 a165 a188 a189 a190 a191 a192 a193 a1126 a1127 a1128 a1129 a1130 a1131 f2125 f2124 f1117 f1118 f1119 f1120 baseline

	* Words read correctly / minute in French (grades 4-6 only)
	
	gen hold1 = (57-f2125-f2124)
	replace hold1 = 0 if hold1<0
	replace hold1 = hold1 / f1117 * 60 
	replace hold1 = . if f1117 >600
	replace hold1 = . if f1117 <15
	
	gen hold2 = (55-f1119-f1118)
	replace hold2 = 0 if hold1<0
	replace hold2 = hold1 / f1120  * 60 
	replace hold2 = . if f1120  >600
	replace hold2 = . if f1120  <15

	egen wrc_french = rowmean(hold1 hold2)
	label var wrc_french "Words read correctly / minute in French"		
	drop hold1 hold2
	
	* Words read correctly / minute in Arabic
	
	gen wrc_arabic = . 
	label var wrc_arabic "Words read correctly / minute in Arabic"
	
	replace wrc_arabic = a110-a112 if grade == 1
	replace wrc_arabic = 0 if wrc_arabic<0
	
	gen hold1 = a121-a123 if grade ==2
	gen hold2 = a124-a126 if grade ==2
	gen hold3 = a127-a129 if grade ==2
	replace hold1=0 if hold1<0
	replace hold2=0 if hold2<0
	replace hold3=0 if hold3<0
	
	egen hold4 = rowmean(hold1 hold2 hold3)
	
	replace wrc_arabic = hold4 if grade == 2
	drop hold?	
	
	gen hold1 = a143-a145 if grade ==3
	gen hold2 = a146-a148 if grade ==3
	
	replace hold1=0 if hold1<0
	replace hold2=0 if hold2<0
	
	egen hold3 = rowmean(hold1 hold2)
	
	replace wrc_arabic = hold3 if grade == 3
	drop hold?
	
	gen hold1 = a160-a162 if grade ==4
	gen hold2 = a163-a165 if grade ==4
	
	replace hold1=0 if hold1<0
	replace hold2=0 if hold2<0
	
	egen hold3 = rowmean(hold1 hold2)
	
	replace wrc_arabic = hold3 if grade == 4
	drop hold?
	
	gen hold1 = a188-a190 if grade ==5
	gen hold2 = a191-a193 if grade ==5
	
	replace hold1=0 if hold1<0
	replace hold2=0 if hold2<0
	
	egen hold3 = rowmean(hold1 hold2)
	
	replace wrc_arabic = hold3 if grade == 5
	drop hold?	
	
	gen hold1 = a1126-a1128  if grade ==6
	gen hold2 = a1129-a1131 if grade ==6
	
	replace hold1=0 if hold1<0
	replace hold2=0 if hold2<0
	
	egen hold3 = rowmean(hold1 hold2)
	
	replace wrc_arabic = hold3 if grade == 6
	drop hold?		
	
	replace wrc_arabic = 0 if wrc_arabic<0	
	
	save "$temp1"  , replace

	* Endline
	use "$input3", clear

	merge 1:1 student_id using "$temp1", keepusing(student_id)
	keep if _m ==3 
	drop _m

	merge m:1 pair_id school_id using `tf', keepusing(pair_id school_id)
	drop if _m !=3
	drop _m
	gen baseline = 0

	* Replacing all don't knows with 0
	foreach var of varlist a* {
		* tab `var' if `var' != ., m
		replace `var' = 0 if `var' == .a
	}

	* Keeping all non-binary variables (EGRA)

	keep student_id subject grade a225 a226 a227 a248 a249 a250 a279 a280 a281 a2112 a2113 a2114 a2148 a2149 a2150 a2183 a2184 a2185 f2123 f2124 f2125 baseline
	
	* Words read correctly / minute in French (grades 4-6 only)

	gen wrc_french = f2123 - f2125
	replace wrc_french = 0 if wrc_french<0
	label var wrc_french "Words read correctly / minute in French"		
	
	* Words read correctly / minute in Arabic
	
	gen wrc_arabic = . 
	label var wrc_arabic "Words read correctly / minute in Arabic"	
	
	replace wrc_arabic = a225 - a227 if grade == 1
	replace wrc_arabic = a248 - a250 if grade == 2
	replace wrc_arabic = a279 - a281 if grade == 3
	replace wrc_arabic = a2112 - a2114 if grade == 4
	replace wrc_arabic = a2148 - a2150 if grade == 5
	replace wrc_arabic = a2183 - a2185 if grade == 6
	replace wrc_arabic = 0 if wrc_arabic < 0
	
	save "$temp2" , replace

}


********************************************************************************
    * Combine estimates, generate one dataset with background information *
********************************************************************************

if $comb== 1 {

	use "$temp3", clear
	
	merge 1:1 student_id baseline using  "$temp1", keepusing(wrc_arabic wrc_french) nogen
	merge 1:1 student_id baseline using  "$temp2", keepusing(wrc_arabic wrc_french) nogen update replace
	
	merge 1:1 student_id baseline using  "$temp4", keepusing(theta_french) nogen
	merge 1:1 student_id baseline using  "$temp5", keepusing(theta_math theta_mathat theta_mathbelow theta_numbers theta_geometry theta_knowing theta_applying theta_numgeo) nogen
	
	gen post = baseline ==0
	
	label var post "Post period"
	label var attrition "Attrition"
	label var theta_arabic "Arabic score"
	label var theta_french "French score"
	label var theta_math "Math score"

	label var theta_arabicat "Arabic score (at grade)"
	label var theta_arabicbelow "Arabic score (below grade)"
	
	label var theta_mathat "Math score (at grade)"
	label var theta_mathbelow "Math score (below grade)"
	
	label var theta_numbers "Math score: Calculation and numeracy"
	label var theta_geometry "Math score: Geometry, measures, data"
	label var theta_knowing "Math score: Knowing"
	label var theta_applying "Math score: Applying and reasoning"
	label var theta_numgeo "Math score: Equal weight to calculation and numeracy vs others"
	
	label var baseline "Baseline (vs endline)"
	
	order treated, after(school_id)
	order theta_* attrition post baseline, after(student_id)
	drop enq_som starttime endtime duration SubmissionDate time_start time_end time_end feedback_finale strata priority gender tayssir repeated QC completion school_list student_list confirmed_completion
	drop a21-m1230
	
	* Add demographics
	preserve
		use "$input2", clear
		tempfile d
		save `d', replace
	restore
	merge m:1 student_id using `d', keepusing(repeated tayssir gender)
	drop if _m ==2
	drop _m 
	
	* Add school characteristics
		
	merge m:1 school_id using "$input0", keepusing(n_teachers)
	drop if _m ==2
	drop _m 
		
	preserve
		
		use "$input1", clear
		keep if year ==7
	
		collapse (sum) total_enrolled girls_enrolled tayssir housing schoolbag ss_beneficiary, by(school_id)
 	
		gen perc_female = (girls_enrolled/total_enrolled)*100
		label var perc_female "Female students (percentage, 2021/2022)"
		
		gen perc_tayssir  = (tayssir/total_enrolled)*100
		label var perc_tayssir "Tayssir beneficiary (percentage, 2021/2022)"
		replace perc_tayssir = 100 if perc_tayssir >100 & perc_tayssir<.

		gen perc_ssbenef = (ss_beneficiary/total_enrolled)*100
		replace perc_ssbenef = 100 if perc_ssbenef >100 & ss_beneficiary<.
		label var perc_ssbenef "Social transfer beneficiary (percentage, 2021/2022)"

		rename total_enrolled total_enrolled7_sum
		
		label var total_enrolled7_sum "Total enrollment (2021/2022)"
		
		cap: drop _*
		tempfile schar1
		save `schar1', replace
		
	restore

	merge m:1 school_id using `schar1', keepusing(total_enrolled7_sum perc_female perc_ssbenef perc_tayssir)
	drop if _m ==2
	drop _m
	
	preserve
		
		use "$input1", clear
		keep if year ==7
		keep if avg_score<.
		collapse avg_score [aw=total_examined], by(school_id)
		rename avg_score avg_score7_mu
		label var avg_score7_mu "Average grade-6 exam score (2021/2022)"	
		tempfile schar2
		save `schar2', replace
		
	restore
	
	merge m:1 school_id using `schar2', keepusing(avg_score7_mu)
	drop if _m ==2
	drop _m	
			
	* Generate additional variables: female, urban, regional development
	tab grade, gen(grade)
	rename gender female
	lab var female "Female"
	rename area urban
	gen regional_dev = inlist(region,6, 3, 7, 4, 1) if region < .
	label var regional_dev "Regional development (high)"

	* Generate additional variables: test-score quartile identifiers at baseline 	
	
	egen tile_arabic = xtile(theta_arabic) if baseline ==1, by(grade) n(4)  
	gen bottom_arabic = tile_arabic ==1 if theta_arabic<. & baseline ==1
	gen middle_arabic = inlist(tile_arabic,2,3) if theta_arabic<. & baseline ==1
	gen top_arabic = tile_arabic ==4 if theta_arabic<. & baseline ==1
	
	egen tile_french = xtile(theta_french) if baseline ==1, by(grade) n(4)  
	gen bottom_french = tile_french ==1 if theta_french<. & baseline ==1
	gen middle_french = inlist(tile_french,2,3) if theta_french<. & baseline ==1
	gen top_french = tile_french ==4 if theta_french<. & baseline ==1
		
	egen tile_math = xtile(theta_math) if baseline ==1, by(grade) n(4)  
	gen bottom_math = tile_math ==1 if theta_math<. & baseline ==1
	gen middle_math = inlist(tile_math,2,3) if theta_math<. & baseline ==1
	gen top_math = tile_math ==4 if theta_math<. & baseline ==1	 
	
	drop tile*
	
	preserve
		* All endline oservations need the baseline quartile indicators, so we'll merge them in here
		keep if baseline ==1
		replace baseline = 0 
		tempfile tiles 
		keep if attrition == 0 
		tempfile tiles
		save `tiles', replace
	restore
	merge 1:1 baseline student_id using `tiles', update replace nogen keepusing(top_* middle_* bottom_*)
	
	lab var top_arabic "Arabic top quartile (at baseline)"
	lab var middle_arabic "Arabic middle two quartiles  (at baseline)"
	lab var bottom_arabic "Arabic bottom quartile (at baseline)"
	
	lab var top_french "French top quartile (at baseline)"
	lab var middle_french "French middle two quartiles (at baseline)"
	lab var bottom_french "French bottom quartile (at baseline)"
	
	lab var top_math "Math top quartile (at baseline)"
	lab var middle_math "Math middle two quartiles (at baseline)"
	lab var bottom_math "Math bottom quartile (at baseline)"	
	
	* Merge in GPA from admin data
		
	preserve
	
		use "$input5", clear
		keep if inlist(subject,18, 19, 22) // math, french, and arabic. unclear where they come from for Grade 1
		collapse testscore, by(student_id)
		rename testscore gpa
		tempfile gpa
		save `gpa',replace
	restore
	merge m:1 student_id using `gpa', keepusing(gpa)
	drop if _m ==2
	drop _m 

	label var gpa "Grade point average"
	
	lab var tayssir "Ever qualified for Tayssir"
	
	save "$temp6", replace
	
}	

********************************************************************************
             * Residualize test scores for causal forests *
********************************************************************************

if $resid== 1 {
	
	* Load data, transform to wide
	use "$temp6", clear
	keep if baseline ==1
	renvars theta_arabic theta_french theta_math bottom_* middle_* top_*, prefix("bl_")
	tempfile b
	save `b', replace
	
	use "$temp6", clear
	keep if baseline ==0
	merge 1:1 student_id using `b', keepusing(bl_*)
	keep if _m ==3
	drop _m
	drop post baseline attrition
	
	* Generate change scores
	gen delta_arabic = theta_arabic-bl_theta_arabic
	gen delta_french = theta_french-bl_theta_french
	gen delta_math = theta_math-bl_theta_math
	
	* Residualize change scores
	* reg delta_arabic i.pair_id##i.grade repeated tayssir female gpa bl_theta_arabic bl_bottom_arabic bl_middle_arabic if treated ==0, cluster(pair_id)
	* reg delta_arabic i.pair_id##i.grade repeated tayssir female bl_theta_arabic bl_bottom_arabic bl_middle_arabic if treated ==0, cluster(pair_id)
	reg delta_arabic i.pair_id##i.grade if treated ==0, cluster(pair_id) // we'll let grf handle any controls, prediction of Y.hat, except for the strata
	predict res_arabic, res 
	
	* reg delta_french i.pair_id##i.grade repeated tayssir female gpa bl_theta_french bl_bottom_french bl_middle_french if treated ==0, cluster(pair_id)
	* reg delta_french i.pair_id##i.grade repeated tayssir female bl_theta_french bl_bottom_french bl_middle_french if treated ==0, cluster(pair_id)
	reg delta_french i.pair_id##i.grade if treated ==0, cluster(pair_id) // we'll let grf handle any controls, prediction of Y.hat, except for the strata
	predict res_french, res
	
	* reg delta_math i.pair_id##i.grade repeated tayssir female female gpa bl_theta_math bl_bottom_math bl_middle_math if treated ==0, cluster(pair_id)
	* reg delta_math i.pair_id##i.grade repeated tayssir female female bl_theta_math bl_bottom_math bl_middle_math if treated ==0, cluster(pair_id)
	reg delta_math i.pair_id##i.grade if treated ==0, cluster(pair_id) // we'll let grf handle any controls, prediction of Y.hat, except for the strata
	predict res_math, res	
	
	* Missing: We can calculate W.hat by hand, with our data (the assignment proportion), feed that W.hat into -grf-, rather than having -grf- predict W.hat with a separate regression forest
	
	* Stack 
	* order student_id school_id treated res_arabic res_french res_math grade? repeated female tayssir bl_* gpa n_teachers total_enrolled7_sum perc_female perc_ssbenef avg_score7_mu perc_tayssir 
	order student_id school_id treated res_arabic res_french res_math grade? repeated female tayssir gpa bl_* n_teachers total_enrolled7_sum perc_female perc_ssbenef avg_score7_mu perc_tayssir
	
	preserve
		keep if subject == 1
		lookfor arabic 
		foreach var of varlist `r(varlist)' {
			renvars `var', subst("_arabic" "")
		}
		drop *_french *_math
		label var bl_theta "Baseline score"
		label var theta "Endline score"
		tempfile arabic 
		save `arabic', replace
	restore 
	
	preserve
		keep if subject == 2
		lookfor french 
		foreach var of varlist `r(varlist)' {
			renvars `var', subst("_french" "")
		}
		drop *_arabic *_math
		label var bl_theta "Baseline score"
		label var theta "Endline score"
		tempfile french 
		save `french', replace
	restore 	
	
	preserve
		keep if subject == 3
		lookfor math 
		foreach var of varlist `r(varlist)' {
			renvars `var', subst("_math" "")
		}
		drop *_french *_arabic
		label var bl_theta "Baseline score"
		label var theta "Endline score"
		tempfile math 
		save `math', replace
	restore	
	
	clear
	append using `arabic'
	append using `french'
	append using `math'
	
	drop delta theta subject grade region province wrc
	order student_id school_id pair_id res treat
	
	drop theta_arabicat theta_arabicbelow se_theta_arabicat se_theta_arabicbelow
	
	drop _est_irtarabic theta*
	drop se_*
	
	* gpa retained for the causal forest (pre-registered Table A4 covariate; missing for grade-1 students, handled by grf's MIA)
	
	
	* Keep the main-text analysis sample (valid outcome, treatment, IDs). Allow
	* missing covariates: grf handles them natively (missingness-incorporated-in-
	* attributes), so the grf sample matches the main-text sample (attrition == 0)
	* rather than being narrowed to covariate-complete cases. temp7 is the grf
	* input only; temp6 (read by the main-text tables) is saved earlier, untouched.
	keep if !missing(res, treated, pair_id, school_id)
	
	* Save temp file to be used in R
	
	save "$temp7", replace

}

********************************************************************************
         * Appendix B measurement exhibits (Table B1, Figure B1) *
********************************************************************************

* Assembled from the per-subject captures above (the mb_ip_* item-parameter
* matrices and the mb_rel_*/mb_n_* endline reliability and counts). Writes the
* psychometric-properties snippet (output/tables/tableb1.txt) and the
* per-subject reliability-across-ability figures (output/plots/figureb1_<subj>.pdf,
* one per subject; Figure B1 has three LaTeX panels). Properties are
* reported for the endline-form items (variable-name stub a2/f2/m2), excluding
* baseline-only (a1/f1/m1) and cross-round drift (bldf_*) items. This block runs
* only within a full IRT run (the estimates must be live); a table-phase-only
* rerun leaves the existing exhibits untouched.

if "$measure" == "1" {

	local havemat 0
	foreach sj in arabic french math {
		capture confirm matrix mb_ip_`sj'
		if !_rc local havemat 1
	}

	if `havemat' {

		capture set scheme cleanplots

		tempname fh gh
		file open `fh' using "$tables/tableb1.txt", write replace
		file open `gh' using "$tables/tableb1_counts.tex", write replace

		local panels ""

		foreach sj in arabic french math {

			capture confirm matrix mb_ip_`sj'
			if _rc continue

			if "`sj'" == "arabic" {
				local LAB  "Arabic"
				local stub "a2"
				local tmp  "$eltemp/temp3.dta"
			}
			if "`sj'" == "french" {
				local LAB  "French"
				local stub "f2"
				local tmp  "$eltemp/temp4.dta"
			}
			if "`sj'" == "math" {
				local LAB  "Mathematics"
				local stub "m2"
				local tmp  "$eltemp/temp5.dta"
			}

			preserve

				* Endline item parameters -> mean a/b, item count, and (per subject)
				* the test information function -> SEM and conditional reliability.
				clear
				matrix _ip = mb_ip_`sj'
				local items : roweq _ip
				svmat double _ip, names(col)
				generate str32 _item = ""
				local i = 0
				foreach it of local items {
					local ++i
					quietly replace _item = "`it'" in `i'
				}
				quietly count if strpos(_item, "`stub'") == 1
				if r(N) > 0 quietly keep if strpos(_item, "`stub'") == 1

				quietly summarize a
				local mna = r(mean)
				quietly summarize b
				local mnb = r(mean)
				local nit = r(N)

				* 2PL test information over a theta grid.
				generate byte _one = 1
				tempfile itp
				quietly save `itp'

				clear
				set obs 301
				generate double th = -3 + (_n - 1)*0.02
				generate byte _one = 1
				joinby _one using `itp'
				generate double _p    = 1 / (1 + exp(-a*(th - b)))
				generate double _info = a^2 * _p * (1 - _p)
				collapse (sum) tif = _info, by(th)
				generate double sem = 1 / sqrt(tif)
				generate double rel = 1 / (1 + sem^2)

				twoway (line sem th, sort lpattern(solid) yaxis(1)) ///
				       (line rel th, sort lpattern(dash)  yaxis(2)), ///
					title("`LAB'", size(medium)) ///
					xtitle("Ability ({&theta})") xscale(range(-3 3)) xlabel(-3(1)3) ///
					ytitle("Standard error of measurement", axis(1)) yscale(range(0 2.5) axis(1)) ylabel(0(0.5)2.5, axis(1)) ///
					ytitle("Conditional reliability", axis(2)) yscale(range(0 1) axis(2)) ylabel(0(0.2)1, axis(2)) ///
					legend(order(1 "SEM" 2 "Reliability") rows(1) size(small)) ///
					name(mp_`sj', replace)

				* One PDF and PNG per subject; Figure B1 has three LaTeX panels.
				graph export "$figures/figureb1_`sj'.pdf", replace
				graph export "$figures/figureb1_`sj'.png", width(1600) replace

			restore

			* Average number of items administered per student (endline): the mean
			* across endline students of the non-missing item responses in the scored
			* temp file (each student answered only their grade-specific form).
			local psd = .
			capture confirm file "`tmp'"
			if !_rc {
				preserve
					use "`tmp'", clear
					quietly egen _nr = rownonmiss(`stub'*) if baseline == 0
					quietly summarize _nr if baseline == 0 & !missing(theta_`sj')
					local psd = r(mean)
				restore
			}

			local nn  = ${mb_n_`sj'}
			local rl  = ${mb_rel_`sj'}
			local nnc : display %12.0fc `nn'
			local nnc = trim("`nnc'")
			local avd : display %4.2f `mna'
			local dfd : display %5.2f `mnb'
			local rld : display %4.2f `rl'
			file write `fh' `"`LAB' & `nnc' & `avd' & `dfd' & `rld' \\"' _n
			* Item counts go in the table note (code-generated macros), not columns.
			file write `gh' `"\renewcommand{\bItems`sj'}{`nit'}"' _n
			file write `gh' `"\renewcommand{\bPer`sj'}{`=round(`psd')'}"' _n
		}

		file close `fh'
		file close `gh'
	}
}

/*
	* Calculating percent correct by subject, grade, and round (to be shared with the Ministry via email)

	use "$temp3", clear
	drop if attrition ==1
	dropmiss, force	
	drop area attrition answered
	drop feedbac
	drop f2123 f2124 f2125
	drop  f1117  f1118  f1119 f1120
	egen mean_arabic = rowmean(a*) if subject == 1
	egen mean_french = rowmean(f*) if subject == 2
	egen mean_math = rowmean(m*) if subject == 3
	foreach var of varlist mean_* {
		replace `var' = `var' * 100
	}
	
	
	tabstat mean_* if baseline ==0, by(treated) stat(mean n)
	tabstat mean_* if treated ==1 & baseline ==0, by(grade) stat(mean n)
	tabstat mean_* if treated ==0 & baseline ==0, by(grade) stat(mean n)
	
	preserve
		collapse mean_*, by(grade treated baseline)
		sort baseline treated grade
		tempfile t
		save `t'
	restore
	
	* Calculating percent correct overall at endline
	local i = 0 
	foreach s in  arabic french  math  {
		local i = `i' +1
		preserve
			keep if subject == `i'
			keep mean_`s' treated grade baseline
			rename mean mean
			tempfile file`i'
			save `file`i''
		restore
	}
	clear
	
	append using `file1'
	append using `file2'
	append using `file3'
	
	tabstat mean if baseline ==0, by(treated) stat(mean n)
	
	tabstat mean if treated ==1 & baseline ==0, by(grade) stat(mean n)
	tabstat mean if treated ==0 & baseline ==0, by(grade) stat(mean n)
	
	collapse mean, by(grade treated baseline)
	sort baseline treated grade
	merge 1:1 baseline treated grade using `t', nogen
	order baseline treated grade
	
	export excel using "$temp8", replace first(var)
	




