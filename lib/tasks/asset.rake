namespace :assets do
  desc "Display asset path"
  task :paths => :environment do
    Rails.application.config.assets.paths.each do |path|
      puts path
    end
  end

	desc "Display asset ressources"
  task :list => :environment do
    Rails.application.assets.each_file do |path|
      puts path
    end
  end
end
