set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local table_file    "../output/tables.txt"
    local depvar        "D.ln_p"
    local instr         "first_us_turb_pot_wind_cap"

    use "${GoogleDrive}/stata/build_wind_panel/wind_panel_tract_fhfa.dta", clear

    build_descriptive_table, depvar(`depvar') endog("D.aggr_turb_tract_year") ///
            instr(`instr') time_fe(year) cluster(tract_fip)
    matrix fs_table  = r(fs_col)
    matrix ols_table = r(ols_col)
    matrix iv_table  = r(iv_col)

    use "${GoogleDrive}/stata/build_wind_panel/wind_panel_zip_fhfa.dta", clear

    build_descriptive_table, depvar(`depvar') endog("D.aggr_turb_zip_year") ///
            instr(`instr') time_fe(year) cluster(regionname)
    matrix fs_table  = (fs_table, r(fs_col))
    matrix ols_table = (ols_table, r(ols_col))
    matrix iv_table  = (iv_table, r(iv_col))

    foreach file in "wind_panel_zip_median_listing_sqft" "wind_panel_zip_zhvi" {
        use "${GoogleDrive}/stata/build_wind_panel/`file'.dta", clear

        build_descriptive_table, depvar(`depvar') endog("D.aggr_turb_zip_month") ///
            instr(`instr') time_fe(dt) cluster(regionname)
        matrix fs_table  = (nullmat(fs_table), r(fs_col))
        matrix ols_table = (nullmat(ols_table), r(ols_col))
        matrix iv_table  = (nullmat(iv_table), r(iv_col))
    }

    matrix_to_txt, saving(`table_file') mat(fs_table) ///
        format(%20.5f) title(<tab:descr_fs>) replace
    matrix_to_txt, saving(`table_file') mat(ols_table) ///
        format(%20.5f) title(<tab:descr_ols>) append
    matrix_to_txt, saving(`table_file') mat(iv_table) ///
        format(%20.5f) title(<tab:descr_iv>) append
end

program build_descriptive_table, rclass
    syntax, depvar(str) endog(str) instr(str) time_fe(str) [controls(str) *]

    local obs    = "e(N_clust) \ e(N)"
    local ss_est = "_b[`endog'] \ _se[`endog']"
    local fs_est = "_b[`instr'] \ _se[`instr']"

    reghdfe `endog' `instr' `controls', absorb(`time_fe') `options'
    matrix fs_col = (`fs_est' \ `obs')

    reghdfe `depvar' `controls' `endog', absorb(`time_fe') `options'
    matrix ols_col = (`ss_est' \ `obs')
    reghdfe `depvar' `controls' (`endog' = `instr'), absorb(`time_fe') `options'
    matrix iv_col = (`ss_est' \ `obs')

    return matrix fs_col  = fs_col
    return matrix ols_col = ols_col
    return matrix iv_col  = iv_col
end

* Execute
main
