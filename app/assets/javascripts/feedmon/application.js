import { Application } from "@hotwired/stimulus";
import AsyncSubmitController from "./controllers/async_submit_controller";
import NotificationController from "./controllers/notification_controller";
import DropdownController from "./controllers/dropdown_controller";
import ModalController from "./controllers/modal_controller";
import "./turbo_actions";

const existingApplication = window.FeedmonStimulus;
const application = existingApplication || Application.start();

if (!existingApplication) {
  window.FeedmonStimulus = application;
}

application.register("notification", NotificationController);
application.register("async-submit", AsyncSubmitController);
application.register("dropdown", DropdownController);
application.register("modal", ModalController);

export default application;
