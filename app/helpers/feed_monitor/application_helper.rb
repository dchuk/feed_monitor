module FeedMonitor
  module ApplicationHelper
    def heatmap_bucket_classes(count, max_count)
      return "bg-slate-100 text-slate-500" if max_count.to_i.zero? || count.to_i.zero?

      ratio = count.to_f / max_count

      case ratio
      when 0...0.25
        "bg-blue-100 text-blue-800"
      when 0.25...0.5
        "bg-blue-200 text-blue-900"
      when 0.5...0.75
        "bg-blue-400 text-white"
      else
        "bg-blue-600 text-white"
      end
    end

    # Unified status badge helper for both fetch and scrape operations
    def async_status_badge(status, show_spinner: true)
      status_str = status.to_s

      label, classes, spinner = case status_str
      when "queued"
        ["Queued", "bg-amber-100 text-amber-700", show_spinner]
      when "pending"
        ["Pending", "bg-amber-100 text-amber-700", show_spinner]
      when "fetching", "processing"
        ["Processing", "bg-blue-100 text-blue-700", show_spinner]
      when "success"
        ["Completed", "bg-green-100 text-green-700", false]
      when "failed"
        ["Failed", "bg-rose-100 text-rose-700", false]
      when "partial"
        ["Partial", "bg-amber-100 text-amber-700", false]
      when "idle"
        ["Idle", "bg-slate-100 text-slate-600", false]
      else
        ["Ready", "bg-slate-100 text-slate-600", false]
      end

      { label: label, classes: classes, show_spinner: spinner }
    end

    # Legacy helper for backwards compatibility
    def fetch_status_badge_classes(status)
      async_status_badge(status)
    end

    # Helper to render the loading spinner SVG
    def loading_spinner_svg(css_class: "mr-1 h-4 w-4 animate-spin text-blue-500")
      tag.svg(
        class: css_class,
        xmlns: "http://www.w3.org/2000/svg",
        fill: "none",
        viewBox: "0 0 24 24",
        aria: { hidden: "true" }
      ) do
        concat tag.circle(class: "opacity-25", cx: "12", cy: "12", r: "10", stroke: "currentColor", stroke_width: "4")
        concat tag.path(class: "opacity-75", fill: "currentColor", d: "M4 12a8 8 0 0 1 8-8v4a4 4 0 0 0-4 4H4z")
      end
    end
  end
end
