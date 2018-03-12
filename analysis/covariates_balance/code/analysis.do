set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local table_file "../output/tables.txt"
    local excluded_controls = "pop male_ratio white_ratio asian_ratio"
    local controls = "avg_income black_ratio elevation near_dist"
    local inst = "wind_zip_area_ratio"

    use "${GoogleDrive}/stata/wind_prices_turbines.dta", clear

    bys regionname: egen ever_wind_farm = max(wind_farm)
    duplicates drop regionname, force
    
    foreach control in `controls' {
        local c_est = "_b[`inst'] \ _se[`inst']"
        
        sum `control'
        matrix sample_means = (nullmat(sample_means) \ r(mean) \ r(sd))

        ttest `control', by(ever_wind_farm) unequal
        cap matrix drop no_windfarm_means windfarm_means diff
        matrix no_windfarm_means = (r(mu_1) \ r(sd_1))
        matrix windfarm_means = (r(mu_2) \ r(sd_2))
        matrix diff = (r(mu_2) - r(mu_1) \ r(se))
        matrix by_windfarm_means = (nullmat(by_windfarm_means) \ (windfarm_means, no_windfarm_means, diff))
        
        reg `control' `inst'
        matrix reg_means = (nullmat(reg_means) \ `c_est')
        
        local resid_controls: list controls- control
        reg `control' `inst' `resid_controls'
        matrix reg_control_means = (nullmat(reg_control_means) \ `c_est')
    }
    sample_sizes
    matrix sample_size = r(sample_size)

    *matrix TABLE = ((sample_means, by_windfarm_means, ///
    *                 reg_means, reg_control_means) \ sample_size)
    matrix TABLE_SLIDE = ((sample_means, by_windfarm_means) \ sample_size)

    matrix_to_txt, saving(`table_file') mat(TABLE_SLIDE) ///
        format(%20.5f) title(<tab:cov_balance_slide>) replace
end

program sample_sizes, rclass
    count
    scalar N = r(N)
    count if ever_wind_farm == 1
    scalar wind_farm_N = r(N)
    count if ever_wind_farm == 0
    scalar no_wind_farm_N = r(N)

    matrix sample_size = (N, wind_farm_N, no_wind_farm_N, N)
    return matrix sample_size = sample_size
end

* Execute
main
