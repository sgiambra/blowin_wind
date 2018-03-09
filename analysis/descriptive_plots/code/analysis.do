set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    plot_annual_new_turbines
    plot_prices_ts
end

program plot_annual_new_turbines
    import delimited "${GoogleDrive}/gis_derived/zip_turbines.csv", clear
    keep objectid_1 dtbuilt sprname
    
    gen date = date(dtbuilt, "YMDhms")
    gen dt = mofd(date)
    format dt %tm
    generate year=year(date)
    keep if year > 1930 & year < 5000
    
    drop if sprname == ""
    bys sprname: gen nbr_turbines_by_prj = _N
    keep if nbr_turbines_by_prj >= 10
    keep if year >= 1998 & year <= 2017
    collapse (count) objectid_1, by(year)

    graph bar (asis) objectid_1, over(year, label(angle(45) labsize(small))) ///
        ytitle("Annual installed turbines")
    graph export "../output/annual_new_turbines.png", replace
end

program plot_prices_ts
    use "${GoogleDrive}/stata/wind_prices_turbines.dta", clear
    bys regionname (dt): egen ever_wind_farm = max(wind_farm)
    collapse (mean) p, by(ever_wind_farm dt)
    tsset ever_wind_farm dt
    
    replace p = p/1000
    label var p "Average Zillow Home Value Index (1,000$)"
    
    graph twoway (tsline p if ever_wind_farm == 0, lpattern(dash) lcolor(gs3)) ///
        (tsline p if ever_wind_farm == 1, lcolor(gs3)), ytitle(`: var label p') ///
        xtitle("") legend(label(1 "No wind farm") label(2 "Wind farm"))
    graph export "../output/prices_ts.png", replace
end

* Execute
main
