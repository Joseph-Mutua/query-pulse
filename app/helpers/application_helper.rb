module ApplicationHelper
  def status_badge(status)
    tone = case status.to_s
           when "success", "resolved", "ok" then "badge-success"
           when "failed", "critical", "open", "timeout" then "badge-danger"
           when "running", "acknowledged", "warning" then "badge-warning"
           else "badge-neutral"
           end
    tag.span(status.to_s.humanize, class: "badge #{tone}")
  end

  def format_duration(milliseconds)
    return "—" if milliseconds.nil?

    milliseconds >= 1_000 ? "#{(milliseconds / 1_000.0).round(2)}s" : "#{milliseconds}ms"
  end

  def short_hash(value)
    value.present? ? value.first(10) : "—"
  end
end
