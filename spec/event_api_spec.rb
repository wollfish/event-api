# frozen_string_literal: true

RSpec.describe EventApi do
  it "has a version number" do
    expect(EventApi::VERSION).not_to be nil
  end

  # TODO: Add unit testcases.
  it "generate event" do
    expect(EventApi.notify('admin_notify.deposit.failed', record: {data: 'testing gem'})).not_to be nil
  end
end
