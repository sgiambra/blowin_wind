set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    build_wind
    build_zillow
    build_wind_farms
end

program build_wind
    import delimited "${GoogleDrive}/gis_derived/intersect_wind_zip.csv", clear
    save "../temp/intersect_wind_zip.dta", replace
    
    import delimited "${GoogleDrive}/gis_derived/zip_area.csv", clear
    merge 1:m zcta5ce10 using "../temp/intersect_wind_zip.dta", ///
        keepusing(a30_ratio area_intersect) keep(3) assert(1 3) nogen
        
    bys zcta5ce10: egen validate_area = total(area_intersect)
    assert ((validate_area - area_zip)/area_zip < 0.001)
    drop validate_area
    
    gen w_area_intersect = a30_ratio*area_intersect
    collapse area_zip (sum) tot_w_wind_zip = w_area_intersect, by(zcta5ce10)
    gen wind_zip_area_ratio = (tot_w_wind_zip / area_zip)*100
    gen regionname = zcta5ce10
    drop if wind_zip_area_ratio > 100
    
    save_data "../temp/wind_zip_area_ratio.dta", ///
        key(regionname) replace
    
    replace wind_zip_area_ratio = round(wind_zip_area_ratio, .001)
    export delimited using "${GoogleDrive}/stata/zip_wind_weighted.csv", replace
end

program build_zillow
    import delimited "${GoogleDrive}/raw_data/zillow/prices/Zip_Zhvi_AllHomes.csv", clear
    
    foreach v of varlist v8-v269 {
        local x: variable label `v'
        local x: subinstr local x "-" "m"
        local x p`x'
        rename `v' `x'
    }
    save_data "../temp/zillow_prices.dta", key(regionname) replace
    
    import delimited "${GoogleDrive}/gis_derived/zip_area.csv", ///
        stringcol(1) clear
    destring zcta5ce10, gen(regionname)
    keep zcta5ce10 regionname
    
    merge 1:1 regionname using "../temp/zillow_prices.dta", keep(3) assert(1 2 3) nogen
    keep zcta5ce10 p2007m01
    
    export delimited using "${GoogleDrive}/stata/zillow_zip.csv", replace
end

program build_wind_farms
    import delimited "${GoogleDrive}/gis_derived/zip_turbines.csv", clear
    keep objectid_1 dtbuilt sprname zcta5ce10
    
    gen date = date(dtbuilt, "YMDhms")
    gen dt = mofd(date)
    format dt %tm
    generate year=year(date)
    keep if year > 1930 & year < 5000
    
    drop if sprname == ""
    bys sprname: gen nbr_turbines_by_prj = _N
    keep if nbr_turbines_by_prj >= 10
    bys zcta5ce10 dt: gen new_turbines_zip_month = _N
    
    egen t = tag(zcta5ce10 dt)
    keep if t == 1
    keep zcta5ce10 new_turbines_zip_month dt
    bys zcta5ce10 (dt): gen aggr_turb_zip_month = sum(new_turbines_zip_month)
    rename zcta5ce10 regionname
    save_data "../temp/turbines_zip.dta", key(regionname dt) replace
    
    use "../temp/zillow_prices.dta", clear
    reshape long p, i(regionname) j(date, string)
    gen dt = monthly(date,"YM")
    format dt %tm
    
    merge 1:1 regionname dt using "../temp/turbines_zip.dta", ///
        assert(1 2 3) keep(1 3)
    gen wind_farm = 1 if _merge == 3
    drop _merge
    
    bysort regionname (dt): carryforward aggr_turb_zip_month wind_farm, replace
    foreach var in new_turbines_zip_month aggr_turb_zip_month wind_farm {
        replace `var' = 0 if `var' == .
    }
    
    merge m:1 regionname using "../temp/wind_zip_area_ratio.dta", ///
        nogen assert(1 2 3) keep(3)
        
    xtset regionname dt
    save_data "${GoogleDrive}/stata/wind_prices_turbines.dta", ///
        key(regionname dt) replace
end

* Execute
main
