set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local controls = "avg_income pop male_ratio white_ratio " + ///
                     "black_ratio asian_ratio near_dist elevation"

    use "${GoogleDrive}/stata/wind_prices_turbines.dta", clear
    gen lnp = log(p)
    gen delta_lnp = D.lnp

    label var wind_farm             "Probability wind farm in Zip Code"
    label var delta_lnp             "Monthly change in ZHVI"
    label var wind_zip_area_ratio   "Zip Code area with wind power capacity > 30%"

    binscatter delta_lnp wind_zip_area_ratio, ///
        xtitle(`: var label wind_zip_area_ratio') ytitle(`: var label delta_lnp')
    graph export "../output/price_change_wind_binsc.png", replace

    * Residualize instrument
    reg wind_zip_area_ratio `controls'
    predict inst_resid_adj, residuals
    label var inst_resid_adj "Residualized Zip Code area with wind power capacity > 30%"

    local inst_list = "wind_zip_area_ratio inst_resid_adj wind_zip_area_ratio inst_resid_adj"
    local saving_list = "first_stage fist_stage_adj second_stage second_stage_adj"
    local var_list = "wind_farm wind_farm delta_lnp delta_lnp"
    local range_list = `""0 100" "-40 60" "0 100" "-40 60""'

    forval col_index = 1/4 {
        local inst : word `col_index' of `inst_list'
        local saving : word `col_index' of `saving_list'
        local vars : word `col_index' of `var_list'
        local ranges : word `col_index' of `range_list'

        build_2sls_plot, vars(`vars') inst(`inst') ranges(`ranges') saving(`saving')
    }
end

program build_2sls_plot
    syntax, vars(str) inst(str) ranges(str) saving(str) *

    preserve
        range points `ranges' 50

        lpoly `vars' `inst', degree(2) at(points) gen(`vars'_hat) se(`vars'_se) nograph

        local width_`vars': display %4.3f r(bwidth)
        gen `vars'_lb = `vars'_hat - 2*`vars'_se
        gen `vars'_ub = `vars'_hat + 2*`vars'_se
        
        line `vars'_lb `vars'_hat `vars'_ub points, ///
            lpattern(dash solid dash) legend(off) xtitle(`: var label `inst'') ///
            ytitle(`: var label `vars'') note("Notes: Bandwidth is `width_`vars''", span)
        graph export "../output/`saving'.png", replace
    restore
end

* Execute
main
