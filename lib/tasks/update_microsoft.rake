namespace :caucus do
  desc 'Update result counts from Microsoft'
  task :update_microsoft do
    return unless Time.now.in_time_zone('EST').to_date == Date.parse('01/02/2016')
    require Rails.root.join('app', 'workers', 'microsoft_data_worker.rb')
    MicrosoftDataWorker.perform_async
  end
end
