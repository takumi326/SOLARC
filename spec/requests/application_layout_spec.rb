# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Application layout", type: :request do
  it "includes mobile navigation controls" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="mobile-nav-open"')
    expect(response.body).to include('id="mobile-nav-drawer"')
    expect(response.body).to include("mobile_nav")
  end
end
