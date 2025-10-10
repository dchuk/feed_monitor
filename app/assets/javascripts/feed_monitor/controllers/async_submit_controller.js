(() => {
  class AsyncSubmitController extends Stimulus.Controller {
    static targets = ["button"];
    static values = { loadingText: String };

    connect() {
      if (this.hasButtonTarget) {
        this.defaultText = this.buttonTarget.textContent;
      }
    }

    start() {
      if (!this.hasButtonTarget) return;

      const button = this.buttonTarget;
      button.disabled = true;
      button.dataset.originalText = this.defaultText || button.textContent;
      if (this.hasLoadingTextValue && this.loadingTextValue) {
        button.textContent = this.loadingTextValue;
      }
      button.classList.add("opacity-75", "pointer-events-none");
    }

    finish() {
      if (!this.hasButtonTarget) return;

      const button = this.buttonTarget;
      button.disabled = false;
      button.classList.remove("opacity-75", "pointer-events-none");
      const original = button.dataset.originalText;
      if (original) {
        button.textContent = original;
      }
    }
  }

  window.FeedMonitorAsyncSubmitController = AsyncSubmitController;
})();
