module StashEngine
  class CurationActivity < ActiveRecord::Base
    belongs_to :stash_identifier, class_name: 'StashEngine::Identifier', foreign_key: 'identifier_id'
    belongs_to :user, class_name: 'StashEngine::User', foreign_key: 'user_id'
    validates :status, inclusion: { in: ['Submitted',
                                         'Private for Peer Review',
                                         'Curation',
                                         'Author Action Required',
                                         'Embargoed',
                                         'Published',
                                         'Withdrawn',
                                         'Status Unchanged',
                                         'Versioned'],
                                    message: '%{value} is not a valid status' }
    validates :status, presence: true

    def self.curation_status(my_stash_id)
      curation_activities = CurationActivity.where(stash_identifier: my_stash_id).order(updated_at: :desc)
      curation_activities.each do |activity|
        return activity.status unless activity.status == 'Status Unchanged'
      end
      @curation_status = 'Unsubmitted'
    end

    def as_json(*)
      # {"id":11,"identifier_id":1,"status":"Submitted","user_id":1,"note":"hello hello ssdfs2232343","keywords":null}
      {
        id: id,
        dataset: stash_identifier.to_s,
        status: status,
        action_taken_by: user.name,
        note: note,
        keywords: keywords,
        created_at: created_at,
        updated_at: updated_at
      }
    end
  end
end
