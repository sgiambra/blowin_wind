program plot_event_study
    syntax anything(name = plot_vars) [, estimates(string) saving(string) center ///
        match_range(string) shift_targets(string) xtitle(string) ytitle(string)  ///
        weight_cond(string) yline_patterns(string) yaxis(string) lcolor(string) fcolor(string) *] 

    if "`lcolor'" != "" local lcolor_opts "lcolor(`lcolor')"
    else local lcolor_opts "lcolor(gs8)"
    if "`fcolor'" != "" local fcolor_opts "fcolor(`fcolor')"
    else local fcolor_opts "fcolor(gs8)"

    preserve
    if "`yaxis'" == "" local yaxis = "1"
    if "`estimates'" == "" {
        estimates sto current_est
        local estimates = "current_est"
    }

    foreach object in estimates shift_targets yaxis match_range yline_patterns { 
        local num_`object' : word count ``object'' 
        local check_args "`check_args' num_`object'(`num_`object'')"
    }
    check_valid_arguments `plot_vars', `check_args'
    if `num_yline_patterns' == 0 local yline_pattern "lpattern(dot)"

    if "`center'" != "" {
        forval i = 1/`num_estimates' {
            local estimate: word `i' of `estimates'
            if `num_yaxis' == 1 local yaxis_id = `yaxis'
            else local yaxis_id: word `i' of `yaxis'
            if `num_shift_targets' > 0 local target: word `i' of `shift_targets'
            if `num_yline_patterns' > 0 local yline_pattern: word `i' of `yline_patterns' 
            quietly estimate restore `estimate'
            center_estimates `plot_vars', target(`target') weight_cond(`weight_cond')
            local yshifts "`yshifts' `r(diff_to_mean)'"
            local yline_opts "`yline_opts' yline(`r(target_mean)', `yline_pattern' axis(`yaxis_id'))"
            local y_center_`i' = r(target_mean)
        }
        local yshift_opts "yshift(`yshifts')"
    }

    if "`match_range'" != "" {
        extract_plot_range using `match_range'
        local range = r(range)
        forval i = 1/`num_yaxis' {
            local yaxis_id: word `i' of `yaxis'
            * Include at least as much range as estimation results in `match_range'
            local include_range_lower = `y_center_`i'' - `range' / 2
            local include_range_upper = `y_center_`i'' + `range' / 2
            local yscale_opts = "`yscale_opts' ylabel(#6, axis(`yaxis_id')) " + ///
                "yscale(range(`include_range_lower' `include_range_upper') axis(`yaxis_id'))"
        }           
    }

    forval i = 1/`num_yaxis' {
        local yaxis_`i': word `i' of `yaxis'
        local yaxis_opts "`yaxis_opts' yaxis(`yaxis_`i'')"
    }

    plotcoeffs `plot_vars', estimates(`estimates') `lcolor_opts' `fcolor_opts' `yline_opts' ///
        `yshift_opts' `yscale_opts' ytitle(`ytitle') xtitle(`xtitle') yaxis(`yaxis_opts') `options' 

    if "`saving'" != "" graph export `saving', replace
    restore
end

program check_valid_arguments
    syntax varlist(fv), num_estimates(integer) num_shift_targets(integer) num_yaxis(integer) ///
        num_match_range(integer) num_yline_patterns(integer) 

    if  "`s(fvops)'" != "true" {
        dis as error "ERROR: plot_event_study must be passed a factor variable."
        error -1
    }

    if `num_yaxis' > 1 & `num_estimates' != `num_yaxis' {
        dis as error "ERROR: The number of axis IDs in yaxis() must be zero or one"
        dis as error "       or equal the number estimates."
        error -1
    }
    if !inlist(`num_shift_targets', `num_estimates', 0) {
        dis as error "ERROR: The number of variables in shift_targets() must"
        dis as error "       be zero or equal the number of estimates."
        error -1
    }   
    if !inlist(`num_yline_patterns', `num_estimates', 0) {
        dis as error "ERROR: The number of variables in yline_patterns() must"
        dis as error "       be zero or equal the number of estimates."
        error -1
    }   
    if `num_match_range' > 0 & `num_yaxis' != `num_estimates' {
        dis as error "ERROR: If match_range() is specified, the number of axis IDs in yaxis()"
        dis as error "       must equal the number of estimates."
        error -1
    }
end

program extract_plot_range, rclass
    syntax using
    
    preserve
    use `using'
    local minimum = .
    local maximum = .
    foreach var of varlist l_* {
        quietly sum `var'
        local minimum = min(`minimum', r(min))
    }
    foreach var of varlist u_* {
        quietly sum `var'
        local maximum = max(`maximum', r(max))
    }
    return local range = (`maximum' - `minimum') * 1.05
    restore
end
