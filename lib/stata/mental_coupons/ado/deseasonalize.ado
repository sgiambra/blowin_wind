program deseasonalize
    syntax anything(name = var_to_adj), unit(string) time(string) season(string)
    
    xtset `unit' `time'
    
    egen numeric_season = group(`season')
    quietly: sum numeric_season
    local n_seasons = `r(max)'
    by `unit': gen time_size = _n

    if mod(`n_seasons', 2) == 0{
        local lag = `n_seasons' / 2 - 1
        local lead = - `n_seasons' / 2  
        egen `var_to_adj'_ma`n_seasons' = filter(`var_to_adj'), lags(`lead'/`lag') normalise
        egen `var_to_adj'_ma2_`n_seasons' = filter(`var_to_adj'_ma`n_seasons'), lags(0/1) normalise
        gen `var_to_adj'_detr = `var_to_adj' - `var_to_adj'_ma2_`n_seasons'
    }

    else{
        local lag = (`n_seasons' - 1) / 2
        local lead = - (`n_seasons' - 1) / 2
        egen `var_to_adj'_ma = filter(`var_to_adj'), lags(`lead'/`lag') normalise
        gen `var_to_adj'_detr = `var_to_adj' - `var_to_adj'_ma
    }

    bysort `unit' numeric_season: egen `var_to_adj'_detr_avg = mean(`var_to_adj'_detr)
    bysort `unit' (`time'): egen `var_to_adj'_avg_detr_avg = mean(`var_to_adj'_detr_avg) if time_size <= `n_seasons'
    replace `var_to_adj'_avg_detr_avg = `var_to_adj'_avg_detr_avg[_n-1] if missing(`var_to_adj'_avg_detr_avg)
    gen `var_to_adj'_seasonal_comp = `var_to_adj'_detr_avg - `var_to_adj'_avg_detr_avg
    gen `var_to_adj'_seasonal_adj = `var_to_adj' - `var_to_adj'_seasonal_comp
    
    local var_to_drop numeric_season time_size `var_to_adj'_ma* `var_to_adj'_detr `var_to_adj'_detr_avg ///
        `var_to_adj'_avg_detr_avg `var_to_adj'_seasonal_comp
    drop `var_to_drop'
end
