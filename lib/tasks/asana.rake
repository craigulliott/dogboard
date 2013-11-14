# remove this once Napa is more forgiving about its dependencies
module ActiveRecord
end

namespace :asana do

  desc 'warm up the cache'
  task :warm_cache => :environment do
    while 1
      
      # get all the users
      users = Asana.users false
      puts "Found and cached #{users.count} users"
      
      # recursively fetch all projects and tasks, without using the cache
      Asana.all_projects(false).each do |project|
        
        puts "Fetcing tasks for project #{project["id"]} '#{project["name"]}'"

        # fetch all the taks
        tasks = Asana.tasks_for_project(project["id"], false)
        puts "Found and cached #{tasks.count} tasks"
      
      end
      
      # sleep 60
    end

  end

end