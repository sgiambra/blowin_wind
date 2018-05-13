set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local farm_threshold 10

    build_false_wind_farms, stub(hazard) time(recdate)
    build_false_wind_farms, stub(notdetermined) time(recdate)
    build_false_wind_farms, stub(nobuiltdate) time(compdate)

    foreach stub in hazard notdetermined nobuiltdate {
        use "${GoogleDrive}/stata/build_wind_panel/wind_panel_zip_fhfa.dta", clear
        bys regionname: egen max_turbines_zip = max(aggr_turb_zip_year)
        keep if max_turbines_zip == 0
        drop wind_farm wind_farm_event
    
        merge 1:1 regionname year using "../temp/turbines_zip_`stub'.dta", ///
            assert(1 2 3) keep(1 2 3)
        gen wind_farm = 1 if (_merge == 2 | _merge == 3) & ///
            aggr_turb_zip_year_`stub' >= `farm_threshold'
        drop _merge
        
        bysort regionname (year): carryforward aggr_turb_zip_year_`stub' ///
            wind_farm, replace
        
        foreach var in new_turb_zip_year_`stub' aggr_turb_zip_year_`stub' wind_farm {
            replace `var' = 0 if `var' == .
        }
        
        egen wind_farm_event = min(cond(wind_farm == 1, ///
            year, .)), by(regionname)
        xtset regionname year

        save_data "${GoogleDrive}/stata/build_wind_panel/wind_panel_zip_fhfa_`stub'.dta", ///
            key(regionname year) replace
    }
end

program build_false_wind_farms
    syntax, stub(str) time(str)

    import delimited "${GoogleDrive}/gis_derived/zip_turbines_`stub'.csv", clear

    keep objectid_1 `time' zcta5ce10 strtype wsbegdt wsenddt
    keep if !missing(zcta5ce10)

    keep if wsbegdt == "" & wsenddt == ""    
    
    gen date = date(`time', "YMDhms")
    gen dt = mofd(date)
    format dt %tm
    gen year = year(date)
    keep if year > 1930 & year <= 2018

    drop if strtype != "Wind Turbine"

    collapse (count) new_turb_zip_year_`stub' = objectid_1, by(zcta5ce10 year)
    bys zcta5ce10 (year): gen aggr_turb_zip_year_`stub' = sum(new_turb_zip_year_`stub')
    rename zcta5ce10 regionname
    save_data "../temp/turbines_zip_`stub'.dta", key(regionname year) replace
end

* Execute
main
