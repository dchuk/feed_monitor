(() => {
  if (!window.Stimulus || !window.Stimulus.Application) {
    console.error("FeedMonitor: Stimulus is not available. Ensure stimulus.umd.js is loaded before feed_monitor/application.js.");
    return;
  }

  const existingApp = window.FeedMonitorStimulus;
  const application = existingApp || window.Stimulus.Application.start();

  if (!existingApp) {
    window.FeedMonitorStimulus = application;
    window.FeedMonitorRegisteredControllers = new Set();
  }

  const registry = window.FeedMonitorRegisteredControllers;

  function register(identifier, controller) {
    if (!controller) return;
    if (!registry.has(identifier)) {
      application.register(identifier, controller);
      registry.add(identifier);
    }
  }

  register("notification", window.FeedMonitorNotificationController);
  register("async-submit", window.FeedMonitorAsyncSubmitController);
  register("dropdown", window.FeedMonitorDropdownController);

  document.addEventListener("turbo:submit-end", () => {
    document.dispatchEvent(new CustomEvent("feed-monitor:form-finished"));
  });
})();
