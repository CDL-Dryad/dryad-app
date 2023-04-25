module StashEngine
  class CurationActivityController < ApplicationController
    # after_action :verify_authorized, except: :curation_activity_params

    helper AdminDatasetsHelper

    # GET /resources/{id}/curation_activities
    def index
      resource = Resource.includes(:identifier, :curation_activities).find(params[:resource_id])
      @ident = resource.identifier
      @curation_activities = authorize resource.curation_activities.order(created_at: :desc), policy_class: CurationActivityPolicy
      respond_to do |format|
        format.html
        format.json { render json: @curation_activities }
      end
    end

    # this is used by the 'add note, and only for curation history page'
    def curation_note
      # only add to latest resource and after latest curation activity, no matter if this page is stale or whatever
      @resource = Identifier.find_by_id(params[:id]).latest_resource
      @curation_activity = authorize CurationActivity.create(resource_id: @resource.id, user_id: current_user.id,
                                                             status: @resource.last_curation_activity&.status,
                                                             note: params[:stash_engine_curation_activity][:note])
      @resource.reload
    end

    private

    def curation_activity_params
      params.require(:stash_engine_curation_activity).permit(:resource_id, :status, :note)
    end

  end
end
