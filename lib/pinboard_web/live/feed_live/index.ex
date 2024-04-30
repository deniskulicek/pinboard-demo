defmodule PinboardWeb.FeedLive.Index do
  use PinboardWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="container">
      <h1 class="text-2xl">Welcome to your pinboard feed!</h1>
      <p class="my-2 text-gray-600">
        Try out real-time functionality by adding a comment below.
      </p>
      <ul class="text-xs">
        <li><b>Pro tip</b>: Open this page in multiple tabs to see the real-time updates.</li>
        <li><b>Pro pro tip</b>: Open in multiple browsers as different users!</li>
      </ul>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
