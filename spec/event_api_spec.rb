# frozen_string_literal: true

RSpec.describe EventApi do
  let(:private_key) { Base64.urlsafe_encode64(OpenSSL::PKey::RSA.generate(2048).to_pem) }

  let(:rabbitmq_credentials) do
    {
      host: "localhost",
      port: "5672",
      username: "guest",
      password: "guest"
    }
  end

  it "has a version number" do
    expect(EventApi::VERSION).not_to be nil
  end

  it "generate event" do
    event_api = described_class.configure\
      application_name: "event_api",
      jwt_algorithm: "RS256",
      jwt_private_key: private_key,
      rabbitmq_credentials: rabbitmq_credentials

    expect(event_api.notify("push_notify.withdraw.succeed", record: { data: "withdraw completed" })).not_to be nil
  end
end
