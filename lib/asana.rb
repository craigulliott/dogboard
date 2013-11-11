class Asana
  include HTTParty
  format :json
  base_uri "https://app.asana.com:443/api/1.0/"

  # set configuration
  def self.configure settings
    @@api_key = settings[:key]

    @@workspace_id = settings[:workspace_id]
    @@current_team_id = settings[:current_team_id]
    @@planned_team_id = settings[:planned_team_id]
    @@bugs_and_chores_team_id = settings[:bugs_and_chores_team_id]
    @@features_and_ideas_team_id = settings[:features_and_ideas_team_id]
    
    @@milestone_tag_id = settings[:milestone_tag_id]
    @@bug_tag_id = settings[:bug_tag_id]
    @@chore_tag_id = settings[:chore_tag_id]

    @@memcache_client = settings[:memcache_client]
  end

  # pointer to the memcache client
  def self.mc
    @@memcache_client
  end

  # default httparty options
  def self.options
    options = { basic_auth: { username: @@api_key, password: "" }, output: "json" }
  end

  # http GET from Asana, wrapped in memcache  
  def self.get_cached path, ttl=900
    # look in memcached first
    cached_result = self.mc.get path
    return cached_result if cached_result
    # can't find this in memcache or it has expired, perform the request and cache the results for next time
    result = self.get(path, self.options)["data"]
    self.mc.set path, result, ttl
    # return the result
    return result
  end

  # recursively fetch all project from Asana for the current workspace
  def self.all_projects
    # fetch full project record for each of the projects available to this user
    self.get_cached("/workspaces/#{@@workspace_id}/projects").collect{|p|
      self.project p["id"]
    }
  end

  # get projects which are currently living under a certain team
  def self.projects_for_team id
    # fetch full project record for each of the projects available to this user
    self.all_projects.select{|k| k["team"]["id"] == id} 
  end
  # helpers to get the projects within a team
  def self.current_projects; self.projects_for_team(@@current_team_id); end
  def self.planned_projects; self.projects_for_team(@@planned_team_id); end
  def self.bugs_and_chores_projects; self.projects_for_team(@@bugs_and_chores_team_id); end
  def self.features_and_ideas_projects; self.projects_for_team(@@features_and_ideas_team_id); end

  # get the tasks within a project
  def self.tasks_for_project id
    self.get_cached("/projects/#{id}/tasks").collect{|t|
      self.task t["id"]
    }
  end

  # get the tasks within a project which have a specific tag
  def self.tagged_tasks_for_project project_id, tag_id
    self.get_cached("/projects/#{project_id}/tasks").collect{|t|
      self.task t["id"]
    }.select{|t|
      # keep in the array if the tag is present
      t["tags"].select{|t| t["id"] == tag_id}.count > 0
    }
  end
  # helpers to get tagged tasks with in a project
  def self.milestone_tasks_for_project(id); self.tagged_tasks_for_project(id, @@milestone_tag_id); end
  def self.bug_tasks_for_project(id); self.tagged_tasks_for_project(id, @@bug_tag_id); end
  def self.chore_tasks_for_project(id); self.tagged_tasks_for_project(id, @@chore_tag_id); end

  # get the data for a specific task
  def self.task id
    self.get_cached("/tasks/#{id}")
  end

  # Asana representation f the current user, useful for testing
  def self.me
    self.get_cached("/users/me.json")
  end

  # fetch meta data about a specific project
  def self.project id
    self.get_cached("/projects/#{id}")
  end

  # fetch teams for a specific workspace
  def self.teams
    self.get_cached("/workspaces/#{@@workspace_id}/teams")
  end

  # a business level summary of the current projects
  def self.current_projects_summary
    self.current_projects.collect{|p|
      {
        name: p["name"],
        task_count: self.tasks_for_project(p["id"]).count,
        milestones: self.milestone_tasks_for_project(p["id"]).collect{|t|
          {
            name: t["name"],
            due: t["due_on"],
            assignee: (t["assignee"].present? ? t["assignee"]["name"] : nil)
          }
        }
      }
    }
  end

  # a business level summary of the planned projects
  def self.planned_projects_summary
    self.current_projects.collect{|p|
      {
        name: p["name"],
        task_count: self.tasks_for_project(p["id"]).count,
        milestones: self.milestone_tasks_for_project(p["id"]).collect{|t|
          {
            name: t["name"],
            due: t["due_on"],
            assignee: (t["assignee"].present? ? t["assignee"]["name"] : nil)
          }
        }
      }
    }
  end

  # a business level summary of the current bugs and chores for each product
  def self.bugs_and_chores_projects_summary
    self.bugs_and_chores_projects.collect{|p|
      {
        name: p["name"],
        bugs_count: self.bug_tasks_for_project(p["id"]).count,
        chores_count: self.chore_tasks_for_project(p["id"]).count
      }
    }
  end

end

