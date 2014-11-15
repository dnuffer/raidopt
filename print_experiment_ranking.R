#!/usr/bin/env Rscript

testing=F

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

ranked_benchmarks = function() {
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
                mean_value = mean(value),
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
    #rankings[[benchmark]] = rank(-sorted_benchmarks$median_value, ties.method="average")
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

  #return(sorted_benchmarks[order(sorted_benchmarks$combined_scores),1:(ncol(sorted_benchmarks)-2)])
  ranked_benchmarks = cbind(sorted_benchmarks, combined_scores)
  ranked_benchmarks = ranked_benchmarks[order(combined_scores), !(names(ranked_benchmarks) %in% c("benchmark", "median_value", "mean_value"))]
                                        
  return(ranked_benchmarks)
}

print(ranked_benchmarks())
