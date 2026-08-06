*******************************************************************************
* Appendix placebo / pre-trend test for the administrative DiD design (prints
* as Table A5).
*
* A falsification check for differential pre-trends / anticipation in the
* school-universe difference-in-differences design (equation "secondary" in
* the paper): the treatment is moved one year earlier and the true program
* year is dropped:
*   (1) DROP the 2023-24 program year (year==11).
*   (2) Move "post" one year earlier: post = 1{2022-23 (year==10)}. The placebo
*       "treatment" therefore lands in 2022-23, a PRE-program year.
* If parallel trends hold and there is no anticipation, the placebo treated x post
* coefficients should be near zero.
*
* Two domains, both on the window 2020-21..2022-23 (years 8,9,10), placebo
* post = 1{2022-23 (year==10)}:
*   COLUMNS 1-3 (enrollment): replicate Table 3's enrollment estimator (the
*     paper's surviving outcome domain) with the treatment shifted one year
*     earlier.
*   COLUMNS 4-7 (grade-6 national examination): the same estimator applied to
*     examination scores. This is valid here — unlike in Table 3, where the
*     examination was dropped as an outcome — because the ENTIRE placebo
*     window (2020-21..2022-23) predates the Ministry's 2023-24 change to the
*     examination administered in Pioneer Schools, so scores are comparable
*     across program and comparison schools throughout. The placebo therefore
*     doubles as a covariate-adjusted, matched-pair-clustered companion to
*     Figure 1's pre-program parallel-trends plot.
* (A longer pre-program exam panel back to 2014-15 exists, but the student
* characteristics needed for this covariate-adjusted spec and its subgroup
* panels are only available from 2019-20 on, so the placebo keeps the short
* covariate-complete window for all rows; the long-panel exam pre-trend is
* shown separately, covariate-free, in Figure 1.)
*
* Author:  Andy de Barros (adb)
* Created: 10 Jul 2026
* Estimator (each cell): reghdfe of the outcome on treated, the placebo DiD term
*   (treated x post), and baseline covariates (female, ever-repeated, age) each
*   interacted with post; absorbs pair x grade x year cell fixed effects and
*   clusters on the matched pair. Covariates, MHT families (Westfall-Young
*   stepdown), and panels (A/B/C) follow the same construction as 06-Table6's
*   enrollment domain (see that file's header and Appendix C/E). Writes
*   tableplacebo.txt; does NOT touch table3.txt. Control-mean row is the
*   2022-23 comparison-group mean.
*******************************************************************************

version 18
clear all
set more off
set seed 2816

do "code/_setup.do"
sysdir set PLUS "$code/ado"   // vendored packages (reghdfe, wyoung); session-scoped, as in 00_master.do

* ---- inputs ---------------------------------------------------------------
global exam6ap   "$restricted/exam_6ap/clean_exam_6AP_20260504_ll.dta"
global droppanel "$restricted/dropout/dropout_primary_school_Y1_20260618_ll.dta"
global charfile  "$restricted/student_characteristics/clean_10_student_characteristics_20260515_ll.dta"
global xwalk_sch "$restricted/crosswalk/IDSchool_effective_sample_neam.dta"
global tableplacebo "$tables/tableplacebo.txt"

* ---- 276 study schools: treatment + matched pair, keyed by cd_etab --------
use "$blclean/Baseline-tested-neam.dta", clear
bysort school_id: keep if _n==1
keep school_id treat pair_id
rename treat treated
merge 1:1 school_id using "$xwalk_sch", keep(match) nogen
assert _N==276
keep cd_etab treated pair_id
tempfile schools
save `schools'

* ---- time-varying "ever repeated a grade" indicator, from the enrollment panel ------
* Identical construction to 06-Table6: retook_{i,t} = 1 if the student has repeated
* in any year up to and INCLUDING t (a repeat in year s = same grade as the
* immediately preceding year). Built from the full panel history (2014/15-2024/25)
* so it can look back before the DiD years; merged by id_eleve x year.
use id_eleve year grade using "$droppanel", clear
bysort id_eleve year (grade): keep if _n==1        // one grade per student-year
bysort id_eleve (year): gen byte is_rep = (grade==grade[_n-1] & year==year[_n-1]+1) if _n>1
recode is_rep (.=0)
bysort id_eleve (year): gen byte retook = sum(is_rep) > 0    // cumulative: ever by year t
keep id_eleve year retook
tempfile everrep
save `everrep'

*------------------------------------------------------------------------------
* SMOKE TEST FIRST. B = 25 verifies the dofile completes, the coverage diagnostic
* is sane, and the placebo [adj p] rows are plausible; note the elapsed time, THEN
* raise B for the publication run. Running this dofile sequentially at B = 2500 is
* slow (the enrollment domain's ten Westfall-Young families are the long pole); the
* publication run was instead produced by running the ten Westfall-Young families
* as separate parallel Stata processes and combining their adjusted p-values. Point
* estimates/SEs are unchanged from the B = 25 smoke run (deterministic); only the
* bracketed adjusted p-values were regenerated.
*------------------------------------------------------------------------------
local B = 2500    // Westfall-Young bootstrap replications (publication run)
* pair x grade x year cell fixed effects (pgy) let every matched-pair-by-grade cell
* follow its own trend across years, mirroring Table 3's i.post#i.grade#i.pair_id.
local OPT "absorb(pgy) vce(cluster pair_id)"
* Right-hand side for every cell: the placebo DiD (treated + treated x post) plus the
* three baseline covariates and their post interactions.
local RHS "treated treatpost female retook age fem_po ret_po age_po"

* Format one cell from the estimates in memory: returns r(b), r(se), r(st).
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

* One Westfall-Young family. Reads $WYMODELS (compound-quoted model sequence) and
* $WYFP (familyp spec); returns r(p1)..r(p`nt') = stepdown-adjusted p-values in
* the order the models were supplied.
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

*******************************************************************************
* DOMAIN 1 — EXAM (administrative triangulation)
*   index tag  eov = exam_average_z ; components ear/efr/emath.
*   Window: 2020-21..2022-23 (years 8,9,10), placebo post==10 (2022-23).
*******************************************************************************
use cd_etab id_eleve year exam_average exam_ar exam_fr exam_math using "$exam6ap", clear
keep if inlist(year, 8, 9, 10)                        // 2020/21 .. 2022/23 (Table 3 window minus the program year)
merge m:1 cd_etab using `schools', keep(match) nogen
merge m:1 id_eleve using "$charfile", keepusing(gender birthdate) keep(master match) nogen
merge m:1 id_eleve year using `everrep', keep(master match) nogen   // time-varying ever-repeated -> retook
gen female = gender
* age at 1 September of the school year (year code 8..10 -> fall 2020..2022);
* set impossible birthdates missing before computing.
replace birthdate = . if !missing(birthdate) & (birthdate < td(01jan2000) | birthdate > td(31dec2020))
gen age = (mdy(9,1,2012+year) - birthdate)/365.25
gen grade      = 6
egen pair_grade = group(pair_id grade)
egen pgy        = group(pair_grade year)
gen post       = (year==10)
gen treatpost  = treated*post

* z-score each exam outcome within year vs the comparison group
foreach ev in exam_average exam_ar exam_fr exam_math {
	gen `ev'_z = .
	foreach y in 8 9 10 {
		qui sum `ev' if treated==0 & year==`y'
		replace `ev'_z = (`ev' - r(mean))/r(sd) if year==`y'
	}
}

* contrast interactions (gender, repeat)
gen fem_tr = female*treated
gen fem_po = female*post
gen fem_tp = female*treatpost
gen ret_tr = retook*treated
gen ret_po = retook*post
gen ret_tp = retook*treatpost
gen age_po = age*post

* coverage diagnostic (prints to the log): share of obs dropped for missing covariates
qui count
local N_all = r(N)
qui count if !missing(female, retook, age)
local N_cov = r(N)
di as result "COVERAGE (exam domain): " %4.1f 100*(`N_all'-`N_cov')/`N_all' "% of obs dropped for missing student characteristics (" %9.0fc `=`N_all'-`N_cov'' " of " %9.0fc `N_all' ")."

* ---- point estimates for every exam cell ---------------------------------
local tags  "eov ear efr emath"
local yvars "exam_average_z exam_ar_z exam_fr_z exam_math_z"
local nt : word count `tags'
forvalues i = 1/`nt' {
	local tag : word `i' of `tags'
	local y   : word `i' of `yvars'
	qui reghdfe `y' `RHS', `OPT'
	fmtcell treatpost
	local b_`tag'_A "`r(b)'"
	local se_`tag'_A "`r(se)'"
	local st_`tag'_A "`r(st)'"
	qui sum `y' if treated==0 & post==1 & !missing(female, retook, age)
	local cm_`tag' : di %4.2f r(mean)
	local cm_`tag' = strtrim("`cm_`tag''")
	foreach g in F M R N {
		if "`g'"=="F" local cond "female==1"
		if "`g'"=="M" local cond "female==0"
		if "`g'"=="R" local cond "retook==1"
		if "`g'"=="N" local cond "retook==0"
		qui reghdfe `y' `RHS' if `cond', `OPT'
		fmtcell treatpost
		local b_`tag'_`g' "`r(b)'"
		local se_`tag'_`g' "`r(se)'"
		local st_`tag'_`g' "`r(st)'"
	}
	qui reghdfe `y' `RHS' fem_tr fem_tp, `OPT'
	fmtcell fem_tp
	local b_`tag'_cg "`r(b)'"
	local se_`tag'_cg "`r(se)'"
	local st_`tag'_cg "`r(st)'"
	qui reghdfe `y' `RHS' ret_tr ret_tp if !missing(retook), `OPT'
	fmtcell ret_tp
	local b_`tag'_cr "`r(b)'"
	local se_`tag'_cr "`r(se)'"
	local st_`tag'_cr "`r(st)'"
}

* ---- WY families (exam) ---------------------------------------------------
global WYFP "treatpost"
* E1a: components among all students (3)
global WYMODELS ""
foreach y in exam_ar_z exam_fr_z exam_math_z {
	local m `"reghdfe `y' `RHS', `OPT'"'
	global WYMODELS `"$WYMODELS `"`m'"'"'
}
wyfam `B' 3
local ap_ear_A   = strtrim(string(r(p1),"%5.3f"))
local ap_efr_A   = strtrim(string(r(p2),"%5.3f"))
local ap_emath_A = strtrim(string(r(p3),"%5.3f"))
* E1b: index x 4 subgroups (4)
global WYMODELS ""
foreach cond in "female==1" "female==0" "retook==1" "retook==0" {
	local m `"reghdfe exam_average_z `RHS' if `cond', `OPT'"'
	global WYMODELS `"$WYMODELS `"`m'"'"'
}
wyfam `B' 4
local ap_eov_F = strtrim(string(r(p1),"%5.3f"))
local ap_eov_M = strtrim(string(r(p2),"%5.3f"))
local ap_eov_R = strtrim(string(r(p3),"%5.3f"))
local ap_eov_N = strtrim(string(r(p4),"%5.3f"))
* E2: components x 4 subgroups (12)
global WYMODELS ""
foreach y in exam_ar_z exam_fr_z exam_math_z {
	foreach cond in "female==1" "female==0" "retook==1" "retook==0" {
		local m `"reghdfe `y' `RHS' if `cond', `OPT'"'
		global WYMODELS `"$WYMODELS `"`m'"'"'
	}
}
wyfam `B' 12
local h = 0
foreach tag in ear efr emath {
	foreach g in F M R N {
		local ++h
		local ap_`tag'_`g' = strtrim(string(r(p`h'),"%5.3f"))
	}
}
* EC-idx: index x {gender, repeat} contrasts (2)
global WYMODELS ""
local m `"reghdfe exam_average_z `RHS' fem_tr fem_tp, `OPT'"'
global WYMODELS `"$WYMODELS `"`m'"'"'
local m `"reghdfe exam_average_z `RHS' ret_tr ret_tp if !missing(retook), `OPT'"'
global WYMODELS `"$WYMODELS `"`m'"'"'
global WYFP `""fem_tp" "ret_tp""'
wyfam `B' 2
local ap_eov_cg = strtrim(string(r(p1),"%5.3f"))
local ap_eov_cr = strtrim(string(r(p2),"%5.3f"))
* EC-sub: components x {gender, repeat} (6)
global WYMODELS ""
global WYFP ""
foreach y in exam_ar_z exam_fr_z exam_math_z {
	local m `"reghdfe `y' `RHS' fem_tr fem_tp, `OPT'"'
	global WYMODELS `"$WYMODELS `"`m'"'"'
	global WYFP `"$WYFP "fem_tp""'
	local m `"reghdfe `y' `RHS' ret_tr ret_tp if !missing(retook), `OPT'"'
	global WYMODELS `"$WYMODELS `"`m'"'"'
	global WYFP `"$WYFP "ret_tp""'
}
wyfam `B' 6
local h = 0
foreach tag in ear efr emath {
	foreach c in cg cr {
		local ++h
		local ap_`tag'_`c' = strtrim(string(r(p`h'),"%5.3f"))
	}
}

*******************************************************************************
* DOMAIN 2 — ENROLLMENT, short clean pre-program panel (years 8,9,10)
*   index tag  nxe = next-year re-enrollment (primary dropout outcome);
*   components prm = promotion, enr = within-year enrollment. Placebo post==10.
*******************************************************************************
use cd_etab id_eleve year result status grade next_year_enrollment using "$droppanel", clear
keep if inlist(year, 8, 9, 10)
keep if inrange(grade, 1, 6)
merge m:1 cd_etab using `schools', keep(match) nogen
merge m:1 id_eleve using "$charfile", keepusing(gender birthdate) keep(master match) nogen
merge m:1 id_eleve year using `everrep', keep(master match) nogen   // time-varying ever-repeated -> retook
gen female = gender
* age at 1 September of the school year (year code 8..10 -> fall 2020..2022);
* set impossible birthdates missing before computing.
replace birthdate = . if !missing(birthdate) & (birthdate < td(01jan2000) | birthdate > td(31dec2020))
gen age = (mdy(9,1,2012+year) - birthdate)/365.25
egen pair_grade = group(pair_id grade)
egen pgy        = group(pair_grade year)
gen post       = (year==10)
gen treatpost  = treated*post

* outcomes
gen promoted = 100*(result==1)                       // (component) promoted to next grade
gen enrolled = .                                     // (component) enrolled at year end
replace enrolled = 100 if inlist(status, 3, 4)
replace enrolled = 0   if inlist(status, 1, 2, 5)
gen nextenr  = .                                     // (index) re-enrolled next year
replace nextenr = 100 if inrange(next_year_enrollment, 1, 12)
replace nextenr = 0   if next_year_enrollment==0

* contrast interactions
gen fem_tr = female*treated
gen fem_po = female*post
gen fem_tp = female*treatpost
gen ret_tr = retook*treated
gen ret_po = retook*post
gen ret_tp = retook*treatpost
gen age_po = age*post

* coverage diagnostic (prints to the log): share of obs dropped for missing covariates
qui count
local N_all = r(N)
qui count if !missing(female, retook, age)
local N_cov = r(N)
di as result "COVERAGE (enrollment domain): " %4.1f 100*(`N_all'-`N_cov')/`N_all' "% of obs dropped for missing student characteristics (" %9.0fc `=`N_all'-`N_cov'' " of " %9.0fc `N_all' ")."

* ---- point estimates for every enrollment cell ---------------------------
local tags  "nxe prm enr"
local yvars "nextenr promoted enrolled"
local nt : word count `tags'
forvalues i = 1/`nt' {
	local tag : word `i' of `tags'
	local y   : word `i' of `yvars'
	qui reghdfe `y' `RHS', `OPT'
	fmtcell treatpost
	local b_`tag'_A "`r(b)'"
	local se_`tag'_A "`r(se)'"
	local st_`tag'_A "`r(st)'"
	qui sum `y' if treated==0 & post==1 & !missing(female, retook, age)
	local cm_`tag' : di %4.2f r(mean)
	local cm_`tag' = strtrim("`cm_`tag''")
	foreach g in F M R N {
		if "`g'"=="F" local cond "female==1"
		if "`g'"=="M" local cond "female==0"
		if "`g'"=="R" local cond "retook==1"
		if "`g'"=="N" local cond "retook==0"
		qui reghdfe `y' `RHS' if `cond', `OPT'
		fmtcell treatpost
		local b_`tag'_`g' "`r(b)'"
		local se_`tag'_`g' "`r(se)'"
		local st_`tag'_`g' "`r(st)'"
	}
	qui reghdfe `y' `RHS' fem_tr fem_tp, `OPT'
	fmtcell fem_tp
	local b_`tag'_cg "`r(b)'"
	local se_`tag'_cg "`r(se)'"
	local st_`tag'_cg "`r(st)'"
	qui reghdfe `y' `RHS' ret_tr ret_tp if !missing(retook), `OPT'
	fmtcell ret_tp
	local b_`tag'_cr "`r(b)'"
	local se_`tag'_cr "`r(se)'"
	local st_`tag'_cr "`r(st)'"
}

* ---- WY families (enrollment) --------------------------------------------
global WYFP "treatpost"
* P1a: components among all students (2)
global WYMODELS ""
foreach y in promoted enrolled {
	local m `"reghdfe `y' `RHS', `OPT'"'
	global WYMODELS `"$WYMODELS `"`m'"'"'
}
wyfam `B' 2
local ap_prm_A = strtrim(string(r(p1),"%5.3f"))
local ap_enr_A = strtrim(string(r(p2),"%5.3f"))
* P1b: index x 4 subgroups (4)
global WYMODELS ""
foreach cond in "female==1" "female==0" "retook==1" "retook==0" {
	local m `"reghdfe nextenr `RHS' if `cond', `OPT'"'
	global WYMODELS `"$WYMODELS `"`m'"'"'
}
wyfam `B' 4
local ap_nxe_F = strtrim(string(r(p1),"%5.3f"))
local ap_nxe_M = strtrim(string(r(p2),"%5.3f"))
local ap_nxe_R = strtrim(string(r(p3),"%5.3f"))
local ap_nxe_N = strtrim(string(r(p4),"%5.3f"))
* P2: components x 4 subgroups (8)
global WYMODELS ""
foreach y in promoted enrolled {
	foreach cond in "female==1" "female==0" "retook==1" "retook==0" {
		local m `"reghdfe `y' `RHS' if `cond', `OPT'"'
		global WYMODELS `"$WYMODELS `"`m'"'"'
	}
}
wyfam `B' 8
local h = 0
foreach tag in prm enr {
	foreach g in F M R N {
		local ++h
		local ap_`tag'_`g' = strtrim(string(r(p`h'),"%5.3f"))
	}
}
* PC-idx: index x {gender, repeat} contrasts (2)
global WYMODELS ""
local m `"reghdfe nextenr `RHS' fem_tr fem_tp, `OPT'"'
global WYMODELS `"$WYMODELS `"`m'"'"'
local m `"reghdfe nextenr `RHS' ret_tr ret_tp if !missing(retook), `OPT'"'
global WYMODELS `"$WYMODELS `"`m'"'"'
global WYFP `""fem_tp" "ret_tp""'
wyfam `B' 2
local ap_nxe_cg = strtrim(string(r(p1),"%5.3f"))
local ap_nxe_cr = strtrim(string(r(p2),"%5.3f"))
* PC-sub: components x {gender, repeat} (4)
global WYMODELS ""
global WYFP ""
foreach y in promoted enrolled {
	local m `"reghdfe `y' `RHS' fem_tr fem_tp, `OPT'"'
	global WYMODELS `"$WYMODELS `"`m'"'"'
	global WYFP `"$WYFP "fem_tp""'
	local m `"reghdfe `y' `RHS' ret_tr ret_tp if !missing(retook), `OPT'"'
	global WYMODELS `"$WYMODELS `"`m'"'"'
	global WYFP `"$WYFP "ret_tp""'
}
wyfam `B' 4
local h = 0
foreach tag in prm enr {
	foreach c in cg cr {
		local ++h
		local ap_`tag'_`c' = strtrim(string(r(p`h'),"%5.3f"))
	}
}

*******************************************************************************
* WRITE THE SNIPPET (7-column layout: enrollment domain matches table3.txt's
* 3 columns; the examination domain, valid on this pre-change window, is
* additional and no longer appears in table3.txt itself)
*   Column order: nxe prm enr | (gap) | eov | (gap) | ear efr emath
*   In Panel A the two indices (eov, nxe) carry no adjusted p (blank).
*******************************************************************************
cap file close a
file open a using "$tableplacebo", write replace

* ---- Panel A --------------------------------------------------------------
file write a "\textbf{Panel A: Overall} &   &   &   &   &   &   &   &   &   \\" _n
file write a "\multicolumn{1}{l}{All students}"
foreach tag in nxe prm enr eov ear efr emath {
	if inlist("`tag'","eov","ear") file write a " &"
	file write a " & `b_`tag'_A'`st_`tag'_A'"
}
file write a " \\" _n
file write a " "
foreach tag in nxe prm enr eov ear efr emath {
	if inlist("`tag'","eov","ear") file write a " &"
	file write a " & (`se_`tag'_A')"
}
file write a " \\" _n
file write a " "
foreach tag in nxe prm enr eov ear efr emath {
	if inlist("`tag'","eov","ear") file write a " &"
	if "`ap_`tag'_A'"=="" file write a " &"
	else file write a " & [`ap_`tag'_A']"
}
file write a " \\" _n

* ---- Panel B: gender (Female, Male, Female vs male) ------------------------
file write a "\textbf{Panel B: By gender} &   &   &   &   &   &   &   &   &   \\" _n
foreach grp in F M cg {
	if "`grp'"=="F"  local lab "Female"
	if "`grp'"=="M"  local lab "Male"
	if "`grp'"=="cg" local lab "Female vs male"
	file write a "\multicolumn{1}{l}{`lab'}"
	foreach tag in nxe prm enr eov ear efr emath {
		if inlist("`tag'","eov","ear") file write a " &"
		file write a " & `b_`tag'_`grp''`st_`tag'_`grp''"
	}
	file write a " \\" _n
	file write a " "
	foreach tag in nxe prm enr eov ear efr emath {
		if inlist("`tag'","eov","ear") file write a " &"
		file write a " & (`se_`tag'_`grp'')"
	}
	file write a " \\" _n
	file write a " "
	foreach tag in nxe prm enr eov ear efr emath {
		if inlist("`tag'","eov","ear") file write a " &"
		file write a " & [`ap_`tag'_`grp'']"
	}
	file write a " \\" _n
}

* ---- Panel C: repetition (Ever, Never, Ever vs never) ---------------------
file write a "\textbf{Panel C: Ever vs never repeated} &   &   &   &   &   &   &   &   &   \\" _n
foreach grp in R N cr {
	if "`grp'"=="R"  local lab "Ever repeated"
	if "`grp'"=="N"  local lab "Never repeated"
	if "`grp'"=="cr" local lab "Ever vs never repeated"
	file write a "\multicolumn{1}{l}{`lab'}"
	foreach tag in nxe prm enr eov ear efr emath {
		if inlist("`tag'","eov","ear") file write a " &"
		file write a " & `b_`tag'_`grp''`st_`tag'_`grp''"
	}
	file write a " \\" _n
	file write a " "
	foreach tag in nxe prm enr eov ear efr emath {
		if inlist("`tag'","eov","ear") file write a " &"
		file write a " & (`se_`tag'_`grp'')"
	}
	file write a " \\" _n
	file write a " "
	foreach tag in nxe prm enr eov ear efr emath {
		if inlist("`tag'","eov","ear") file write a " &"
		file write a " & [`ap_`tag'_`grp'']"
	}
	file write a " \\" _n
}

* ---- control mean ---------------------------------------------------------
file write a " \midrule" _n
file write a "Control mean (2022-23)"
foreach tag in nxe prm enr eov ear efr emath {
	if inlist("`tag'","eov","ear") file write a " &"
	file write a " & `cm_`tag''"
}
file write a " \\" _n
file close a
