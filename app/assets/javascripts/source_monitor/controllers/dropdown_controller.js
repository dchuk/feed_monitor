import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["menu"];
  static values = {
    transitionModule: { type: String, default: "stimulus-use" },
    hiddenClass: { type: String, default: "hidden" }
  };

  connect() {
    this.element.dataset.dropdownState = "initializing";
    this.transitionEnabled = false;
    if (typeof this.toggleTransition !== "function") {
      this.toggleTransition = this.toggleVisibility.bind(this);
    }

    if (typeof this.leave !== "function") {
      this.leave = this.hideMenu.bind(this);
    }

    this.loadTransitions()
      .catch(() => null)
      .finally(() => {
        this.element.dataset.dropdownState = "ready";
      });
  }

  disconnect() {
    delete this.element.dataset.dropdownState;
  }

  // Dynamic import provides progressive enhancement: smooth transitions when stimulus-use
  // is available, graceful fallback to CSS class toggling when not. This complexity is
  // justified as it allows the engine to work without requiring stimulus-use as a dependency.
  // Evaluated for simplification in Phase 20.05.07 - Decision: Keep current implementation.
  async loadTransitions() {
    if (!this.hasMenuTarget || this.transitionModuleValue === "") {
      this.logFallback();
      return;
    }

    try {
      const module = await import(this.transitionModuleValue);
      const useTransition = module?.useTransition || module?.default?.useTransition;

      if (typeof useTransition === "function") {
        useTransition(this, {
          element: this.menuTarget,
          hiddenClass: this.hiddenClassValue
        });
        this.transitionEnabled = true;
      } else {
        this.logFallback();
      }
    } catch (error) {
      this.logFallback(error);
    }
  }

  toggle(event) {
    if (this.transitionEnabled && typeof this.toggleTransition === "function") {
      this.toggleTransition();
    } else {
      this.toggleVisibility();
    }
  }

  hide(event) {
    if (!this.hasMenuTarget) return;
    if (event && this.element.contains(event.target)) return;

    if (this.transitionEnabled && typeof this.leave === "function") {
      this.leave();
    } else {
      this.hideMenu();
    }
  }

  toggleVisibility() {
    this.isOpen() ? this.hideMenu() : this.showMenu();
  }

  showMenu() {
    if (!this.hasMenuTarget) return;
    this.menuTarget.classList.remove(this.hiddenClassValue);
  }

  hideMenu() {
    if (!this.hasMenuTarget) return;
    this.menuTarget.classList.add(this.hiddenClassValue);
  }

  isOpen() {
    return this.hasMenuTarget && !this.menuTarget.classList.contains(this.hiddenClassValue);
  }

  logFallback(error = null) {
    this.transitionEnabled = false;
    if (!this._fallbackLogged && typeof window !== "undefined" && window.console) {
      window.console.warn(
        "SourceMonitor dropdown transitions unavailable; using CSS class toggling instead."
      );
      if (error && typeof window.console.debug === "function") {
        window.console.debug(error);
      }
    }
    this._fallbackLogged = true;
  }
}
