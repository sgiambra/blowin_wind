set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    buil_geo_controls
    
    use p0030001 p0030002 p0030003 p0030005 zcta5 using /// 
        "${GoogleDrive}/raw_data/zip_controls/census_2010_sf1/sf12010860us3.dta", clear
    
    destring zcta5, gen(regionname)
    rename (p0030001 p0030002 p0030003 p0030005) ///
        (pop white_pop black_pop asian_pop)

    gen white_ratio = white_pop / pop
    gen black_ratio = black_pop / pop
    gen asian_ratio = asian_pop / pop
    keep regionname pop white_ratio black_ratio asian_ratio

    save_data "../temp/pop_controls.dta", key(regionname) replace
    
    use p0120001 p0120002 zcta5 using ///
        "${GoogleDrive}/raw_data/zip_controls/census_2010_sf1/sf12010860us4.dta", clear
    
    destring zcta5, gen(regionname)
    rename (p0120001 p0120002) (pop male)
    
    gen male_ratio = male / pop
    keep regionname male_ratio
    
    merge 1:1 regionname using "../temp/pop_controls.dta", ///
        nogen assert(3) keep(3)
    save_data "../temp/pop_controls.dta", key(regionname) replace
    
    build_zip_zcta_xwalk

    * Using income control we loose zipcodes. Need to look into this
    import delimited "${GoogleDrive}/raw_data/zip_controls/soi_tax/10zpallagi.csv", clear
    keep zipcode n1 a00100
    
    destring zipcode, replace
    keep if zipcode != 0    
    rename (n1 a00100) (returns adj_gr_income)
    
    collapse (sum) returns adj_gr_income, by(zipcode)
    gen avg_income = adj_gr_income / returns
    merge 1:1 zipcode using "../temp/zip_zcta_xwalk.dta", ///
        nogen keep(3) assert(1 2 3)
    
    merge 1:1 regionname using "../temp/pop_controls.dta", ///
        nogen assert(2 3) keep(3)
    merge 1:1 regionname using "../temp/zipcode_geo_controls.dta", ///
        nogen assert(1 2 3) keep(3)
    save_data "../temp/zip_controls.dta", key(regionname) replace
end

program buil_geo_controls
    * Need to derive these from raw data again
    import delimited "G:\My Drive\brown\labor\project\wind\data\output\DistanceFromCoast.txt", clear
    rename zip_code regionname
    keep regionname near_dist
    replace near_dist = near_dist / 1000

    save_data "../temp/zipcode_geo_controls.dta", replace key(regionname)

    import delimited "G:\My Drive\brown\labor\project\wind\data\output\Elevation.txt", clear
    keep zip_code rastervalu
    rename (zip_code rastervalu) (regionname elevation)
    drop if elevation == -9999

    merge 1:1 regionname using "../temp/zipcode_geo_controls.dta", ///
        nogen keep(3) assert(3)
    save_data "../temp/zipcode_geo_controls.dta", replace key(regionname)
end

program build_zip_zcta_xwalk
    import excel "${GoogleDrive}/raw_data/zipcode_zcta_xwalk/zip_to_zcta_2017.xlsx", ///
        sheet("Zip_to_ZCTA_2016") firstrow clear
    
    destring ZIP_CODE, gen(zipcode)
    destring ZCTA, gen(regionname)
    keep zipcode regionname
    
    save_data "../temp/zip_zcta_xwalk.dta", key(zipcode) replace
end

* Execute
main
