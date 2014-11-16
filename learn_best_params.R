#!/usr/bin/env Rscript

testing=F

run_experiment = function(params) {
    params = lapply(params, as.character)
    if (testing) {
      # TESTING
      value = nchar(paste(params, collapse=","))
      print(paste('echo ', paste(c(params, "bm1", value), collapse=","), '>>benchmark-results-all.csv'))
      system(paste('echo ', paste(c(params, "bm1", value), collapse=","), '>>benchmark-results-all.csv'))
      print(paste('echo ', paste(c(params, "bm2", value ^ 2), collapse=","), '>>benchmark-results-all.csv'))
      system(paste('echo ', paste(c(params, "bm2", value ^ 2), collapse=","), '>>benchmark-results-all.csv'))
    } else {
      print(paste("rvm-exec 2.1@raidopt ruby ./run_experiment.rb", paste(lapply(params, as.character), collapse=" ")))
      status = system(paste("rvm-exec 2.1@raidopt ruby ./run_experiment.rb", paste(lapply(params, as.character), collapse=" ")))
      system(paste('echo ', paste(c(params, status), collapse=","), '>>benchmark-success-failure.csv'))

      if (status != 0) {
        stop("failed to run experiment")
      }
    }
}

get_benchmark_results = function() {
  if (file.exists('benchmark-results-all.csv')) {
    benchmark_results = read.csv('benchmark-results-all.csv', stringsAsFactors=T)
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
  return (benchmark_results)
}

experiment_has_been_run = function(params, benchmark_results) {
  if (missing(benchmark_results)) {
    benchmark_results = get_benchmark_results()
  }
  return (nrow(merge(params, benchmark_results)) != 0)
}

run_all_pairs_experiments = function() {

  all_pairs_experiments = read.csv('experiments.csv', stringsAsFactors=F)
  all_pairs_experiments = all_pairs_experiments[sample(nrow(all_pairs_experiments)),]
  #print(all_pairs_experiments)
  benchmark_results = get_benchmark_results()

  for (i in 1:nrow(all_pairs_experiments)) {
    params = all_pairs_experiments[i,]
    if (nrow(merge(params, benchmark_results)) == 0) {
      run_experiment(params)
    }
  }
}

get_all_experiments = function() {
  all_combinations=expand.grid(
    disks=c("8", "4x830", "4x840"),
    raid=c("raid0","raid5","raid6","raid00","raid10", "raid50", "raid60"),
    strip.size=c(64, 128, 256, 512, 1024),
    read.policy=c("normal", "ahead"),
    write.policy=c("write-back", "write-thru"),
    io.policy=c("cached", "direct"))
  return(all_combinations)
}

predict_benchmark_ranking = function(combinations_to_predict) {
  benchmark_results = get_benchmark_results()
  benchmarks = unique(benchmark_results[,"benchmark"])
  print(benchmarks)

  library(caret)
  library(doParallel)
  registerDoParallel()

  predictors=list()
  for (benchmark in benchmarks) {
    train_data = subset(benchmark_results[benchmark_results$benchmark == benchmark,], select=-c(benchmark))
    predictors[[benchmark]] = train(value~., data=train_data, model="avNNet", trControl=trainControl(method="repeatedcv"), tuneLength=15)
    #predictors[[benchmark]] = train(value~., data=train_data, model="rf", trControl=trainControl(method="cv"), tuneLength=3)
    #print(predictors[[benchmark]])

  }

  if (missing(combinations_to_predict)) {
    combinations_to_predict=get_all_experiments()
  }

  predictions=list()
  rankings=list()
  for (benchmark in benchmarks) {
    predictions[[benchmark]] = predict(predictors[[benchmark]], newdata=combinations_to_predict)
    rankings[[benchmark]] = rank(-predictions[[benchmark]], ties.method="average")

    #print(rankings[[benchmark]])
  }

  combined_scores = rep(0, length(rankings[1]))
  for (ranking in rankings) {
    combined_scores = combined_scores + ranking^2
  }

  print("combined scores")
  #print(combined_scores)
  print("best predicted experiment")
  best_score_idx = which.min(combined_scores)
  print(combinations_to_predict[best_score_idx,])
  #for (benchmark in benchmarks) {
    #print(paste0("benchmark ", benchmark))
    #print("Prediction of best")
    #print(predictions[[benchmark]][best_score_idx])
    #print("ranking of best")
    #print(rankings[[benchmark]][best_score_idx])
  #}
  print("combined score of best predicted experiment")
  print(combined_scores[best_score_idx])
  return(cbind(combinations_to_predict, combined_scores))
  #return(combinations_to_predict[order(combined_scores),])
}

best_benchmark = function() {
  #print("Looking for the best benchmark")
  benchmark_results = get_benchmark_results()

  # each benchmark has multiple rows; one for each time it ran, we need to summarize by taking the median
  # of the values for each configuration
  library(plyr, quietly=T)

  # Run the function median on the value of "value" for each group, 
  # broken down by experiment and benchmark
  benchmark_medians = ddply(benchmark_results, 
                c("disks", "raid", "strip.size", "read.policy", "write.policy", "io.policy", "benchmark"),
                summarise,
                median_value = median(value))

  # TODO: use the 3 sigma worst-case as the ranking, this accounts for the mean as well as punishing for a large variance

  #print(benchmark_medians)

  benchmarks = unique(benchmark_medians[,"benchmark"])

  # verify that all benchmarks have been run on all configurations
  for (benchmark in benchmarks) {
    num_configs = nrow(benchmark_medians[benchmark_medians$benchmark == benchmark,])
    if (!exists("expected_configs")) {
      expected_configs = num_configs
    } else {
      if (expected_configs != num_configs) {
        stop("expected configs: ", expected_configs, " found num_configs: " , num_configs)
      }
    }
  }

  rankings=list()
  for (benchmark in benchmarks) {
    bs = benchmark_medians[benchmark_medians$benchmark == benchmark,]
    sorted_benchmarks = bs[order(bs$disks, bs$raid, bs$strip.size, bs$read.policy, bs$write.policy, bs$io.policy),]
    rownames(sorted_benchmarks) <- 1:nrow(sorted_benchmarks)
    #print(sorted_benchmarks$median_value)
    rankings[[benchmark]] = rank(-sorted_benchmarks$median_value, ties.method="average")
    #print(sorted_benchmarks[rankings[[benchmark]],])
  }
  combined_scores = rep(0, length(rankings[1]))
  for (ranking in rankings) {
    #print("ranking")
    #print(ranking)
    combined_scores = combined_scores + ranking^2
  }

  #print("combined scores")
  #print(combined_scores)
  #print("best_score_idx")
  best_score_idx = which.min(combined_scores)
  #print(best_score_idx)
  #print("best experiment")
  #sb2 = sorted_benchmarks
  #rownames(sb2) <- 1:nrow(sb2)
  #print(sb2)
  #print(sb2[best_score_idx,])
  #print("combined score of best")
  #print(combined_scores[best_score_idx])

  return(sorted_benchmarks[best_score_idx,1:(ncol(sorted_benchmarks)-2)])
}

predict_optimal = function() {
  ranking = predict_benchmark_ranking()
  return(ranking[order(ranking$combined_scores),][1,1:(ncol(ranking)-1)])
}


print("beginning all-pairs experiments")
run_all_pairs_experiments()
print("Complete all-pairs experiments")

print("Beginning greedy search for experiments")
while (T) {
  best = predict_optimal()
  print("Predicted that the best solution is")
  print(best)
  if (experiment_has_been_run(best)) {
    print("experiment has already been run, terminating greedy search")
    break
  }
  print("running experiment for predicted best")
  run_experiment(best)
}

print("Finished greedy search. Found a predicted best experiment that has already been done.")
print("The best configuration found")
print(best_benchmark())

#return records from x.1 which are not in x.2
#http://stackoverflow.com/questions/7728462/identify-records-in-data-frame-a-not-contained-in-data-frame-b
fun.12 <- function(x.1,x.2,...){
  x.1p <- do.call("paste", x.1)
  x.2p <- do.call("paste", x.2)
  x.1[! x.1p %in% x.2p, ]
}

get_unexecuted_experiments = function() {
  fun.12(get_all_experiments(), subset(get_benchmark_results(), select=names(get_all_experiments())))
}
#print(nrow(get_all_experiments()))
#print(nrow(get_unexecuted_experiments()))

print("Starting random search, weighted toward best predictions.")
num_runs_without_improvement = 0
prev_best = best_benchmark()
while (num_runs_without_improvement < 5) {
  # For now, choose randomly from all experiments, not just unexecuted ones because there is some randomness and want to re-run best ones to get more data.
  unexecuted_experiments = get_all_experiments()
  #unexecuted_experiments = get_unexecuted_experiments()
  predictions_of_unexecuted_experiments = predict_benchmark_ranking(unexecuted_experiments)
  unexecuted_experiments = unexecuted_experiments[order(predictions_of_unexecuted_experiments$combined_score),]
  experiment_idx = round(min(rgamma(1, shape=1, scale=log(nrow(unexecuted_experiments))) + 0.5, nrow(unexecuted_experiments)))
  print("random experiment_idx")
  print(experiment_idx)
  experiment_to_run = unexecuted_experiments[experiment_idx,] # 1:(ncol(unexecuted_experiments)-1)]
  print("random experiment_to_run")
  print(experiment_to_run)
  run_experiment(experiment_to_run)
  print("current best benchmark")
  best = best_benchmark()
  print(best)
  #if (!isTRUE(all.equal(best, prev_best, check.names=F))) {
  if (nrow(merge(best, prev_best)) == 0) {
    print("Found new best")
    num_runs_without_improvement = 0
    prev_best = best
  } else {
    num_runs_without_improvement = num_runs_without_improvement + 1
    print("increased num_runs_without_improvement to:")
    print(num_runs_without_improvement)
  }
}
print("Finished random search")
print("The best configuration found")
print(best_benchmark())

print("Beginning second greedy search for experiments")
while (T) {
  best = predict_optimal()
  print("Predicted that the best solution is")
  print(best)
  if (experiment_has_been_run(best)) {
    print("experiment has already been run, terminating greedy search")
    break
  }
  print("running experiment for predicted best")
  run_experiment(best)
}

print("Finished second greedy search. Found a predicted best experiment that has already been done.")

print("Done")
print("The best configuration found")
print(best_benchmark())
