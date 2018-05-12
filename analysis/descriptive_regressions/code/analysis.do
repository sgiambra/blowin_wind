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
    matrix fs_table  = r(fs_cols)
    matrix ols_block = r(ols_cols)
    matrix iv_block  = r(iv_cols)

    use "${GoogleDrive}/stata/build_wind_panel/wind_panel_zip_fhfa.dta", clear

    build_descriptive_table, depvar(`depvar') endog("D.aggr_turb_zip_year") ///
            instr(`instr') time_fe(year) cluster(regionname)
    matrix fs_table  = (fs_table, r(fs_cols))
    matrix ols_block = (ols_block, r(ols_cols))
    matrix iv_block  = (iv_block, r(iv_cols))

    foreach file in "wind_panel_zip_median_listing_sqft" "wind_panel_zip_zhvi" {
        use "${GoogleDrive}/stata/build_wind_panel/`file'.dta", clear

        build_descriptive_table, depvar(`depvar') endog("D.aggr_turb_zip_month") ///
            instr(`instr') time_fe(dt) cluster(regionname)
        matrix fs_table  = (fs_table, r(fs_cols))
        matrix ols_block = (ols_block, r(ols_cols))
        matrix iv_block  = (iv_block, r(iv_cols))
    }
    matrix reg_table = (ols_block, iv_block)

    matrix_to_txt, saving(`table_file') mat(fs_table) ///
        format(%20.5f) title(<tab:descr_fs>) replace
    matrix_to_txt, saving(`table_file') mat(reg_table) ///
        format(%20.5f) title(<tab:descr_reg>) append
end

program build_descriptive_table, rclass
    syntax, depvar(str) endog(str) instr(str) time_fe(str) [*]

    local obs    = "e(N_clust) \ e(N)"
    local ss_est = "_b[`endog'] \ _se[`endog']"
    local fs_est = "_b[`instr'] \ _se[`instr']"

    foreach control in "" "i.state" {
        if "`control'" != "" {
            local stub "_c"
        } 
        reghdfe `endog' `instr' `control', absorb(`time_fe') `options'
        matrix fs_col`stub' = (`fs_est' \ `obs')

        reghdfe `depvar' `control' `endog', absorb(`time_fe') `options'
        matrix ols_col`stub' = (`ss_est' \ `obs')
        reghdfe `depvar' `control' (`endog' = `instr'), absorb(`time_fe') `options'
        matrix iv_col`stub' = (`ss_est' \ `obs')
    }

    foreach mat in fs_col ols_col iv_col {
        matrix `mat's = (`mat', `mat'_c)
    }
    return matrix fs_cols  = fs_cols
    return matrix ols_cols = ols_cols
    return matrix iv_cols  = iv_cols
end

* Execute
main
