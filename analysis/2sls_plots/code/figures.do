set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local controls "i.year"

    foreach stub in "zip" "tract" {
        use "${GoogleDrive}/stata/build_wind_panel/wind_panel_`stub'_fhfa.dta", clear

        gen delta_lnp      = D.ln_p
        gen delta_turbines = D.aggr_turb_`stub'_year

        label var delta_turbines                "Yearly new installed turbines"
        label var delta_lnp                     "Yearly HPI change"
        label var first_us_turb_pot_wind_cap    "Area with wind power capacity > 30% x time first turbine US"

        binscatter delta_lnp first_us_turb_pot_wind_cap, ///
            xtitle(`: var label first_us_turb_pot_wind_cap') ytitle(`: var label delta_lnp')
        graph export "../output/price_change_wind_binsc_`stub'.png", replace

        * Residualize instrument
        reg first_us_turb_pot_wind_cap `controls'
        predict first_us_turb_pot_wind_cap_adj, residuals
        label var first_us_turb_pot_wind_cap_adj "Residualized area with wind power capacity > 30% x time first turbine US"

        foreach type in "" "_adj" {
            qui sum first_us_turb_pot_wind_cap`type', det
            local rng_min`type' = `r(p1)'
            local rng_max`type' = `r(p99)'
        }

        local inst_list   = "first_us_turb_pot_wind_cap first_us_turb_pot_wind_cap_adj first_us_turb_pot_wind_cap first_us_turb_pot_wind_cap_adj"
        local saving_list = "first_stage_`stub' fist_stage_adj_`stub' second_stage_`stub' second_stage_adj_`stub'"
        local var_list    = "delta_turbines delta_turbines delta_lnp delta_lnp"
        local range_list  = `""`rng_min' `rng_max'" "`rng_min_adj' `rng_max_adj'" "`rng_min' `rng_max'" "`rng_min_adj' `rng_max_adj'""'

        forval col_index = 1/4 {
            local inst   : word `col_index' of `inst_list'
            local saving : word `col_index' of `saving_list'
            local vars   : word `col_index' of `var_list'
            local ranges : word `col_index' of `range_list'

            build_2sls_plot, vars(`vars') inst(`inst') ranges(`ranges') saving(`saving')
        }
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
