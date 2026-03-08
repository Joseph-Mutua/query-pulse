class DetectIncidentsJob < ApplicationJob
  queue_as :low

  def perform(search_run_id)
    run = SearchRun.find(search_run_id)
    current = run.snapshot
    previous = run.monitor.snapshots.where(:captured_at.lt => current.captured_at).recent_first.first
    comparison = previous ? Comparison::ResultComparator.call(previous:, current:) : { "changes" => [] }
    Incidents::Detector.call(monitor: run.monitor, search_run: run, previous:, current:,
                             comparison:, assertion_results: run.assertion_results,
                             performance_metrics: Metrics::LatencyRegression.call(monitor: run.monitor))
  end
end
