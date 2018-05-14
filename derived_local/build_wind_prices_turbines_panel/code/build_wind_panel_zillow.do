set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local input_file_list  = "Zip_MedianListingPricePerSqft_AllHomes " + ///
                             "Zip_Zhvi_AllHomes"
    local output_file_list = "wind_panel_zip_median_listing_sqft " + ///
                             "wind_panel_zip_zhvi"

    build_wind_farms, built_time(dtbuilt)

    forval col_index = 1/2 {
        local inpt : word `col_index' of `input_file_list'
        local outpt : word `col_index' of `output_file_list'

        build_zillow, input_file(`inpt')
        build_wind_panel_zip_month, output_file(`outpt') ///
            wind_file(pot_wind_cap_zip_2008) farm_threshold(10)
    }
end

program build_wind_farms
    syntax, built_time(str)

    import delimited "${GoogleDrive}/gis_derived/zip_turbines.csv", clear
    keep objectid_1 dtbuilt sprname zcta5ce10 agldet wsbegdt wsenddt recdate compdate strtype
    keep if !missing(zcta5ce10)
    
    gen date = date(`built_time', "YMDhms")
    gen dt = mofd(date)
    format dt %tm
    gen year = year(date)
    keep if year > 1930 & year <= 2018
    
    drop if missing(agldet)
    qui sum agldet, det
    keep if agldet > `r(p1)'

    drop if strtype != "Wind Turbine"

    save_data "${GoogleDrive}/stata/build_wind_panel/new_turbines_zip.dta", ///
        key(objectid_1) nopreserve replace

    collapse (count) new_turbines_zip_month = objectid_1, by(zcta5ce10 dt)
    bys zcta5ce10 (dt): gen aggr_turb_zip_month = sum(new_turbines_zip_month)
    rename zcta5ce10 regionname
    save_data "../temp/turbines_zip.dta", key(regionname dt) replace

    collapse (sum) new_turb_us_month = new_turbines_zip_month, by(dt)
    save_data "../temp/new_turbines_us_month.dta", key(dt) replace
end

program build_zillow
    syntax, input_file(str)

    import delimited "${GoogleDrive}/raw_data/house_prices/zillow/Zip/`input_file'.csv", clear
    
    qui ds v*
    foreach v of varlist `r(varlist)' {
        local x: variable label `v'
        local x: subinstr local x "-" "m"
        local x p`x'
        rename `v' `x'
    }

    rename regionname zipcode
    merge 1:1 zipcode using "${GoogleDrive}/stata/zip_zcta_xwalk.dta", ///
        nogen keep(3) assert(1 2 3) keepusing(regionname)
    drop zipcode

    collapse (mean) p* (first) city state metro county = county*, by(regionname)
    
    reshape long p, i(regionname) j(date, string)
    gen dt = monthly(date,"YM")
    format dt %tm

    save_data "../temp/zillow_prices.dta", key(regionname dt) replace
end

program build_wind_panel_zip_month
    syntax, output_file(str) wind_file(str) farm_threshold(int)

    use "../temp/zillow_prices.dta", clear

    rename state state_str
    egen state = group(state_str)
    gen ln_p = log(p)
    
    merge 1:1 regionname dt using "../temp/turbines_zip.dta", ///
        assert(1 2 3) keep(1 2 3)

    gen year = year(dofm(dt))
    gen wind_farm = 1 if (_merge == 2 | _merge == 3) ///
        & aggr_turb_zip_month >= `farm_threshold'
    drop _merge
    
    bysort regionname (dt): carryforward aggr_turb_zip_month wind_farm, replace
    foreach var in new_turbines_zip_month aggr_turb_zip_month wind_farm {
        replace `var' = 0 if `var' == .
    }
    egen wind_farm_event = min(cond(wind_farm == 1, ///
        dt, .)), by(regionname)
    drop if ln_p == .

    xtset regionname dt

    merge m:1 regionname using "${GoogleDrive}/stata/build_prelim_controls/`wind_file'.dta", ///
        nogen assert(1 2 3) keep(3)
    merge m:1 dt using "../temp/new_turbines_us_month.dta", ///
        nogen assert(1 2 3) keep(1 3)

    replace new_turb_us_month = 0 if new_turb_us_month == .
    gen new_turb_rmd_us_month = new_turb_us_month - new_turbines_zip_month
    gen subventions_pot_wind_cap = pot_wind_cap_zip_area*new_turb_rmd_us_month

    qui sum dt if new_turb_us_month > 0
    gen first_us_turb_pot_wind_cap = pot_wind_cap_zip_area if dt >= `r(min)'
    replace first_us_turb_pot_wind_cap = 0 if first_us_turb_pot_wind_cap == .
    
    save_data "${GoogleDrive}/stata/build_wind_panel/`output_file'.dta", ///
        key(regionname dt) replace

    merge m:1 regionname using "${GoogleDrive}/stata/build_prelim_controls/zip_controls.dta", ///
        nogen assert(1 2 3) keep(3)
    save_data "${GoogleDrive}/stata/build_wind_panel/`output_file'_controls.dta", ///
        key(regionname dt) replace
end

* Execute
main
