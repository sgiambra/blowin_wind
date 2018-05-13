set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local table_file    "../output/tables.txt"
    local inst          "first_us_turb_pot_wind_cap"

    use "../temp/wind_panel_tract_fhfa_ru.dta", clear
    build_monotonicity_table, depvar(aggr_turb_tract_year) ///
        inst(`inst') time_fe(year) cluster(tract_fip)
    matrix monot_table = r(monot_block)

    use "../temp/wind_panel_zip_fhfa_ru.dta", clear
    build_monotonicity_table, depvar(aggr_turb_zip_year) ///
        inst(`inst') time_fe(year) cluster(regionname)
    matrix monot_table = (monot_table \ r(monot_block))

    use "../temp/wind_panel_zip_zhvi_ru.dta", clear
    build_monotonicity_table, depvar(aggr_turb_zip_month) ///
        inst(`inst') time_fe(dt) cluster(regionname)
    matrix monot_table  = (monot_table \ r(monot_block))

    matrix_to_txt, saving(`table_file') mat(monot_table) ///
        format(%20.6f) title(<tab:monotonicity>) append
end

program build_monotonicity_table, rclass
    syntax, depvar(str) inst(str) time_fe(str) [*]

    local obs     = "(e(N_clust) \ .), (e(N) \ .)"
    local mon_est = "(_b[`inst'] \ _se[`inst'])"
    
    forval rural_status = 1/9 {
        reghdfe D.`depvar' `inst' if ru2003 == `rural_status', ///
            absorb(`time_fe') `options'

        matrix monot_block = (nullmat(monot_block)\ `mon_est', `obs') 
    }
    return matrix monot_block = monot_block
end

* Execute
main
