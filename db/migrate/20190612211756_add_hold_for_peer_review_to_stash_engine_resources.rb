class AddHoldForPeerReviewToStashEngineResources < ActiveRecord::Migration[4.2]
  def change
    add_column :stash_engine_resources, :hold_for_peer_review, :boolean, default: false
    add_column :stash_engine_resources, :peer_review_end_date, :datetime
  end
end
