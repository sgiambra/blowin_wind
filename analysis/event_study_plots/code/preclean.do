set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local nbr_months 12
    local nbr_years 6

    local input_file_list = "wind_panel_zip_median_listing_sqft " + ///
                            "wind_panel_zip_zhvi"
    local labels_list     = `""Log median listing price per sqft ($)" "' + ///
                            `""Log ZHVI ($)""'

    forval col_index = 1/2 {
        local inpt : word `col_index' of `input_file_list'
        local lab_price : word `col_index' of `labels_list'

        use "${GoogleDrive}/stata/build_wind_panel/`inpt'.dta", clear
        generate_reggroups, window(`nbr_months') time(dt) geo(regionname) stub(month)
        *balance_panel, time(dt) geo(regionname) stub(month)
        
        label var relative_ev_month_reggroups ///
            "Months relative to completion of first wind farm in ZIP code"
        label var ln_p "`lab_price'"
        
        save_data "../temp/`inpt'_event_panel.dta", key(regionname dt) replace
    }

    use "${GoogleDrive}/stata/build_wind_panel/wind_panel_tract_fhfa.dta", clear
    generate_reggroups, window(`nbr_years') time(year) geo(tract_fip)
    *balance_panel, time(year) geo(tract_fip)

    label var relative_ev_year_reggroups ///
        "Years relative to completion of first wind farm in census tract"
    label var ln_p "Log HPI"

    save_data "../temp/wind_panel_tract_fhfa_event_panel.dta", key(tract_fip year) replace

    use "${GoogleDrive}/stata/build_wind_panel/wind_panel_zip_fhfa.dta", clear 
    generate_reggroups, window(`nbr_years') time(year) geo(regionname)
    *balance_panel, time(year) geo(regionname)
    
    label var relative_ev_year_reggroups ///
        "Years relative to completion of first wind farm in ZIP code"
    label var ln_p "Log HPI"

    save_data "../temp/wind_panel_zip_fhfa_event_panel.dta", key(regionname year) replace
end

program generate_reggroups
    syntax, window(int) time(str) geo(str) [stub(str)]

    if "`stub'" == "" {
        local stub = "`time'"
    }

    keep if !missing(wind_farm_event)

    gen relative_ev_`stub' = `time' - wind_farm_event
    sort `geo' relative_ev_`stub'
    gen relevant_time_period = (abs(relative_ev_`stub') <= `window')
    egen relative_ev_`stub'_reggroups = group(relative_ev_`stub') if relevant_time_period
    replace relative_ev_`stub'_reggroups = 0 if relative_ev_`stub' < -`window'
    replace relative_ev_`stub'_reggroups = 1000 if relative_ev_`stub' > `window'
end

program balance_panel
    syntax, time(str) geo(str) [stub(str)]

    if "`stub'" == "" {
        local stub = "`time'"
    }

    bys `geo' (`time'): egen sum_reggroups = total(relative_ev_`stub'_reggroups) ///
        if relevant_time_period
    bys `geo' (`time'): carryforward sum_reggroups, replace
    gsort `geo' -`time'
    bys `geo': carryforward sum_reggroups, replace

    qui levelsof relative_ev_`stub'_reggroups ///
        if relevant_time_period, local(levels) 
    foreach l of local levels {
        local i = `i' + `l'
    }
    keep if sum_reggroups == `i'
    drop sum_reggroups
end

* Execute
main
