set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local input_file_list  = "Zip_MedianListingPricePerSqft_AllHomes " + ///
                             "Zip_PctOfListingsWithPriceReductions_AllHomes"
    local output_file_list = "wind_panel_zip_median_listing_sqft " + ///
                             "wind_panel_zip_pct_price_red"

    build_wind_farms

    forval col_index = 1/2 {
        local inpt : word `col_index' of `input_file_list'
        local outpt : word `col_index' of `output_file_list'

        build_zillow, input_file(`inpt') stub(Zip)
        build_wind_panel, output_file(`outpt') ///
            wind_file(pot_wind_cap_zip_2008) farm_threshold(10)
    }
end

program build_wind_farms
    import delimited "${GoogleDrive}/gis_derived/zip_turbines.csv", clear
    keep objectid_1 dtbuilt sprname zcta5ce10 agldet
    keep if !missing(zcta5ce10)
    
    gen date = date(dtbuilt, "YMDhms")
    gen dt = mofd(date)
    format dt %tm
    generate year = year(date)
    keep if year > 1930 & year < 5000
    
    drop if missing(agldet)
    qui sum agldet, det
    keep if agldet > `r(p1)'
    bys zcta5ce10 dt: gen new_turbines_zip_month = _N

    save_data "${GoogleDrive}/stata/build_wind_panel/new_turbines_zip.dta", ///
        key(objectid_1) nopreserve replace

    collapse (mean) agldet new_turbines_zip_month, by(zcta5ce10 dt)
    
    bys zcta5ce10 (dt): gen aggr_turb_zip_month = sum(new_turbines_zip_month)
    gen sum_agldet = agldet*new_turbines_zip_month
    bys zcta5ce10 (dt): gen aggr_sum_agldet = sum(sum_agldet)
    gen avg_agldet = aggr_sum_agldet/aggr_turb_zip_month
    drop agldet sum_agldet aggr_sum_agldet

    rename zcta5ce10 regionname
    save_data "../temp/turbines_zip.dta", key(regionname dt) replace
end

program build_zillow
    syntax, input_file(str) stub(str)

    import delimited "${GoogleDrive}/raw_data/zillow/prices/`stub'/`input_file'.csv", clear
    
    qui ds v*
    foreach v of varlist `r(varlist)' {
        local x: variable label `v'
        local x: subinstr local x "-" "m"
        local x p`x'
        rename `v' `x'
    }

    rename regionname zipcode
    merge 1:1 zipcode using "${GoogleDrive}/stata/zip_zcta_xwalk.dta", ///
        nogen keep(3) assert(1 2 3)
    drop zipcode

    collapse (mean) p* (first) city state metro county = county*, by(regionname)
    
    reshape long p, i(regionname) j(date, string)
    gen dt = monthly(date,"YM")
    format dt %tm

    save_data "../temp/zillow_prices.dta", key(regionname dt) replace
end

program build_wind_panel
    syntax, output_file(str) wind_file(str) farm_threshold(int)

    use "../temp/zillow_prices.dta", clear

    egen county_nbr = group(county state)
    egen state_nbr  = group(state)
    
    merge 1:1 regionname dt using "../temp/turbines_zip.dta", ///
        assert(1 2 3) keep(1 2 3)

    gen year = year(dofm(dt))
    keep if p != .

    file open text using "../output/texttable_`output_file'.txt", write replace
        distinct regionname if _merge == 3
        file write text ("Zip Codes with wind farms and price data: `r(ndistinct)'") _n
        distinct regionname if _merge == 2
        file write text ("Zip Codes with wind farms but no price data: `r(ndistinct)'") _n
        distinct regionname if _merge == 1
        file write text ("Zip Codes price data but no wind farms: `r(ndistinct)'")
    file close text

    gen wind_farm = 1 if (_merge == 2 | _merge == 3) & aggr_turb_zip_month >= `farm_threshold'
    drop _merge
    
    bysort regionname (dt): carryforward aggr_turb_zip_month wind_farm avg_agldet, replace
    foreach var in new_turbines_zip_month aggr_turb_zip_month wind_farm avg_agldet {
        replace `var' = 0 if `var' == .
    }
    xtset regionname dt

    merge m:1 regionname using "${GoogleDrive}/stata/build_prelim_controls/`wind_file'.dta", ///
        nogen assert(1 2 3) keep(3)
    * Some zipcodes have info on prices but not on wind capacity
    * may be better to switch to wind speed
    save_data "${GoogleDrive}/stata/build_wind_panel/`output_file'.dta", ///
        key(regionname dt) replace

    merge m:1 regionname using "${GoogleDrive}/stata/build_prelim_controls/zip_controls.dta", ///
        nogen assert(1 2 3) keep(3)
    save_data "${GoogleDrive}/stata/build_wind_panel/`output_file'_controls.dta", ///
        key(regionname dt) replace
end

* Execute
main
