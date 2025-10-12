(() => {
  const globalObject = window;

  if (
    globalObject.useTransition &&
    typeof globalObject.useTransition.useTransition === "function"
  ) {
    return;
  }

  const fallback = {
    useTransition(controller, options = {}) {
      const element = options.element || controller.element;

      controller.toggleTransition = function toggleTransition() {
        if (!element) return;
        element.classList.toggle("hidden");
      };

      controller.leave = function leave() {
        if (!element) return;
        element.classList.add("hidden");
      };
    }
  };

  globalObject.useTransition = fallback;
})();
