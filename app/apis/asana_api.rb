module AsanaService
  class API < Grape::API
    format :json

    resource :asana do 
      desc "Proxy a simple request to Asana for the users name to test everything is working"
      get do
        {name: Asana.me["name"]}
      end
    end

    resource :bugs_and_chores do 
      desc "Return a summary of bugs and chores per product"
      get do
        Asana.bugs_and_chores_projects_summary
      end
    end

    resource :current_projects do 
      desc "Return a summary of current projects and their milestones"
      get do
        Asana.current_projects_summary
      end
    end

  end
end
