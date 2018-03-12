version 14
set more off
adopath + ado  

program main
    sysuse xtline1.dta, clear

    gen week = week(day)
    collapse (sum) calories, by (person week)
    sort person week
  
    *suppose a season repeats every 4 weeks
    gen season2 = mod((week-1), 4) + 1
    
    deseasonalize calories, unit(person) time(week) season(season) 

    outsheet using test/temp/test_deseasonalize.csv, comma replace
end
*execute
main
