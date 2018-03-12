set more off
adopath + ../../../lib/stata/gslab_misc/ado
adopath + ../../../lib/third_party/stata_tools
preliminaries, loadglob("../../../lib/python/wind/input_params.txt")

program main
    import excel "${GoogleDrive}/raw_data/energy_data/Wind energy capacity_American Wind Energy Association.xls", ///
        sheet("Foglio1") firstrow

    graph bar (asis) cumulativecapacityMW,                  ///
        over(year, label(labsize(small)))                   ///
        ytitle("Cumulative Wind Power Capacity (MW)")       ///
        note("Source: American Wind Energy Association", span)
    graph export "../output/WindEnergyTrend.png", replace

    import excel "${GoogleDrive}/raw_data/energy_data/Wind energy capacity_American Wind Energy Association.xls", ///
        sheet("Foglio2") firstrow clear
    
    foreach v of varlist A-Z{
            local x : variable label `v'
            local q`v' = strtoname("`x'")
            ren `v' `q`v''
    }

    gen world=1
    reshape long _, i(world) j(year)
    rename _ energy_cons

    graph bar (asis) energy_cons, over(year, label(angle(45) labsize(small)))       ///
        ytitle("World Energy Consumption (Mtoe)") ylabel(5000(5000)15000) exclude0  ///
        note("Source: Global Energy Statistical Yearbook 2016", span)
    graph export "../output/WorldEnergyConsumption.png", replace
end

* Execute
main
