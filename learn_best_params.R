#!/usr/bin/env Rscript

testing=T

all_pairs_experiments = read.csv('experiments.csv', stringsAsFactors=F)
#print(all_pairs_experiments)
if (file.exists('benchmark-results-all.csv')) {
	benchmark_results = read.csv('benchmark-results-all.csv', stringsAsFactors=F)
} else {
	if (testing) {
		# TESTING: This header will be added by the actual benchmark
		system('echo "disks,raid,strip size,read policy,write policy,io policy,benchmark,value" >> benchmark-results-all.csv')
	}
	benchmark_results = data.frame(
		disks=character(),
		raid=character(),
		strip.size=character(),
		read.policy=character(),
		write.policy=character(),
		io.policy=character(),
		benchmark=character(),
		value=numeric(), 
		stringsAsFactors=F)
}
#print(benchmark_results)

trim <- function (x) gsub("^\\s+|\\s+$", "", x)

for (i in 1:nrow(all_pairs_experiments)) {
	params = all_pairs_experiments[i,]
	if (nrow(merge(params, benchmark_results)) == 0) {
		if (testing) {
			# TESTING
			value = nchar(paste(params, collapse=","))
			system(paste('echo ', paste(c(params, "bm1", value), collapse=","), '>>benchmark-results-all.csv'))
			system(paste('echo ', paste(c(params, "bm2", value ^ 2), collapse=","), '>>benchmark-results-all.csv'))
		} else {
			system(paste("rvm-exec 2.1@raidopt ruby ./run_experiment.rb", paste(params, collapse=" ")))
		}
	}
}

benchmark_results = read.csv('benchmark-results-all.csv', stringsAsFactors=F)

benchmarks = unique(benchmark_results[,"benchmark"])
print(benchmarks)

library(caret)

predictors=list()
for (benchmark in benchmarks) {
	predictors[[benchmark]] = train(value~.-benchmark, data=benchmark_results[benchmark_results$benchmark == benchmark,], model="rf", trControl=trainControl(method="cv"), tuneLength=3)
	summary(predictors[[benchmark]])
}
