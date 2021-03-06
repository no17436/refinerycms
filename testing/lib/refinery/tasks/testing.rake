namespace :refinery do
  namespace :testing do
    desc "Generates a dummy app for testing"
    task :dummy_app => [
      :report_dummy_app_status,
      :setup_dummy_app,
      :setup_extension,
      :init_test_database
    ]

    desc "raises if there is already a dummy app"
    task :report_dummy_app_status do
      raise "\nPlease rm -rf '#{dummy_app_path}'\n\n" if dummy_app_path.exist?
    end

    desc "Sets up just the dummy application for testing, no migrations or extensions"
    task :setup_dummy_app do
      require 'refinerycms-core'

      params = %w(--quiet)
      params << "--database=#{ENV['DB']}" if ENV['DB']

      Refinery::DummyGenerator.start params

      Refinery::CmsGenerator.start %w[--quiet --fresh-installation]

      Dir.chdir dummy_app_path
    end

    # This task is a hook to allow extensions to pass configuration
    # Just define this inside your extension's Rakefile or a .rake file
    # and pass arbitrary code. Example:
    #
    # namespace :refinery do
    #   namespace :testing do
    #     task :setup_extension do
    #       require 'refinerycms-my-extension'
    #       Refinery::MyEngineGenerator.start %w[--quiet]
    #     end
    #   end
    # end
    task :setup_extension do
    end

    desc "Remove the dummy app used for testing"
    task :clean_dummy_app => [:drop_dummy_app_database] do
      dummy_app_path.rmtree if dummy_app_path.exist?
    end

    desc "Remove the dummy app's database."
    task :drop_dummy_app_database do
      system "bundle exec rake -f #{File.join(dummy_app_path, 'Rakefile')} db:drop"
    end

    task :init_test_database do
      system "RAILS_ENV=test bundle exec rake -f #{File.join(dummy_app_path, 'Rakefile')} db:create db:migrate"
    end

    task :specs do
      paths = Dir.glob('vendor/extensions/*/spec')
      paths << Rails.root

      status = 0
      paths.each do |path|
        if Rails.root.join(path).basename.to_s == 'spec'
          path = Rails.root.join(path).parent
        end
        cmd = "running specs in #{ path.basename }"
        puts "\n#{ "-" * cmd.to_s.length }\n#{ cmd }\n#{"-" * cmd.to_s.length }"
        Dir.chdir(path) do
          IO.popen("bundle exec bundle install && bundle exec rake refinery:testing:dummy_app") unless path == Rails.root
          IO.popen("bundle exec rake spec") do |f|
            f.each { |line| puts line }
            f.close
            status = 1 if $?.to_i > 0
          end
        end
      end
      abort "Some tests failed" if status > 0
    end

    def dummy_app_path
      Refinery::Testing::Railtie.target_extension_path.join('spec', 'dummy')
    end
  end
end
