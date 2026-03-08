module Incidents
  class Resolver
    DEFAULT_HEALTHY_EXECUTIONS = 3

    def self.call(monitor:, seen_fingerprints:, healthy_executions: DEFAULT_HEALTHY_EXECUTIONS)
      new(monitor:, seen_fingerprints:, healthy_executions:).call
    end

    def initialize(monitor:, seen_fingerprints:, healthy_executions:)
      @monitor = monitor
      @seen = seen_fingerprints
      @healthy_executions = healthy_executions
    end

    def call
      if @seen.any?
        @monitor.set(healthy_run_streak: 0)
        return 0
      end

      streak = @monitor.healthy_run_streak.to_i + 1
      @monitor.set(healthy_run_streak: streak)
      return 0 if streak < @healthy_executions

      incidents = @monitor.incidents.active
      count = incidents.count
      incidents.update_all(status: "resolved") if count.positive?
      count
    end
  end
end
