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

# Note that stringAsFactors=T is different from above
benchmark_results = read.csv('benchmark-results-all.csv', stringsAsFactors=T)

benchmarks = unique(benchmark_results[,"benchmark"])
print(benchmarks)

library(caret)
library(doParallel)
registerDoParallel()

predictors=list()
for (benchmark in benchmarks) {
  train_data = subset(benchmark_results[benchmark_results$benchmark == benchmark,], select=-c(benchmark))
	predictors[[benchmark]] = train(value~., data=train_data, model="avNNet", trControl=trainControl(method="cv"), tuneLength=3)
	#predictors[[benchmark]] = train(value~., data=train_data, model="rf", trControl=trainControl(method="cv"), tuneLength=3)
	#print(predictors[[benchmark]])

}

all_combinations=expand.grid(
  disks=c("8", "4x830", "4x840"),
  raid=c("raid0","raid5","raid6","raid00","raid10", "raid50", "raid60"),
  strip.size=c(64, 128, 256, 512, 1024),
  read.policy=c("normal", "ahead"),
  write.policy=c("write-back", "write-thru"),
  io.policy=c("cached", "direct"))

predictions=list()
rankings=list()
for (benchmark in benchmarks) {
  predictions[[benchmark]] = predict(predictors[[benchmark]], newdata=all_combinations)
  rankings[[benchmark]] = order(predictions[[benchmark]], decreasing=T)

  #print(rankings[[benchmark]])
}

combined_scores = seq_along(rankings[1])
for (ranking in rankings) {
  combined_scores = combined_scores + ranking^2
}

print("combined scores")
print(combined_scores)
print("best experiment")
best_score_idx = which.min(combined_scores)
print(all_combinations[best_score_idx,])
for (benchmark in benchmarks) {
  print(paste0("benchmark ", benchmark))
  print("Prediction of best")
  print(predictions[[benchmark]][best_score_idx])
  print("ranking of best")
  print(rankings[[benchmark]][best_score_idx])
}
print("combined score of best")
print(combined_scores[best_score_idx])
