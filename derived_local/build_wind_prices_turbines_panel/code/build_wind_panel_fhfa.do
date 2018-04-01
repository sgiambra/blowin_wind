set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    build_wind_farms
    build_wind_panel_tract_year, farm_threshold(10)
    build_wind_panel_zip_year, farm_threshold(10)
end

program build_wind_farms
    import delimited "${GoogleDrive}/gis_derived/tract_turbines.csv", clear
    keep objectid_1 dtbuilt sprname geo_id agldet

    save_data "../temp/turbines_tract.dta", key(objectid_1) replace
    import delimited "${GoogleDrive}/gis_derived/census_tracts.csv", stringcols(2 3 4) clear
    gen tract_fip = state + county + tract
    merge 1:m geo_id using "../temp/turbines_tract.dta", ///
        nogen assert(1 2 3) keep(3)
    
    gen date = date(dtbuilt, "YMDhms")
    gen dt = mofd(date)
    format dt %tm
    generate year = year(date)
    keep if year > 1930 & year <= 2018
    
    drop if missing(agldet)
    qui sum agldet, det
    keep if agldet > `r(p1)'

    collapse (count) new_turbines_tract_year = objectid_1, by(tract_fip year)
    bys tract_fip (year): gen aggr_turb_tract_year = sum(new_turbines_tract_year)
    save_data "../temp/turbines_tract.dta", key(tract_fip year) replace

    collapse (sum) new_turb_us_year = new_turbines_tract_year, by(year)
    save_data "../temp/new_turbines_us_year.dta", key(year) replace
end

program build_wind_panel_tract_year
    syntax, farm_threshold(int)

    import delimited "${GoogleDrive}/raw_data/house_prices/fhfa/HPI_AT_BDL_tract.csv", ///
        stringcols(1) clear
    rename tract tract_fip
    merge_turbine_wind, geo(tract_fip) stub(tract) farm_threshold(`farm_threshold')
end

program build_wind_panel_zip_year
    syntax, farm_threshold(int)
    
    use "../temp/turbines_zip.dta", clear
    
    gen year = year(dofm(dt))
    collapse (sum) new_turbines_zip_year = new_turbines_zip_month ///
        (max) aggr_turb_zip_year = aggr_turb_zip_month, by(regionname year)
    save_data "../temp/turbines_zip.dta", key(regionnam year) replace

    collapse (sum) new_turb_us_year = new_turbines_zip_year, by(year)
    save_data "../temp/new_turbines_us_year.dta", key(year) replace

    import excel "${GoogleDrive}/raw_data/house_prices/fhfa/HPI_AT_BDL_ZIP5.xlsx", ///
        sheet("ZIP5") cellrange(A7:F517721) firstrow clear

    foreach var of varlist _all {
        destring `var', replace
    }
    rename (FiveDigitZIPCode Year HPI) (regionname year hpi)
    merge_turbine_wind, geo(regionname) stub(zip) farm_threshold(`farm_threshold')

    merge m:1 regionname using "${GoogleDrive}/stata/build_prelim_controls/zip_controls.dta", ///
        nogen assert(1 2 3) keep(3)
    save_data "${GoogleDrive}/stata/build_wind_panel/wind_panel_zip_fhfa_controls.dta", ///
        key(regionname year) replace
end

program merge_turbine_wind
    syntax, geo(str) stub(str) farm_threshold(int)

    gen ln_p = log(hpi)
    
    merge 1:1 `geo' year using "../temp/turbines_`stub'.dta", ///
        assert(1 2 3) keep(1 2 3)

    gen wind_farm = 1 if (_merge == 2 | _merge == 3) & ///
        aggr_turb_`stub'_year >= `farm_threshold'
    drop _merge
    
    bysort `geo' (year): carryforward aggr_turb_`stub'_year wind_farm, replace
    foreach var in new_turbines_`stub'_year aggr_turb_`stub'_year wind_farm {
        replace `var' = 0 if `var' == .
    }
    egen wind_farm_event = min(cond(wind_farm == 1, ///
        year, .)), by(`geo')
    drop if ln_p == .

    merge m:1 `geo' using "${GoogleDrive}/stata/build_prelim_controls/pot_wind_cap_`stub'_2008.dta", ///
        nogen assert(1 2 3) keep(3)
    merge m:1 year using "../temp/new_turbines_us_year.dta", ///
        nogen assert(1 2 3) keep(1 3)

    replace new_turb_us_year = 0 if new_turb_us_year == .
    gen new_turb_rmd_us_year = new_turb_us_year - new_turbines_`stub'_year
    gen subventions_pot_wind_cap = pot_wind_cap_`stub'_area*new_turb_rmd_us_year

    qui sum year if new_turb_us_year > 0
    gen first_us_turb_pot_wind_cap = pot_wind_cap_`stub'_area if year >= `r(min)'
    replace first_us_turb_pot_wind_cap = 0 if first_us_turb_pot_wind_cap == .
    
    if "`geo'" == "tract_fip" {
        destring `geo', replace
    }

    xtset `geo' year
    save_data "${GoogleDrive}/stata/build_wind_panel/wind_panel_`stub'_fhfa.dta", ///
        key(`geo' year) replace
end

* Execute
main
