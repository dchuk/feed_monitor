(() => {
  if (!window.FeedMonitorControllers) {
    window.FeedMonitorControllers = {};
  }

  class NotificationController extends Stimulus.Controller {
    static values = {
      delay: { default: 5000, type: Number }
    };

    connect() {
      this._clearTimeout();
      this._register();
      this._startTimer();
    }

    disconnect() {
      this._clearTimeout();
    }

    hide(event) {
      if (event) event.preventDefault();
      this._clearTimeout();
      this._dismiss();
    }

    _register() {
      window.FeedMonitorControllers.notification = this;
    }

    _startTimer() {
      if (this.delayValue <= 0) return;
      this.timeoutId = window.setTimeout(() => this._dismiss(), this.delayValue);
    }

    _dismiss() {
      if (!this.element) return;
      this.element.classList.add("opacity-0", "translate-y-2");
      window.setTimeout(() => {
        if (this.element && this.element.remove) {
          this.element.remove();
        }
      }, 200);
    }

    _clearTimeout() {
      if (this.timeoutId) {
        window.clearTimeout(this.timeoutId);
        this.timeoutId = null;
      }
    }
  }

  window.FeedMonitorNotificationController = NotificationController;
})();
