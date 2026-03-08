class EnqueueDueMonitorsJob < ApplicationJob
  queue_as :critical

  def perform(now = Time.current)
    QueryPulse::Monitor.where(enabled: true, :next_execution_at.lte => now).limit(1_000).each do |monitor|
      key = "scheduled:#{monitor.id}:#{monitor.next_execution_at.to_i}"
      monitor.schedule_next!(from: now)
      ExecuteMonitorJob.perform_later(monitor.id.to_s, idempotency_key: key)
    end
  end
end
