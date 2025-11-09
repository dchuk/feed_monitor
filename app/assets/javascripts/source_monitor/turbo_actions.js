// Custom Turbo Stream action for client-side redirects
// Usage: responder.redirect(url, action: "advance")
// Note: Turbo is available globally via turbo_include_tags in the layout
if (window.Turbo && window.Turbo.StreamActions) {
	window.Turbo.StreamActions.redirect = function () {
		const url = this.getAttribute("url");
		const visitAction = this.getAttribute("visit-action") || "advance";

		if (url) {
			window.Turbo.visit(url, { action: visitAction });
		}
	};
}
