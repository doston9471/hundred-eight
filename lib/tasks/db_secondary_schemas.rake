namespace :db do
  desc "Load Solid Queue, Cache, and Cable schemas when all databases share DATABASE_URL (Heroku)"
  task load_secondary_schemas: :environment do
    unless ENV["DATABASE_URL"].present?
      puts "db:load_secondary_schemas: skipped (DATABASE_URL not set)"
      next
    end

    {
      "queue" => "solid_queue_recurring_tasks",
      "cache" => "solid_cache_entries",
      "cable" => "solid_cable_messages"
    }.each do |database, sentinel_table|
      if ActiveRecord::Base.connection.table_exists?(sentinel_table)
        puts "db:load_secondary_schemas: #{database} already loaded (#{sentinel_table})"
        next
      end

      task_name = "db:schema:load:#{database}"
      unless Rake::Task.task_defined?(task_name)
        warn "db:load_secondary_schemas: #{task_name} is not defined"
        next
      end

      puts "db:load_secondary_schemas: loading #{database} schema..."
      # schema:load is blocked in production unless this is set (Heroku release / first boot).
      ENV["DISABLE_DATABASE_ENVIRONMENT_CHECK"] = "1"
      Rake::Task[task_name].reenable
      Rake::Task[task_name].invoke
    end
  end
end
