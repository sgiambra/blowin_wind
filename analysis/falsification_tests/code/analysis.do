set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local table_file    "../output/tables.txt"
    local depvar        "D.ln_p"

    use "${GoogleDrive}/stata/build_wind_panel/wind_panel_tract_fhfa.dta", clear

    build_falsification_table if new_turb_us_year == 0, ///
        depvar(`depvar') geo(tract) time_fe(year) cluster(tract_fip)
    matrix fals_table  = r(fals_cols)

    use "${GoogleDrive}/stata/build_wind_panel/wind_panel_zip_fhfa.dta", clear

    build_falsification_table if new_turb_us_year == 0, ///
        depvar(`depvar') geo(zip) time_fe(year) cluster(regionname)
    matrix fals_table  = (fals_table, r(fals_cols))

    use "${GoogleDrive}/stata/build_wind_panel/wind_panel_zip_zhvi.dta", clear

    build_falsification_table if new_turb_us_month == 0, ///
        depvar(`depvar') geo(zip) time_fe(dt) cluster(regionname)
    matrix fals_table  = (fals_table, r(fals_cols))

    matrix_to_txt, saving(`table_file') mat(fals_table) ///
        format(%20.6f) title(<tab:falsification>) replace
end

program build_falsification_table, rclass
    syntax [if], depvar(str) geo(str) time_fe(str) [*]

    local obs    = "e(N_clust) \ e(N)"
    local fals_est = "_b[pot_wind_cap_`geo'_area] \ _se[pot_wind_cap_`geo'_area]"

    foreach control in "" "i.state" {
        if "`control'" != "" {
            local stub "_c"
        }
        reghdfe `depvar' `control' pot_wind_cap_`geo'_area `if', ///
            absorb(`time_fe') `options'
        matrix fals_col`stub' = (`fals_est' \ `obs')
    }
    matrix fals_cols = (fals_col, fals_col_c)
    
    return matrix fals_cols  = fals_cols
end

* Execute
main
