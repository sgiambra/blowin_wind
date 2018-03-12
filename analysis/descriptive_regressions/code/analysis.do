set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local table_file    "../output/tables.txt"
    local cluster_vars  "regionname dt"
    local endog         "wind_farm"
    local instr         "wind_zip_area_ratio"

    use "${GoogleDrive}/stata/wind_prices_turbines.dta", clear
    gen ln_p = ln(p)
    
    build_descriptive_table, endog(`endog') instr(`instr') ///
        cluster(`cluster_vars')
    matrix fs_table = r(fs_col)
    matrix ols_block = r(ols_col)
    matrix tsls_block = r(tsls_col)

    local controls_list = "avg_income pop male_ratio white_ratio " + ///
                          "black_ratio asian_ratio near_dist elevation"

    build_descriptive_table, endog(`endog') instr(`instr') ///
        controls(`controls_list') cluster(`cluster_vars')
    matrix fs_table = (fs_table, r(fs_col))
    matrix ols_block = (ols_block, r(ols_col))
    matrix tsls_block = (tsls_block, r(tsls_col))

    matrix iv_table = (ols_block, tsls_block)

    matrix_to_txt, saving(`table_file') mat(fs_table) ///
        format(%20.5f) title(<tab:descr_fs>) replace
    matrix_to_txt, saving(`table_file') mat(iv_table) ///
        format(%20.5f) title(<tab:descr_iv>) append
end

program build_descriptive_table, rclass
    syntax, endog(str) instr(str) [controls(str) *]

    local obs    = "e(N_clust1) \ e(N)"
    local ss_est = "_b[`endog'] \ _se[`endog']"
    local fs_est = "_b[`instr'] \ _se[`instr']"

    reghdfe `endog' `instr' `controls', absorb(dt) `options'
    matrix fs_col = (`fs_est' \ `obs')

    reghdfe D.ln_p `controls' `endog', absorb(dt) `options'
    matrix ols_col = (`ss_est' \ `obs')
    reghdfe D.ln_p `controls' (`endog' = `instr'), absorb(dt) `options'
    matrix tsls_col = (`ss_est' \ `obs')

    return matrix fs_col = fs_col
    return matrix ols_col = ols_col
    return matrix tsls_col = tsls_col
end

* Execute
main
