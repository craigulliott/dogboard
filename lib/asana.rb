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

  # log entries
  def self.log message
      Napa::Logger.logger.debug message
  end

  # http GET from Asana, wrapped in memcache  
  def self.get_through_cache path, use_cache=true, ttl=86400
    self.log path
    # look in memcached first
    if use_cache
      cached_result = self.mc.get path
      # if we find a record, log and return it
      if cached_result
        #self.log "Found #{path} in cache"
        return cached_result 
      end
    end

    # can't find this in memcache or it has expired, perform the request and cache the results for next time
    response = self.get(path, self.options)
    self.log response.code
    self.log response.headers.to_h.to_json

    # gracefully handle rate limiting
    if response.code == 429
      self.log "Asana rate limit, waiting for #{10} seconds"
      sleep 10
      # retry by making a recursive call
      return self.get_through_cache path, use_cache, ttl
    end

    if response.code >= 500 and response.code < 600
      self.log "Asana remote error #{response.code}, waiting for 10 seconds"
      sleep 10
      # retry by making a recursive call
      return self.get_through_cache path, use_cache, ttl
    end

    # we dont know how to handle other response types
    raise "Asana returned unhandled http code #{response.code}" unless response.code == 200

    result = response["data"]
    self.mc.set path, result, ttl

    return result

  end


  # fetching data remotely from asana
  ##########################################################################################################

  # get the data for a specific task
  def self.task task_id, use_cache=true
    self.get_through_cache("/tasks/#{task_id}", use_cache)
  end

  # Asana representation f the current user, useful for testing
  def self.me use_cache=true
    self.get_through_cache("/users/me.json", use_cache)
  end

  # fetch meta data about a specific project
  def self.project project_id, use_cache=true
    self.get_through_cache("/projects/#{project_id}", use_cache)
  end

  # fetch tasks for a specific project
  def self.tasks project_id, use_cache=true
    self.get_through_cache("/projects/#{project_id}/tasks", use_cache)
  end

  # fetch projects for a specific workspace
  def self.projects workspace_id, use_cache=true
    self.get_through_cache("/workspaces/#{workspace_id}/projects", use_cache)
  end

  # recursively fetch all projects from Asana for the current workspace
  def self.all_projects use_cache=true
    # fetch full project record for each of the projects available to this user
    self.projects(@@workspace_id, use_cache).collect{|p|
      self.project p["id"], use_cache
    }
  end

  # get the tasks within a project
  def self.tasks_for_project project_id, use_cache=true
    tasks = self.tasks(project_id, use_cache).select{|t|
      # is this task a header?
      t["name"][-1] != ':'
    }.collect{|t|
      self.task t["id"], use_cache
    }
  end

  # get the users for the current workspace
  def self.users use_cache=true
    self.get_through_cache("/workspaces/#{@@workspace_id}/users", use_cache)
  end

  # recursively fetch every task in the workspace
  def self.all_tasks use_cache=true
    tasks = []
    self.projects(@@workspace_id, use_cache).collect{|p|
      tasks = tasks | self.tasks_for_project(p["id"], use_cache)
    }
    tasks
  end


  # filtering data locally
  ##########################################################################################################

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

  # get the tasks within a project which have a specific tag
  def self.tagged_tasks_for_project project_id, tag_id
    self.tasks_for_project(project_id).select{|t|
      # keep in the array if the tag is present
      t["tags"].select{|t| t["id"] == tag_id}.count > 0
    }
  end
  # get the tasks within a project which are completed
  def self.completed_tasks_for_project project_id
    self.tasks_for_project(project_id).select{|t| t["completed"]}
  end
  # get the tasks within a project which are NOT completed
  def self.uncompleted_tasks_for_project project_id
    self.tasks_for_project(project_id).select{|t| ! t["completed"]}
  end
  # helpers to get tagged tasks with in a project
  def self.milestone_tasks_for_project(id); self.tagged_tasks_for_project(id, @@milestone_tag_id); end
  def self.bug_tasks_for_project(id); self.tagged_tasks_for_project(id, @@bug_tag_id); end
  def self.chore_tasks_for_project(id); self.tagged_tasks_for_project(id, @@chore_tag_id); end

  
  # get tasks which are currently assigned to a certain user
  def self.tasks_for_assignee assignee_id
    self.filter_tasks_by_assignee(self.all_tasks, assignee_id)
  end

  # takes an array of tasks and returns only those assigned to a specific assignee
  def self.filter_tasks_by_assignee tasks, assignee_id
    tasks.select{|k| k["assignee"]["id"] == assignee_id} 
  end

  
  # get tasks which have a specific tag
  def self.tasks_for_assignee assignee_id
    self.filter_tasks_by_assignee(self.all_tasks, assignee_id)
  end

  # takes an array of tasks and returns only those with a 
  def self.filter_tasks_by_assignee tasks, assignee_id
    tasks.select{|k| k["assignee"]["id"] == assignee_id} 
  end


  # enrich Asana results
  ##########################################################################################################

  def self.team_members
    {
      '5839263971963' => {
        photo: 'http://tech.bellycard.com/assets/img/team/aj-self.jpg',
        name: "Aj Self"
      },
      '5839263971973' => {
        photo: 'http://tech.bellycard.com/assets/img/team/chris-ingebrigtsen.jpg',
        name: "Chris Ingebrigtsen"
      },
      '7333041694564' => {
        photo: 'http://tech.bellycard.com/assets/img/team/christian-vozar.jpg',
        name: "Christian Vozar"
      },
      '4121204866338' => {
        photo: 'http://tech.bellycard.com/assets/img/team/craig-ulliott.jpg',
        name: "Craig Ulliott"
      },
      '4339385349455' => {
        photo: 'http://tech.bellycard.com/assets/img/team/daniel-mason.jpg',
        name: "Daniel Mason"
      },
      '5839263971983' => {
        photo: 'http://tech.bellycard.com/assets/img/team/darby-frey.jpg',
        name: "Darby Frey"
      },
      '5839263971993' => {
        photo: 'http://tech.bellycard.com/assets/img/team/dave-arel.jpg',
        name: "Dave Arel"
      },
      '6654705164517' => {
        photo: 'http://tech.bellycard.com/assets/img/team/eric-kerr.jpg',
        name: "Eric Kerr"
      },
      '5839335517481' => {
        photo: 'http://tech.bellycard.com/assets/img/team/jay-o-connor.jpg',
        name: "Jay O'Connor"
      },
      '7416710640880' => {
        photo: 'http://tech.bellycard.com/assets/img/team/joe-divita.jpg',
        name: "Joe Divita"
      },
      '5839263972008' => {
        photo: 'http://tech.bellycard.com/assets/img/team/jon-white.jpg',
        name: "Jon White"
      },
      '5839263972018' => {
        photo: 'http://tech.bellycard.com/assets/img/team/kevin-reedy.jpg',
        name: "Kevin Reedy"
      },
      '5839084828068' => {
        photo: 'http://tech.bellycard.com/assets/img/team/kyle-mcconnell.jpg',
        name: "Kyle Mcconnell"
      },
      '5840757402844' => {
        photo: 'http://tech.bellycard.com/assets/img/team/shay-howe.jpg',
        name: "Shay Howe"
      }
    }
  end


  # summarizing and representing Asana data
  ##########################################################################################################

  def self.is_bug task
    task["tags"].present? && task["tags"].select{|t| t["id"] == @@bug_tag_id}.count > 0
  end

  def self.is_chore task
    task["tags"].present? && task["tags"].select{|t| t["id"] == @@chore_tag_id}.count > 0
  end

  def self.is_chore task
  end


  # a business level summary of the current projects
  def self.current_projects_summary
    self.current_projects.collect{|p|
      project = {
        name: p["name"],
        notes: p["notes"],
        open_task_count: self.completed_tasks_for_project(p["id"]).count,
        closed_task_count: self.uncompleted_tasks_for_project(p["id"]).count,
        milestones: self.milestone_tasks_for_project(p["id"]).collect{|t|
          {
            name: t["name"],
            due: t["due_on"],
            notes: t["notes"],
            assignee: (t["assignee"].present? ? ( Asana.team_members[t["assignee"]["id"].to_s].merge(t["assignee"]) ) : nil)
          }
        }
      }
      project[:assignee] = project[:milestones].first[:assignee] unless project[:milestones].empty?
      project
    }
  end

  # a business level summary of the planned projects which are not yet started
  def self.upcomming_projects_summary
    self.planned_projects.collect{|p|
      {
        name: p["name"],
        notes: p["notes"]
      }
    }
  end

  # a business level summary of the projects we are still planning
  def self.project_factory_summary
    self.current_projects.collect{|p|
      {
        name: p["name"],
        notes: p["notes"]
      }
    }
  end

  # a business level summary of the current bugs and chores for each product
  def self.products_summary
    self.bugs_and_chores_projects.collect{|p|
      {
        name: p["name"],
        bugs_count: self.bug_tasks_for_project(p["id"]).count,
        chores_count: self.chore_tasks_for_project(p["id"]).count
      }
    }
  end

  # a business level summary of the current bugs and chores for each product
  def self.team_members_summary

    team_members = self.team_members
    team_members.each do |k, v|
      team_members[k][:id] = k
      team_members[k][:bugs_count] = 0
      team_members[k][:chores_count] = 0
    end
    
    # get all the projects in the bugs and chores team
    self.bugs_and_chores_projects.each do |project|
      
      # look at all the tasks in each product
      self.tasks_for_project(project["id"]).each do |task|

        is_bug = self.is_bug(task)
        is_chore = self.is_chore(task)

        # skip tasks which are not assigned to one of our team members or are neither a bug or a chore
        next unless task["assignee"].present? and (is_bug or is_chore) and team_members[task["assignee"]["id"]].present?
        
        assignee_id = task["assignee"]["id"]

        user_summary[assignee_id][:bugs_count] += 1 if self.is_bug(task)
        user_summary[assignee_id][:chores_count] += 1 if self.is_chore(task)

      end
    end

    team_members.collect{|tm| tm[1]}
  end

end

