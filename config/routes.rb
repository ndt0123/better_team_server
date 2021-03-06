Rails.application.routes.draw do
  devise_for :users
  
  namespace :api, defaults: {format: :json} do
    namespace :v1 do
      mount ActionCable.server => '/cable'

      devise_scope :user do
        post "sign_up", to: "registrations#create"
        post "sign_in", to: "sessions#create"
        delete "sign_out", to: "sessions#destroy"
      end

      namespace :admin do
        
      end

      get "account_info", to: "account#index"
      patch "update_account", to: "account#update"

      # Workspace
      resources :workspace
      get "user_list_workspace", to: "workspace#user_list_workspace"
      post "workspace/:workspace_id/add_members", to: "workspace#add_members"
      post "workspace/:workspace_id/remove_members", to: "workspace#remove_members"
      get "workspace/:workspace_id/all_users", to: "workspace#all_users"
      get "workspace/:workspace_id/all_members", to: "workspace#all_members"
      post "workspace/:workspace_id/leave_workspace", to: "workspace#leave_workspace"
      get "all_workspaces", to: "workspace#all_workspaces"
      post "workspace/:workspace_id/join", to: "workspace#join"

      # Task
      post "workspace/:workspace_id/new_task", to: "task#create"  #Create task for workspace
      post "task/:task_id", to: "task#update"
      get "workspace/:workspace_id/pending_tasks_list", to: "task#pending_tasks_list"
      get "workspace/:workspace_id/in_progress_tasks_list", to: "task#in_progress_tasks_list"
      get "workspace/:workspace_id/finished_tasks_list", to: "task#finished_tasks_list"
      get "task/:task_id/detail", to: "task#detail"
      get "task/:task_id/task_history", to: "task#task_history"

      # Comment
      post "task/:task_id/comment", to: "task_comment#create"
      get "task/:task_id/comments", to: "task_comment#comments"

      # Message
      post "workspace/:workspace_id/message", to: "message#create"
      get "workspace/:workspace_id/messages", to: "message#messages"
      post "workspace/:workspace_id/create_reply_message", to: "message#create_reply_message"

      # Dashboard
      get "dashboard/count_task_user", to: "dashboard#count_task_user"
      get "dashboard/caculate_percent_task_changed", to: "dashboard#caculate_percent_task_changed"
      get "dashboard/get_recent_tasks", to: "dashboard#get_recent_tasks"
      get "dashboard/get_recent_messages", to: "dashboard#get_recent_messages"
    end
  end
end
