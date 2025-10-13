import { Application } from "@hotwired/stimulus";
import AsyncSubmitController from "feed_monitor/controllers/async_submit_controller";
import NotificationController from "feed_monitor/controllers/notification_controller";
import DropdownController from "feed_monitor/controllers/dropdown_controller";
import ModalController from "feed_monitor/controllers/modal_controller";

const existingApplication = window.FeedMonitorStimulus;
const application = existingApplication || Application.start();

if (!existingApplication) {
  window.FeedMonitorStimulus = application;
}

application.register("notification", NotificationController);
application.register("async-submit", AsyncSubmitController);
application.register("dropdown", DropdownController);
application.register("modal", ModalController);

document.addEventListener("turbo:submit-end", () => {
  document.dispatchEvent(new CustomEvent("feed-monitor:form-finished"));
});

export default application;
