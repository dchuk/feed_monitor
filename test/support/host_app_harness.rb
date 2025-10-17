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

  TEMPLATE_OPTIONS = {
    default: [
      "--skip-test",
      "--skip-system-test",
      "--skip-hotwire",
      "--skip-javascript",
      "--skip-css",
      "--skip-deploy",
      "--skip-action-mailer",
      "--skip-action-mailbox",
      "--skip-action-text",
      "--skip-active-storage",
      "--skip-git"
    ],
    api: [
      "--api",
      "--skip-test",
      "--skip-system-test",
      "--skip-hotwire",
      "--skip-javascript",
      "--skip-css",
      "--skip-deploy",
      "--skip-action-mailer",
      "--skip-action-mailbox",
      "--skip-action-text",
      "--skip-active-storage",
      "--skip-git"
    ]
  }.freeze

  def prepare_working_directory(template: :default)
    ensure_template!(template)
    reset_working_directory!(template)
    @current_template = template
    yield current_work_root if block_given?
    ensure_bundle_installed!(current_work_root)
  end

  def cleanup_working_directory
    return unless @current_template

    FileUtils.rm_rf(current_work_root)
    @current_template = nil
  end

  def bundle_exec!(*command, env: {})
    with_working_directory(env:) do |resolved_env|
      output, status = Open3.capture2e(resolved_env, "rbenv", "exec", "bundle", "exec", *command)
      raise_command_failure(command, output) unless status.success?
      output
    end
  end

  def exist?(relative_path)
    File.exist?(File.join(current_work_root, relative_path))
  end

  def read(relative_path)
    File.read(File.join(current_work_root, relative_path))
  end

  def digest_files(relative_paths)
    relative_paths.index_with { |path| digest(path) }
  end

  def digest(relative_path)
    Digest::SHA256.hexdigest(read(relative_path))
  end

  private

  def current_work_root
    raise "call prepare_working_directory before interacting with HostAppHarness" unless @current_template

    work_root(@current_template)
  end

  def ensure_template!(template)
    root = template_root(template)
    return if File.exist?(File.join(root, "Gemfile.lock"))

    FileUtils.rm_rf(root)
    generate_host_app_template!(template)
    append_engine_to_gemfile!(root)
    ensure_bundle_installed!(root)
  end

  def reset_working_directory!(template)
    FileUtils.rm_rf(work_root(template))
    FileUtils.mkdir_p(File.dirname(work_root(template)))
    FileUtils.cp_r("#{template_root(template)}/.", work_root(template))
  end

  def generate_host_app_template!(template)
    args = [template_root(template), *TEMPLATE_OPTIONS.fetch(template)]

    Bundler.with_unbundled_env do
      FeedMonitor::Engine.eager_load!
      Dir.chdir(ENGINE_ROOT) do
        Rails::Generators::AppGenerator.start(args, behavior: :invoke)
      end
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

  def with_working_directory(env: {})
    Bundler.with_unbundled_env do
      Dir.chdir(current_work_root) do
        merged_env = default_env.merge(env)
        yield merged_env
      end
    end
  end

  def run_bundler!(env, args)
    output, status = Open3.capture2e(env, "rbenv", "exec", "bundle", *args)
    raise_command_failure(["bundle", *args], output) unless status.success?
  end

  def default_env(root = current_work_root)
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

  def template_root(template)
    File.join(TMP_ROOT, "host_app_template_#{template}")
  end

  def work_root(template)
    File.join(TMP_ROOT, "host_app_#{template}")
  end
end
