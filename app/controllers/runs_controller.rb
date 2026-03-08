class RunsController < ApplicationController
  def show
    @run = SearchRun.find(params[:id])
    @monitor = @run.monitor
    @previous_run = @run.started_at && @monitor.search_runs.where(:started_at.lt => @run.started_at).recent_first.first
  end
end
