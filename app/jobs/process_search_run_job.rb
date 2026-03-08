class ProcessSearchRunJob < ApplicationJob
  queue_as :default

  def perform(search_run_id)
    run = SearchRun.find(search_run_id)
    Search::ExecuteMonitor.call(monitor: run.monitor, search_run: run)
  end
end
