# frozen_string_literal: true

require "bundler"
require "digest"
require "fileutils"
require "open3"
require "rails/generators"
require "rails/generators/rails/app/app_generator"

module HostAppHarness
  extend self

  ENGINE_ROOT = File.expand_path("../..", __dir__)
  TMP_ROOT = File.expand_path("../tmp", __dir__)
  TEMPLATE_ROOT = File.join(TMP_ROOT, "host_app_template")
  WORK_ROOT = File.join(TMP_ROOT, "host_app")

  def prepare_working_directory
    ensure_template!
    reset_working_directory!
    ensure_bundle_installed!(WORK_ROOT)
  end

  def cleanup_working_directory
    FileUtils.rm_rf(WORK_ROOT)
  end

  def bundle_exec!(*command)
    Bundler.with_unbundled_env do
      Dir.chdir(WORK_ROOT) do
        env = default_env
        output, status = Open3.capture2e(env, "rbenv", "exec", "bundle", "exec", *command)
        raise_command_failure(command, output) unless status.success?
        output
      end
    end
  end

  def exist?(relative_path)
    File.exist?(File.join(WORK_ROOT, relative_path))
  end

  def read(relative_path)
    File.read(File.join(WORK_ROOT, relative_path))
  end

  def digest_files(relative_paths)
    relative_paths.index_with { |path| digest(path) }
  end

  def digest(relative_path)
    Digest::SHA256.hexdigest(read(relative_path))
  end

  private

  def ensure_template!
    return if File.exist?(File.join(TEMPLATE_ROOT, "Gemfile.lock"))

    FileUtils.rm_rf(TEMPLATE_ROOT)
    generate_host_app_template!
    append_engine_to_gemfile!(TEMPLATE_ROOT)
    ensure_bundle_installed!(TEMPLATE_ROOT)
  end

  def reset_working_directory!
    FileUtils.rm_rf(WORK_ROOT)
    FileUtils.mkdir_p(File.dirname(WORK_ROOT))
    FileUtils.cp_r("#{TEMPLATE_ROOT}/.", WORK_ROOT)
  end

  def generate_host_app_template!
    args = [ TEMPLATE_ROOT, "--skip-test", "--skip-system-test", "--skip-hotwire", "--skip-javascript", "--skip-css", "--skip-action-mailer", "--skip-action-mailbox", "--skip-action-text", "--skip-active-storage", "--skip-git" ]

    Bundler.with_unbundled_env do
      FeedMonitor::Engine.eager_load!
      Rails::Generators::AppGenerator.start(args, behavior: :invoke)
    end
  end

  def append_engine_to_gemfile!(root)
    gemfile = File.join(root, "Gemfile")
    File.open(gemfile, "a") do |file|
      file.puts
      file.puts %(gem "feed_monitor", path: "#{ENGINE_ROOT}")
    end
  end

  def ensure_bundle_installed!(root)
    Bundler.with_unbundled_env do
      Dir.chdir(root) do
        env = default_env(root)
        check_status = system(env, "rbenv", "exec", "bundle", "check", out: File::NULL, err: File::NULL)
        return if check_status

        run_bundler!(env, %w[install --quiet])
      end
    end
  end

  def run_bundler!(env, args)
    output, status = Open3.capture2e(env, "rbenv", "exec", "bundle", *args)
    raise_command_failure(["bundle", *args], output) unless status.success?
  end

  def default_env(root = WORK_ROOT)
    {
      "BUNDLE_GEMFILE" => File.join(root, "Gemfile"),
      "BUNDLE_IGNORE_CONFIG" => "1"
    }
  end

  def raise_command_failure(command, output)
    message = [
      "HostAppHarness command failed: #{Array(command).join(" ")}",
      output
    ].compact.join("\n")

    raise RuntimeError, message
  end
end
