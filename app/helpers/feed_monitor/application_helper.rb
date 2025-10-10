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
  end
end
