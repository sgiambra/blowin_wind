set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    build_zillow_xls, input_file("Zip_MedianListingPricePerSqft_AllHomes")
    build_fhfa_xls
end

program build_zillow_xls
    syntax, input_file(str)

    import delimited "${GoogleDrive}/raw_data/house_prices/zillow/Zip/`input_file'.csv", clear
    
    qui ds v*
    foreach v of varlist `r(varlist)' {
        local x: variable label `v'
        local x: subinstr local x "-" "m"
        local x p`x'
        rename `v' `x'
    }

    rename regionname zipcode
    merge 1:1 zipcode using "${GoogleDrive}/stata/zip_zcta_xwalk.dta", ///
        nogen keep(3) assert(1 2 3) keepusing(regionname)
    drop zipcode

    collapse (mean) p* (first) city state metro countyname, by(regionname) 
    save_data "../temp/zillow_prices.dta", ///
        key(regionname) nopreserve replace
    
    import delimited "${GoogleDrive}/gis_derived/zip_area.csv", ///
        stringcol(1) clear
    destring zcta5ce10, gen(regionname)
    keep zcta5ce10 regionname
    
    merge 1:1 regionname using "../temp/zillow_prices.dta", ///
        keep(3) assert(1 2 3) nogen
    keep zcta5ce10 p2010m08 p2012m08
    gen price_diff = log(p2012m08) - log(p2010m08)
    
    export excel using "${GoogleDrive}/stata/zillow_zip.xls", replace
end

program build_fhfa_xls
    import excel "${GoogleDrive}/raw_data/house_prices/fhfa/HPI_AT_BDL_ZIP5.xlsx", ///
        sheet("ZIP5") cellrange(A7:F517721) firstrow clear
    rename (FiveDigitZIPCode Year HPIwith2000base) (zcta5ce10 year hpi2000)
    keep zcta5ce10 year hpi2000

    destring year hpi2000, replace
    keep if year == 2000 | year == 2005

    bys zcta5ce10 (year): gen hpi_diff = hpi2000[_n] - hpi2000[_n-1]
    keep if hpi_diff != .
    
    export excel using "${GoogleDrive}/stata/fhfa_zip.xls", replace
end

* Execute
main
