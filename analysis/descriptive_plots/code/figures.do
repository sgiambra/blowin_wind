set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local keep_every 10
    
    plot_annual_new_turbines
    
    use "${GoogleDrive}/stata/build_wind_panel/wind_panel_zip_median_listing_sqft.dta", clear
    
    label var ln_p "Median listing price per sqft (ln $)"
    plot_prices_ts, geo(regionname) time(dt) ///
        saving(prices_ts_median_zip) stub("median listing price per sqft (ln $)")

    use "${GoogleDrive}/stata/build_wind_panel/wind_panel_zip_zhvi.dta", clear
    
    replace p = p/1000
    replace ln_p = log(p)
    label var ln_p "ZHVI (ln $1,000)"
    plot_prices_ts, geo(regionname) time(dt) ///
        saving(prices_ts_zhvi_zip) stub("ZHVI (ln $1,000)")
    build_prices_histogram if p <= 1000, saving(hist_zhvi_prices)
    build_prices_cdf if p <= 1000, keep_every(`keep_every') saving(cdf_zhvi_prices)

    validate_price_data
end

program plot_annual_new_turbines
    use "${GoogleDrive}/stata/build_wind_panel/new_turbines_zip.dta", clear
    
    keep if year >= 1998 & year <= 2017
    collapse (count) objectid_1, by(year)

    graph bar (asis) objectid_1, over(year, label(angle(45) labsize(small))) ///
        ytitle("Annual installed turbines")
    graph export "../output/annual_new_turbines.png", replace
end

program plot_prices_ts
    syntax, geo(str) time(str) saving(str) stub(str)

    if "`time'" == "dt" {
        local fmt "format(%tmMon-CCYY)"
        local xlab_step 30
    }
    if "`time'" == "year" {
        local xlab_step 5
    }

    preserve
        bys `geo' (`time'): egen ever_wind_farm = max(wind_farm)
        collapse (mean) ln_p, by(ever_wind_farm `time')
        tsset ever_wind_farm `time'
        
        label var ln_p "Average `stub'"
        qui sum `time'
        
        graph twoway (tsline ln_p if ever_wind_farm == 0, lpattern(dash) lcolor(gs3))  ///
            (tsline ln_p if ever_wind_farm == 1, lcolor(gs3)), ytitle(`: var label ln_p') ///
            xtitle("") xlabel(`r(min)'(`xlab_step')`r(max)', `fmt' labsize(3) angle(45))  ///
            legend(label(1 "No wind farm") label(2 "Wind farm"))
        graph export "../output/`saving'.png", replace
    restore
end

program build_prices_histogram
    syntax [if], saving(str)

    histogram ln_p `if', percent
    graph export "../output/`saving'.png", replace
end

program build_prices_cdf
    syntax [if], keep_every(int) saving(str)

    preserve
        cumul ln_p `if', gen(c_prices)
        label var c_prices "Cumulative probability"
        sort c_prices
        keep if _n == 1 | mod(_n, `keep_every') == 0
        line c_prices ln_p `if'
        graph export "../output/`saving'.png", replace
    restore
end

program validate_price_data
    use regionname p year using ///
        "${GoogleDrive}/stata/build_wind_panel/wind_panel_zip_median_listing_sqft.dta", clear
    avg_yearly_change p, stub(median_listing)

    use regionname p year using ///
        "${GoogleDrive}/stata/build_wind_panel/wind_panel_zip_zhvi.dta", clear
    replace p = p/1000
    avg_yearly_change p, stub(zhvi)

    foreach stub in zip tract {
        use "${GoogleDrive}/stata/build_wind_panel/wind_panel_`stub'_fhfa.dta", clear
        gen delta_ln_hpi_`stub' = D.ln_p
        collapse delta_ln_hpi_`stub', by(year)
        save_data "../temp/fhfa_`stub'_year", key(year) replace
    }

    use  "../temp/fhfa_tract_year", clear
    merge 1:1 year using "../temp/fhfa_zip_year", ///
        assert(1 2 3) keep(1 2 3) nogen 
    merge 1:1 year using "../temp/zhvi_year", ///
        assert(1 2 3) keep(1 2 3) nogen
    merge 1:1 year using "../temp/median_listing_year", ///
        assert(1 2 3) keep(1 2 3) nogen

    tsset year
    graph twoway (tsline delta_ln_hpi_zip, lcolor(gs6))  ///
        (tsline delta_ln_hpi_tract, lpattern(dot) lcolor(dkgreen) lwidth(medthick)) ///
        (tsline delta_ln_median_listing, lpattern(dash) lcolor(navy)) ///
        (tsline delta_ln_zhvi, lpattern(shortdash_dot) lcolor(black)), ///
        ytitle("Average percentage change") legend( ///
            lab(1 "Bogin et al (2016)" "ZIP") lab(2 "Bogin et al (2016)" "Census Tract") ///
            lab(3 "Median listing price") lab(4 "ZHVI"))
    graph export "../output/validate_price_data.png", replace
end

program avg_yearly_change
    syntax anything(name=price_var), stub(str)

    collapse `stub'_year = `price_var', by(regionname year)

    xtset regionname year
    gen ln_`stub'_year = log(`stub'_year)
    gen delta_ln_`stub' = D.ln_`stub'_year
    collapse delta_ln_`stub', by(year)
    save_data "../temp/`stub'_year", key(year) replace
end

* Execute
main
