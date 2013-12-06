module AsanaService
  class API < Grape::API
    format :json

    resource :asana do 
      desc "Proxy a simple request to Asana for the users name to test everything is working"
      get do
        {name: Asana.me["name"]}
      end
    end

    resource :current_projects do 
      desc "Return a summary of current projects and their milestones"
      get do
        Asana.current_projects_summary
      end
    end

    resource :upcomming_projects do 
      desc "Return a summary of projects which are starting soon"
      get do
        Asana.upcomming_projects_summary
      end
    end

    resource :project_factory do 
      desc "Return a summary of current project ideas"
      get do
        Asana.project_factory_summary
      end
    end

    resource :products do 
      desc "Return a summary of our products"
      get do
        Asana.products_summary
      end
    end

    resource :team_members do 
      desc "Return a summary of our team"
      get do
        Asana.team_members_summary
      end
    end

  end
end
