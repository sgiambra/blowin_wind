set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries

program main
    local table_file "../output/tables.txt"
    local cluster_vars "regionname dt"
    
    build_descriptive_table, tables_file(`table_file') ///
        cluster(`cluster_vars')
end

program build_descriptive_table
    syntax, tables_file(str) [*]

    local endog = "wind_farm"
    local instr = "wind_zip_area_ratio"

    local obs    = "e(N_clust1) \ e(N)"
    local ss_est = "_b[`endog'] \ _se[`endog']"
    local fs_est = "_b[`instr'] \ _se[`instr']"

    use "../temp/wind_prices_turbines.dta", clear
    
    reghdfe `endog' `instr', absorb(dt) `options'
    matrix fs_col = (`fs_est' \ `obs')
    matrix fs_table = fs_col
    matrix_to_txt, saving(`tables_file') mat(fs_table) ///
        format(%20.5f) title(<tab:descr_fs>) replace

    reghdfe D.p `endog', absorb(dt) `options'
    matrix ols_col = (`ss_est' \ `obs')
    reghdfe D.p (`endog' = `instr'), absorb(dt) `options'
    matrix tsls_col = (`ss_est' \ `obs')
    matrix iv_table = (ols_col, tsls_col)
    matrix_to_txt, saving(`tables_file') mat(iv_table) ///
        format(%20.5f) title(<tab:descr_iv>) append
end

* Execute
main
