memcached_client = Dalli::Client.new('localhost:11211', {namespace: ENV["SERVICE_NAME"], compress: true })

settings = {
  key: ENV["ASANA_API_KEY"],
  
  workspace_id: ENV["ASANA_WORKSPACE_ID"].to_i,
  
  current_team_id: ENV["ASANA_CURRENT_TEAM_ID"].to_i,
  planned_team_id: ENV["ASANA_PLANNED_TEAM_ID"].to_i,
  bugs_and_chores_team_id: ENV["ASANA_BUGS_AND_CHORES_TEAM_ID"].to_i,
  features_and_ideas_team_id: ENV["ASANA_FEATURES_AND_IDEAS_TEAM_ID"].to_i,

  milestone_tag_id: ENV["ASANA_MILESTONE_TAG_ID"].to_i,
  bug_tag_id: ENV["ASANA_BUG_TAG_ID"].to_i,
  chore_tag_id: ENV["ASANA_CHORE_TAG_ID"].to_i,

  memcache_client: memcached_client
}

Asana.configure settings

