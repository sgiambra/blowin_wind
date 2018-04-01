set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/stata/mental_coupons/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local input_file_list = "wind_panel_zip_median_listing_sqft " + ///
                            "wind_panel_zip_zhvi"

    foreach inpt in `input_file_list' {
        use "../temp/`inpt'_event_panel.dta", clear
        prepare_factor_info relative_ev_month if relevant_time_period
        local reg_opts = r(reg_opts)

        make_event_study_plot, depvar(ln_p) time(dt) geo(regionname) ///
            stub(month) saving(event_study_`inpt') `reg_opts'
    }

    use "../temp/wind_panel_tract_fhfa_event_panel.dta", clear
    prepare_factor_info relative_ev_year if relevant_time_period
    local reg_opts = r(reg_opts)

    make_event_study_plot, depvar(ln_p) time(year) geo(tract_fip) ///
        saving(event_study_wind_panel_tract_fhfa) `reg_opts'

    use "../temp/wind_panel_zip_fhfa_event_panel.dta", clear
    prepare_factor_info relative_ev_year if relevant_time_period
    local reg_opts = r(reg_opts)

    make_event_study_plot, depvar(ln_p) time(year) geo(regionname) ///
        saving(event_study_wind_panel_zip_fhfa) `reg_opts'
end

program prepare_factor_info, rclass
    syntax anything(name=factor_var) [if]

    qui levelsof `factor_var' `if', local(factor_levels)
    local num_factor_levels: word count `factor_levels'
    local median_factor_value = (`num_factor_levels' + 1)/2
    local base_factor_value = `median_factor_value' - 1
    return local reg_opts = "factor_levels(`factor_levels') " +             ///
                            "num_factor_levels(`num_factor_levels') " +     ///
                            "median_factor_value(`median_factor_value')" +  ///
                            "base_factor_value(`base_factor_value')"
end

program make_event_study_plot
    syntax, depvar(str) time(str) geo(str) factor_levels(str) num_factor_levels(str) ///
        median_factor_value(str) base_factor_value(str) saving(str) * [stub(str)]

    if "`stub'" == "" {
        local stub = "`time'"
    }

    areg `depvar' ib`base_factor_value'.relative_ev_`stub'_reggroups i.`time', ///
        absorb(`geo') vce(robust)

    plot_event_study i(1/`num_factor_levels')bn.relative_ev_`stub'_reggroups, ///
        label(`factor_levels') center xtitle(`: var label relative_ev_`stub'_reggroups') ///
        ytitle(`: var label `depvar'') xlabel(minmax `median_factor_value', value)      ///
        saving("../output/`saving'_`stub'.png") `options'
end

* Execute
main
