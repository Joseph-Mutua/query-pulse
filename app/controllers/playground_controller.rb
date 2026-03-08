class PlaygroundController < ApplicationController
  def show
    @request_data = playground_params.to_h.presence || defaults
    return unless request.post?

    if params[:intent] == "save"
      monitor = QueryPulse::Monitor.create!(@request_data.slice("engine", "query", "location", "language", "device")
                                .merge("name" => @request_data["name"].presence || @request_data["query"].truncate(70),
                                       "country" => "us", "frequency" => "1h"))
      return redirect_to monitor, notice: "Playground request saved as a monitor."
    end

    monitor = QueryPulse::Monitor.new(@request_data.slice("engine", "query", "location", "language", "device")
                          .merge("name" => "Playground", "country" => "us"))
    result = Search::AdapterFactory.for(monitor.engine).execute(query: monitor.query, location: monitor.location,
                                                                language: monitor.language, device: monitor.device,
                                                                country: monitor.country)
    @result = result
    @normalized = Normalization::SearchResultNormalizer.call(raw: result.raw, monitor:, response_time_ms: result.duration_ms) if result.success?
  end

  private

  def playground_params
    params.fetch(:search, ActionController::Parameters.new).permit(:name, :engine, :query, :location, :language, :device)
  end

  def defaults
    { "engine" => "fake", "query" => "ruby web scraping", "location" => "Austin, Texas",
      "language" => "en", "device" => "desktop" }
  end
end
