require "rails_helper"

RSpec.describe StashEngine::ResourcesController, :type => :routing do
  routes { StashEngine::Engine.routes }

  it "routes to the list of all resources" do
    expect(:get => resources_path).
      to route_to(:controller => "stash_engine/resources", :action => "index")
  end

  it "routes a named route" do
    expect(:get => new_resource_path).
      to route_to(:controller => "stash_engine/resources", :action => "new")
  end
end

RSpec.describe StashEngine::ResourcesController, type: :controller do

  let!(:current_user) { StashEngine::User.create(first_name: "Test", last_name: "User", email: "test_user@gmail.com") }

  describe "POST #create" do
    it "creates a new resource" do
      expect {
        post :create, { user_id: current_user.id }
      }.to change(StashEngine::Resource, :count).by(1)
    end
  end
end