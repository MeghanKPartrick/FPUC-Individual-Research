global origin "~/Dropbox/ECON580-2023DB"
capture cd "/Users/meghanpartrick/Documents/ECON580-Personal"

capture cd "~\Dropbox\CPS-shared"
use ECON580_cps_covid.dta, clear

use "/Users/meghanpartrick/Downloads/ECON580_cps_covid-3.dta", clear
***************************************************************************
*					Create variables
***************************************************************************

keep if year==2021
xtset inid date	

// Future Employment Status Variable
gen fempstat=f.empstat		// future employment status next month in t+1
label var fempstat "Employment status in t+1"

// Eligibility
tab whyunemp
tab whyunemp, nol
recode whyunemp 0=. 1/2=1 3/6=0, gen(ubeligible)
label var ubeligible "Eligible for unemployment benefits"
label define ubeligible 1 "UI eligible" 0 "UI ineligible"
label values ubeligible ubeligible

// Hours of work variable
recode uhrsworkt 997=. 999=.
gen fhours=f.uhrsworkt		// future hours next month in t+1
label var fhours "Hours worked in t+1"

// Employment variable
gen femployed=f.employed		// employment next month in t+1
label var femployed "Employment in t+1"

// Age group
gen age_cat = 0
replace age_cat = 1 if age>=23
label var age_cat "Age 23-64"

// Policy
gen post=1 if daydate>fpuc2_end
replace post=0 if daydate<=fpuc2_end
label define post 1 "Post-policy" 0 "Before policy" 
label values post post
label var post "FPUC-2 early withdrawal"

// Sample
keep if ubeligible<.
gen s=1 if month<9

// Vectors
global Z "female i.race i.foreign i.educ married nchild" 
*Y: fhours femployed
global FE "i.statefip i.month"
global X "ubeligible"
global M "age_cat"
sum fhours femployed $X $M $Z $FE

***************************************************************************
*					Heckmans
***************************************************************************

// Vectors
global Z "female i.race i.foreign married nchild" 
global FE "i.region i.month"
global R "yngch educ_mom educ_pop profcert"
sum fhours femployed $Z $R $FE

// Selection equation
reg femployed $Z $R $FE, robust  

// Estimate hours equation
reg fhours ubeligible $Z $FE, robust
outreg2 using selection.xls, replace ctitle(ols) bdec(3)

// Estimate hours equation with selection correction (heckman)
heckman fhours ubeligible $Z $FE, select(femployed=$R $Z $FE) twostep
outreg2 using selection.xls, append ctitle(2step) bdec(3)

heckman fhours ubeligible $Z $FE, select(femployed=$R $Z $FE) vce(robust)
outreg2 using selection.xls, append ctitle(mle) bdec(3) sortvar(ubeligible)


***************************************************************************
*					Heckprobit
***************************************************************************

// Binary outcomes 
gen ffulltime=(fhours>35) if fhours<.
label var ffulltime "=1 if in full time employment"
tab ffulltime femployed

// Heckprobit = probit model with selection bias correction
heckprobit ffulltime ubeligible $Z $FE, select(femployed=$R $Z $FE) vce(robust)



***************************************************************************
*					Multinomial Logit
***************************************************************************

clonevar group=ubeligible

gen post=1 if daydate>fpuc2_end
replace post=0 if daydate<=fpuc2_end
label define post 1 "Post-policy" 0 "Before policy" 
label values post post
label var post "FPUC-2 early withdrawal"

gen s=1 if month<9


// note: this step needs to be completed before restricting data to only unemployed people, otherwise there will be an error int he regression
gen fempstat=f.empstat		// future employment status next month in t+1
label var fempstat "Employment status in t+1"


mlogit fempstat i.post##i.group $Z $FE if s==1, base(1)

