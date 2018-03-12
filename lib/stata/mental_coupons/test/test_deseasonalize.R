require(data.table)

test_deseasonalize <- read.csv('test/temp/test_deseasonalize.csv')

calories_Tess <- test_deseasonalize[which(test_deseasonalize$person == 'Tess'),"calories"]
calories_Sam <- test_deseasonalize[which(test_deseasonalize$person == 'Sam'),"calories"]
calories_Arnold <- test_deseasonalize[which(test_deseasonalize$person == 'Arnold'),"calories"]

calories_Tess <- ts(calories_Tess, frequency = 4)
calories_Sam <- ts(calories_Sam, frequency = 4)
calories_Arnold <- ts(calories_Arnold, frequency = 4)

calories_Tess_decomposed <- decompose(calories_Tess)
calories_Sam_decomposed <- decompose(calories_Sam)
calories_Arnold_decomposed <- decompose(calories_Arnold)

calories_Tess_seasonal_adj_r <- calories_Tess - calories_Tess_decomposed$seasonal
calories_Sam_seasonal_adj_r <- calories_Sam - calories_Sam_decomposed$seasonal
calories_Arnold_seasonal_adj_r <- calories_Arnold - calories_Arnold_decomposed$seasonal

calories_seasonal_adj_r <- round(c(calories_Tess_seasonal_adj_r, calories_Sam_seasonal_adj_r, calories_Arnold_seasonal_adj_r), digits = 1)
calories_seasonal_adj <- round(test_deseasonalize[,"calories_seasonal_adj"], digits = 1)

all.equal(calories_seasonal_adj, calories_seasonal_adj_r)
