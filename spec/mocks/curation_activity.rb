module Mocks

  module CurationActivity
    def neuter_curation_callbacks!
      # These callbacks cause constant grief when you're just trying to set up curation states in order to
      # do things like test dataset visibility.  Mostly we don't want these running in tests unless we're testing that
      # callback explicitly.
      allow_any_instance_of(StashEngine::CurationActivity).to receive(:submit_to_datacite).and_return(true)
      allow_any_instance_of(StashEngine::CurationActivity).to receive(:update_solr).and_return(true)
      allow_any_instance_of(StashEngine::CurationActivity).to receive(:process_payment).and_return(true)
      allow_any_instance_of(StashEngine::CurationActivity).to receive(:email_status_change_notices).and_return(true)
      allow_any_instance_of(StashEngine::CurationActivity).to receive(:email_orcid_invitations).and_return(true)
      ignore_zenodo!
    end

    def ignore_zenodo!
      allow_any_instance_of(StashEngine::CurationActivity).to receive(:copy_to_zenodo).and_return(true)
    end
  end
end
