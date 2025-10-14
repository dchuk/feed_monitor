import { StreamActions } from "@hotwired/turbo";

// Custom Turbo Stream action for client-side redirects
// Usage: responder.redirect(url, action: "advance")
StreamActions.redirect = function () {
	const url = this.getAttribute("url");
	const visitAction = this.getAttribute("visit-action") || "advance";

	if (url) {
		Turbo.visit(url, { action: visitAction });
	}
};
