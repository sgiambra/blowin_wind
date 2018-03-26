set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local keep_every 1
    
    plot_annual_new_turbines
    
    use "${GoogleDrive}/stata/build_wind_panel/wind_panel_zip_median_listing_sqft.dta", clear
    gen ln_p = log(p)
    label var ln_p "Median listing price per sqft (Log $1,000)"

    plot_prices_ts
    
    build_zillow_histogram if p <= 1000
    build_zillow_cdf if p <= 1000, keep_every(`keep_every')
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
    preserve
        bys regionname (dt): egen ever_wind_farm = max(wind_farm)
        collapse (mean) ln_p, by(ever_wind_farm dt)
        tsset ever_wind_farm dt
        
        label var ln_p "Median listing price per sqft (Log $1,000)"
        sum dt
        
        graph twoway (tsline ln_p if ever_wind_farm == 0, lpattern(dash) lcolor(gs3))  ///
            (tsline ln_p if ever_wind_farm == 1, lcolor(gs3)), ytitle(`: var label p') ///
            xtitle("") xlabel(`r(min)'(50)`r(max)', format(%tmMon-CCYY) labsize(3) angle(45))  ///
            legend(label(1 "No wind farm") label(2 "Wind farm"))
        graph export "../output/prices_ts.png", replace
    restore
end

program build_zillow_histogram
    syntax [if]

    histogram ln_p `if', percent
    graph export "../output/hist_zillow_prices.png", replace
end

program build_zillow_cdf
    syntax [if], keep_every(int)

    preserve
        cumul ln_p `if', gen(c_prices)
        label var c_prices "Cumulative probability"
        sort c_prices
        keep if _n == 1 | mod(_n, `keep_every') == 0
        line c_prices ln_p `if'
        graph export "../output/cdf_zillow_prices.png", replace
    restore
end

* Execute
main
