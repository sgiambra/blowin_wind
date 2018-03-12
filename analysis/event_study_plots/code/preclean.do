set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/stata/mental_coupons/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local nbr_quarters 6
    local nbr_months   12

    use "${GoogleDrive}/stata/wind_prices_turbines.dta", clear
    * Restrict to compliers
    * keep if wind_zip_area_ratio > 60

    gen ln_p = log(p)
    generate_reggroups, window(`nbr_months') time(dt) stub(month)
    label var relative_ev_month_reggroups "Months relative to completion of first wind turbine"
    save_data "../temp/event_panel_month.dta", key(regionname dt) replace
    
    use "${GoogleDrive}/stata/wind_prices_turbines.dta", clear
    * Restrict to compliers
    * keep if wind_zip_area_ratio > 60

    g qtr = qofd(dofm(dt))
    collapse (mean) p (sum) new_turbines_zip_qtr = new_turbines_zip_month, by(regionname qtr)
    gen ln_p = log(p)
    
    generate_reggroups, window(`nbr_quarters') time(qtr) stub(qtr)
    label var relative_ev_qtr_reggroups "Quarters relative to completion of first wind turbine"
    save_data "../temp/event_panel_qtr.dta", key(regionname qtr) replace
end

program generate_reggroups
    syntax, window(int) time(str) [stub(str)]

    egen wind_farm_event = min(cond(new_turbines_zip_`stub' > 0, ///
        `time', .)), by(regionname)

    keep if !missing(wind_farm_event)

    gen relative_ev_`stub' = `time' - wind_farm_event
    sort regionname relative_ev_`stub'
    gen relevant_time_period = (abs(relative_ev_`stub') <= `window')
    egen relative_ev_`stub'_reggroups = group(relative_ev_`stub') if relevant_time_period
    replace relative_ev_`stub'_reggroups = 0 if relative_ev_`stub' < -`window'
    replace relative_ev_`stub'_reggroups = 1000 if relative_ev_`stub' > `window'
end

* Execute
main
