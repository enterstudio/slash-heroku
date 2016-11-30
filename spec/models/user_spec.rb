require "rails_helper"

RSpec.describe User, type: :model do
  it "creates action made by the user" do
    user = create_atmos
    expect do
      user.create_action_for(action_params)
    end.to change(user.actions, :count).by(1)
    action = Action.last
    expect(action.value).to eql("staging")
    expect(action.callback_id).to eql("environment")
    expect(action.team_id).to eql("T0QQTP89F")
    expect(action.team_domain).to eql("heroku")
    expect(action.channel_id).to eql("C0QQS2U6B")
    expect(action.channel_name).to eql("general")
    expect(action.action_ts).to eql("1480454458.026997")
    expect(action.message_ts).to eql("1480454212.000005")
  end
end
