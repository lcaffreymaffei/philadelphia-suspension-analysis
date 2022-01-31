//shaping demographic file

	clear
	import excel "C:\Users\Lucy Caffrey Maffei\Downloads\SchoolFastFacts.xlsx", sheet("Sheet2") firstrow case(lower)
	replace dataelement = lower(trim(dataelement))
	gen keep = 1 if inlist(dataelement, "2 or more races","american indian/alaskan native","asian","black/african american","hispanic","native hawaiian or other pacific islander", "white")
	tab dataelement if keep == 1
	keep if keep == 1
	drop keep
	replace dataelement = subinstr(dataelement, "/", "_",.)
	replace dataelement= subinstr(dataelement, " ", "_",.)
	replace dataelement = subinstr(dataelement, "2", "two", .)
	replace dataelement = "native" if dataelement == "american_indian_alaskan_native"
	replace dataelement = "islander" if dataelement == "native_hawaiian_or_other_pacific_islander"
	format displayvalue %20s
	replace dataelement = "black" if dataelement == "black_african_american"
	reshape wide displayvalue, i( districtname aun name schl) j(dataelement)s
	rename schl schoolnumber
	tempfile demographic
	save `demographic'
	clear

//shaping pvaas to get AGIs

	import excel "Y:\Data and Analytics\Assessments\PVAAS\2018-PVAAS-State-wide-AGIs-w-GrMeasure-School-20181001 (1).xlsx", sheet("2018-PVAAS-State-wide-AGIs-w-Gr") firstrow case(lower)
	keep if inlist(grade, "4-8","N/A")
	drop if subject == "Biology"
	replace subject = lower(subject)
	keep districtaun schoolnumber districtname schoolname subject grade averagegrowthindexagi
	replace subject = subinstr(subject, " ", "_", .)
	rename averagegrowthindexagi agi
	drop grade
	reshape wide agi, i(districtaun districtname schoolnumber schoolname) j(subject)s
	tempfile agi
	save `agi'
	clear
	
//shaping safe schools file to get OSS
	import excel "Y:\Data and Analytics\Safety and Discipline\Publicly Available Data\2017-2018.xls", sheet("2017-2018") firstrow case(lower)
	preserve
	keep if missing(schoolnumber)
	drop if missing(aun)
	tempfile safeschools
	save `safeschools'
	restore
	drop if missing(aun)
	tempfile safeschoolswithpacode
	save `safeschoolswithpacode'
	clear
	use `safeschools'
	drop if strpos(leaname, " SD")
	rename aunbr aun
	tostring aun, force replace
	drop schoolnumber
	merge 1:m aun using `demographic'
	keep if _merge ==3
	duplicates tag aun, gen(dup)
	keep if dup == 0
	drop dup _merge displayvalueasian-displayvaluewhite districtname
	replace schoolname = name
	drop name
	destring schoolnumber, force replace
	append using `safeschoolswithpacode'
	destring aun, force replace
	replace aun = aunbr if missing(aun)
	drop aunbr
	order aun schoolnumber
	keep academicoss-weaponoss aun-year enrollment
	egen totaloss = rowtotal(academicoss conductoss drugandalcoholoss tobaccooss violenceoss weaponoss)
	tempfile schoolincidents
	save `schoolincidents'
	
//merging all 3 files
	drop if missing(schoolnumber)
	tostring schoolnumber, force replace
	merge 1:1 schoolnumber using `agi'
	drop if _merge == 1
	drop _merge
	tostring aun, force replace
	merge 1:1 schoolnumber using `demographic'
	tab schoolname if _merge == 2 & county == "Philadelphia"
	drop if _merge ==2
	drop _merge
	destring displayvalueasian, force replace
	destring displayvalueblack, force replace
	destring displayvalue*, force replace
	gen ossrate = totaloss/enrollment*100
//analytics
	regress ossrate displayvaluewhite
	corr ossrate displayvaluewhite
	regress ossrate displayvaluewhite if county == "Philadelphia"
	gen highminority = 1 if displayvaluewhite < 30
	replace highminority = 0 if missing(highminorit)
	regress ossrate highminority
	gen philadelphia = 1 if county == "Philadelphia"
	replace philadelphia = 0 if county != "Philadelphia"
	regress ossrate philadelphia
	regress ossrate philadelphia highminority
	tab philadelphia if highminority == 1
	tab highminority if philadelphia ==1
	tab highminority if philadelphia==0
	regress ossrate displayvalueasian
	regress ossrate displayvalueasian philadelphia
	egen districtminority = mean(displayvaluewhite), by (leaname)
	preserve
	keep if districtminority < 30
	regress ossrate philadelphia
	restore
	tempfile masterfile
	save `masterfile'


