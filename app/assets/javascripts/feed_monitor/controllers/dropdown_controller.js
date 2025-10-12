(() => {
  const globalObject = window;

  if (globalObject.FeedMonitorDropdownController) {
    return;
  }

  if (!globalObject.StimulusDropdown) {
    console.error("FeedMonitor: StimulusDropdown is not available. Ensure stimulus-dropdown.umd.js is loaded.");
    return;
  }

  globalObject.FeedMonitorDropdownController = globalObject.StimulusDropdown;
})();
