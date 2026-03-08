require "rails_helper"

RSpec.describe "operator workflow", type: :system do
  before { driven_by(:rack_test) }

  it "creates, runs, and investigates a monitor through the operations console" do
    visit new_monitor_path
    fill_in "Name", with: "Ruby ecosystem watch"
    fill_in "Query", with: "ruby observability"
    select "Fake", from: "Engine"
    fill_in "monitor_required_domains", with: "example.com"
    click_button "Create Monitor"

    monitor = QueryPulse::Monitor.find_by(name: "Ruby ecosystem watch")
    expect(page).to have_text("Monitor created")
    expect(page).to have_text("ruby observability")

    perform_enqueued_jobs { click_button "Run now" }
    run = monitor.search_runs.recent_first.first
    expect(page).to have_text("Execution queued")
    expect(run.reload.status).to eq("success")

    find("a[href='#{run_path(run)}']").click
    expect(page).to have_text("Normalized JSON")
    expect(page).to have_text("Changes (0)")
    expect(page).to have_text("ruby observability")

    run.set(response_changes: [{ "type" => "FIELD_REMOVED", "path" => "organic_results[].snippet",
                                 "severity" => "warning", "previous" => "text", "current" => nil }])
    visit run_path(run)
    expect(page).to have_text("FIELD_REMOVED")
    expect(page).to have_text("organic_results[].snippet")

    incident = monitor.incidents.create!(search_run: run, incident_type: "field_removed", severity: "warning", status: "open",
                                         title: "Snippet disappeared", description: "Provider omitted the snippet.",
                                         path: "organic_results[].snippet", fingerprint: SecureRandom.hex,
                                         first_seen_at: Time.current, last_seen_at: Time.current)
    visit incident_path(incident)
    click_button "Acknowledge"
    expect(page).to have_text("acknowledged")
    click_button "Resolve"
    expect(page).to have_text("resolved")

    visit playground_path
    fill_in "Query", with: "deterministic rails search"
    click_button "Run search"
    expect(page).to have_text("organic_results")
    expect(page).to have_text("deterministic rails search")
  end
end
