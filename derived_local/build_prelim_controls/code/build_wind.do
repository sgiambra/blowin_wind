set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    local precision_km = 1

    build_pot_wind_cap_zip, stub(2008) precision(`precision_km') output_csv(True)
    build_pot_wind_cap_zip, stub(current) precision(`precision_km')
    build_pot_wind_cap_zip, stub(near_fut) precision(`precision_km') wind_lab("near future")

    build_pot_wind_cap_tract, precision(`precision_km')

    validate_pot_wind_cap
end

program build_pot_wind_cap_zip
    syntax, stub(str) precision(int) [output_csv(str), wind_lab(str)]

    if "`wind_lab'" == "" {
        local wind_lab = "`stub'"
    }

    import delimited "${GoogleDrive}/gis_derived/intersect_wind_zip_`stub'.csv", clear
        
    bys zcta5ce10: egen validate_area = total(area_intersect)
    assert (abs(validate_area - a_zip) / a_zip <= `precision')
    drop validate_area
    
    gen wgt_area_intersect = a30_ratio*area_intersect
    collapse a_zip (sum) tot_wgt_wind_zip = wgt_area_intersect, by(zcta5ce10)
    gen pot_wind_cap_zip_area = (tot_wgt_wind_zip / a_zip)*100
    gen regionname = zcta5ce10
    replace pot_wind_cap_zip_area = 100 if pot_wind_cap_zip_area > 100
    label var pot_wind_cap_zip_area "Weighted potential wind capacity, `wind_lab'"
    
    save_data "${GoogleDrive}/stata/build_prelim_controls/pot_wind_cap_zip_`stub'.dta", ///
        key(regionname) replace
    
    if "`output_csv'" == "True" {
        replace pot_wind_cap_zip_area = round(pot_wind_cap_zip_area, .001)
        export delimited using "${GoogleDrive}/stata/pot_wind_cap_zip_`stub'.csv", replace
    }
end

program build_pot_wind_cap_tract
    syntax, precision(int)

    import delimited "${GoogleDrive}/gis_derived/intersect_wind_tract_2008.csv", stringcols(4 5 6) clear
    gen tract_fip = state + county + tract
    keep if area_tract != 0

    bys tract_fip: egen validate_area = total(area_intersect)
    assert (abs(validate_area - area_tract) / area_tract <= `precision')
    drop validate_area

    gen wgt_area_intersect = a30_ratio*area_intersect
    collapse area_tract (sum) tot_wgt_wind_tract = wgt_area_intersect, by(tract_fip)
    gen pot_wind_cap_tract_area = (tot_wgt_wind_tract / area_tract)*100
    replace pot_wind_cap_tract_area = 100 if pot_wind_cap_tract_area > 100
    label var pot_wind_cap_tract_area "Weighted potential wind capacity, 2008"
    
    save_data "${GoogleDrive}/stata/build_prelim_controls/pot_wind_cap_tract_2008.dta", ///
        key(tract_fip) replace
end

program validate_pot_wind_cap
    use "${GoogleDrive}/stata/build_prelim_controls/pot_wind_cap_zip_2008.dta", clear
    keep regionname pot_wind_cap_zip_area
    rename pot_wind_cap_zip_area pot_wind_cap_zip_area_2008

    foreach stub in current near_fut {
        merge 1:1 regionname using "${GoogleDrive}/stata/build_prelim_controls/pot_wind_cap_zip_`stub'.dta", ///
            nogen assert(3) keep(3) keepusing(pot_wind_cap_zip_area)
        rename pot_wind_cap_zip_area pot_wind_cap_zip_area_`stub'
    }
    
    foreach stub in current near_fut {
        binscatter pot_wind_cap_zip_area_`stub' pot_wind_cap_zip_area_2008, ///
            ytitle("`: var label pot_wind_cap_zip_area_`stub''") ///
            xtitle("`: var label pot_wind_cap_zip_area_2008'")
        graph export "../output/pot_wind_cap_2008_`stub'.png", replace
    }
end

* Execute
main
