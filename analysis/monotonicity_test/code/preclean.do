set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    build_geo_rural_urban

    use "${GoogleDrive}/stata/build_wind_panel/wind_panel_tract_fhfa.dta", clear
    gen fipsstcou = int(tract_fip/1000000)
    merge m:1 fipsstcou using "../temp/county_rural_urban.dta", ///
        nogen assert(1 2 3) keep(3)
    save_data "../temp/wind_panel_tract_fhfa_ru.dta", replace key(tract_fip year)

    use "${GoogleDrive}/stata/build_wind_panel/wind_panel_zip_fhfa.dta", clear
    merge m:1 regionname using "../temp/zip_rural_urban.dta", ///
        nogen assert(1 2 3) keep(3)
    save_data "../temp/wind_panel_zip_fhfa_ru.dta", replace key(regionname year)

    use "${GoogleDrive}/stata/build_wind_panel/wind_panel_zip_zhvi.dta", clear
    merge m:1 regionname using "../temp/zip_rural_urban.dta", ///
        nogen assert(1 2 3) keep(3)
    save_data "../temp/wind_panel_zip_zhvi_ru.dta", replace key(regionname dt)
end

program build_geo_rural_urban
    import excel "${GoogleDrive}/raw_data/rural_urban/t1101_ziprural.xls", ///
        sheet("Data") firstrow clear
    keep zip fipsstcou ru2003
    rename zip regionname
    save_data "../temp/zip_rural_urban.dta", key(regionname) replace

    duplicates drop fipsstcou, force
    keep fipsstcou ru2003
    save_data "../temp/county_rural_urban.dta", key(fipsstcou) replace
end

* Execute
main
