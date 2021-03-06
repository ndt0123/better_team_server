class Api::V1::WorkspaceController < ApplicationController
  include ActionView::Helpers::TextHelper
  before_action :get_current_user

  def create
    user_id = @current_user.id
    workspace = Workspace.new workspace_params
    if workspace.save
      workspace_member = WorkspaceMember.new(role: :admin, user_id: user_id, workspace_id: workspace.id)
      if workspace_member.save
        render json: {
          is_success: true,
          workspace: {
            id: workspace.id,
            title: workspace.title
          }
        }, status: :ok
      end
    else
      render json: {
        is_success: false,
        error: workspace.errors.full_messages.join(". ")
      }, status: :ok
    end
  end

  def update
    workspace = Workspace.find_by(id: params[:id])
    if workspace && can_update_workspace?(workspace, @current_user)
      if workspace.update workspace_params
        render json: {
          is_success: true,
          workspace: workspace
        }, status: :ok
      else
        render json: {
          is_success: false,
          message: workspace.errors.full_messages.join(". ")
        }, status: :ok
      end
    else
      render json: {
        is_success: false,
        message: 'Can not update this workspace!'
      }, status: :ok
    end
  end

  def show
    workspace = Workspace.find_by(id: params[:id])
    belong_workspace = false
    if workspace
      if WorkspaceMember.find_by(workspace_id: workspace.id, user_id: @current_user.id)
        belong_workspace = true
      end
      workspace_info = {
        id: workspace.id,
        title: workspace.title,
        description: workspace.description,
        is_private: workspace.is_private,
        belong_workspace: belong_workspace,
        code: workspace.code
      }

      render json: {
        is_success: true,
        workspace: workspace_info
      }, status: :ok
    else
      render json: {
        is_success: false,
        message: 'You can not access this resource!'
      }, status: :ok
    end
  end

  def user_list_workspace
    workspaces = @current_user.workspaces.select(:id, :title)
    render json: {
      is_success: true,
      workspaces: workspaces
    }, status: :ok
  end

  # POST: Add new members to workspace
  # post "workspace/:workspace_id/add_members"
  # data: {user_ids: []}
  def add_members
    workspace = Workspace.find_by(id: params[:workspace_id])
    if workspace && can_add_members?(workspace, @current_user)
      params[:user_ids].map { |user_id|
        WorkspaceMember.find_or_create_by(user_id: user_id, workspace_id:params[:workspace_id])
      }
      members = workspace.users.without_authen_token
      render json: {
        is_success: true,
        members: members
      }, status: :ok
    else
      render json: {
        is_success: false,
        message: "You can not access this recources!"
      }, status: :ok
    end
  end

  # POST: Remove member
  # post "workspace/:workspace_id/remove_members"
  # params: user_ids: [list uset id]
  def remove_members
    workspace = Workspace.find_by(id: params[:workspace_id])
    if workspace && can_remove_members?(workspace, @current_user)
      params[:user_ids].map { |user_id|
        workspace_member = WorkspaceMember.member.find_by(user_id: user_id, workspace_id: workspace.id)
        if workspace_member
          workspace_member.destroy
        end
      }
      members = []
      workspace.workspace_members.each do |workspace_member|
        if workspace_member.user.id != @current_user.id
          user = workspace_member.user
          member_info = {
            id: user.id,
            email: user.email,
            created_at: user.created_at,
            updated_at: user.updated_at,
            first_name: user.first_name,
            last_name: user.last_name,
            university: user.university,
            phone_number: user.phone_number,
            address: user.address,
            facebook: user.facebook,
            sex: user.sex,
            avatar: user.avatar,
            birthday: user.birthday,
            role: workspace_member.role,
            status: workspace_member.status
          }
          members.push(member_info)
        end
      end
      render json: {
        is_success: true,
        members: members
      }, status: :ok
    else
      render json: {
        is_success: false,
        message: "You can not access this recources!"
      }, status: :ok
    end
  end

  # GET: all users that do not belong to this workspace
  # get "workspace/:workspace_id/all_users"
  # body: {search_key: ""}
  def all_users
    workspace = Workspace.find_by(id: params[:workspace_id])
    search_key = params[:search_key] || ""
    if workspace && workspace.users.pluck(:id).include?(@current_user.id)
      member_ids = workspace.users.pluck(:id)
      all_users = User.where.not(id: member_ids)
      if search_key.present?
        all_users = all_users.where("email LIKE :text OR first_name LIKE :text OR last_name LIKE :text OR university LIKE :text", text: "%#{search_key}%").without_authen_token
      end
      render json: {
        is_success: true,
        users: all_users
      }, status: :ok
    else
      render json: {
        is_success: false,
        message: "You can not access this recources!"
      }, status: :ok
    end
  end

  # GET: all members in workspace except current user
  # get "workspace/:workspace_id/all_members"
  # params: {search_key: "", all: Boolean}
  # If params[:all] == true -> Get all member include current user
  def all_members
    workspace = Workspace.find_by(id: params[:workspace_id])
    search_key = params[:search_key] || ""
    if workspace && workspace.users.pluck(:id).include?(@current_user.id)
      members = []
      users = if search_key.present?
        workspace.users.where("email LIKE :text OR first_name LIKE :text OR last_name LIKE :text OR university LIKE :text", text: "%#{search_key}%")
      else
        workspace.users
      end
      users.each do |user|
        if user.id != @current_user.id || params[:all]
          workspace_member = user.workspace_members.find_by(workspace_id: workspace.id)
          member_info = {
            id: user.id,
            email: user.email,
            created_at: user.created_at,
            updated_at: user.updated_at,
            first_name: user.first_name,
            last_name: user.last_name,
            university: user.university,
            phone_number: user.phone_number,
            address: user.address,
            facebook: user.facebook,
            sex: user.sex,
            avatar: user.avatar,
            birthday: user.birthday,
            role: workspace_member.role,
            status: workspace_member.status
          }
          members.push(member_info)
        end
      end

      render json: {
        is_success: true,
        members: members
      }, status: :ok
    else
      render json: {
        is_success: false,
        message: "You can not access this recources!"
      }, status: :ok
    end
  end

  def leave_workspace
    workspace_id = params[:workspace_id]
    workspace_member = WorkspaceMember.find_by(user_id: @current_user.id, workspace_id: workspace_id)
    if workspace_member
      workspace_member.destroy
      render json: {
        is_success: true
      }, status: :ok
    else
      render json: {
        is_success: false,
        message: "You do not belong to this workspace."
      }, status: :ok
    end
  end

  def all_workspaces
    search_key = params[:search_key].presence || ""
    workspaces = []

    Workspace.where("title LIKE :text", text: "%#{search_key}%").each do |workspace|
      belong_workspace = false
      if WorkspaceMember.find_by(workspace_id: workspace.id, user_id: @current_user.id)
        belong_workspace = true
      end

      workspaces.push({
        id: workspace.id,
        title: workspace.title,
        description: truncate(workspace.description, length: 50),
        is_private: workspace.is_private,
        belong_workspace: belong_workspace
      })
    end

    render json: {
      is_success: true,
      workspaces: workspaces
    }, status: :ok
  end

  def join
    code = params[:code]
    is_success = true
    message = ""

    workspace = Workspace.find_by(id: params[:workspace_id])
    workspace_member = WorkspaceMember.find_by(user_id: @current_user.id, workspace_id: params[:workspace_id])

    if workspace_member.present?
      is_success = false
      message = "You already belong to this workspace!"
    elsif workspace.code.blank? || code == workspace.code
      if WorkspaceMember.create(user_id: @current_user.id, workspace_id: params[:workspace_id])
        is_success = true
        message = "Successfully"
      else
        is_success = false
        message = "Can not join to this workspace!"
      end
    else
      is_success = false
      message = "Private key is incorrect!"
    end

    render json: {
      is_success: is_success,
      message: message
    }, status: :ok
  end

  private
  def workspace_params
    params.permit Workspace::WORKSPACE_PARAMS
  end

  def can_add_members? workspace, user
    workspace_member = WorkspaceMember.approved.by_user_workspace(user.id, workspace.id)
    return workspace_member.present?
  end

  def can_remove_members? workspace, user
    workspace_member = WorkspaceMember.approved.by_user_workspace(user.id, workspace.id)
    return workspace_member.present?
  end

  def can_update_workspace? workspace, user
    workspace_member = WorkspaceMember.approved.by_user_workspace(user.id, workspace.id)
    return workspace_member.present?
  end

  def can_read_workspace_info? workspace, user
    workspace_member = WorkspaceMember.approved.by_user_workspace(user.id, workspace.id)
    return workspace_member.present?
  end
end
