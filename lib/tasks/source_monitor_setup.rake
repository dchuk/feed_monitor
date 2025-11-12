namespace :source_monitor do
  namespace :setup do
    desc "Verify host dependencies before running the guided SourceMonitor installer"
    task check: :environment do
      summary = SourceMonitor::Setup::DependencyChecker.new.call

      puts "SourceMonitor dependency check:" # rubocop:disable Rails/Output
      summary.results.each do |result|
        status = result.status.to_s.upcase
        current = result.current ? result.current.to_s : "missing"
        expected = result.expected || "n/a"
        puts "- #{result.name}: #{status} (current: #{current}, required: #{expected})" # rubocop:disable Rails/Output
      end

      if summary.errors?
        messages = summary.errors.map do |result|
          "#{result.name}: #{result.remediation}"
        end

        raise "SourceMonitor setup requirements failed. #{messages.join(' ')}"
      end
    end
  end
end
