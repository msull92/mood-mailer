require "dotenv"

Dotenv.load

require "awesome_print"
require "mailgun"
require "rest-client"
require "rufus-scheduler"

ENV["TZ"] = "America/Chicago"

scheduler = Rufus::Scheduler.new

# First, instantiate the Mailgun Client with your API key
mg_client = Mailgun::Client.new ENV["MAILGUN_API_KEY"]
mg_events = Mailgun::Events.new(mg_client, ENV["EMAIL_DOMAIN"])

scheduler.cron "0 9,13,17 * * 1,2,3,4,5" do
  message_params =  {
    from:    ENV["FROM_EMAIL_ADDRESS"],
    to:      ENV["TO_EMAIL_ADDRESS"],
    subject: "How are you feeling?",
    text:    "Reply with a word of how you're feeling right now."
  }

  # Send your message through the client
  mg_client.send_message ENV["EMAIL_DOMAIN"], message_params
end

scheduler.every "5m" do
  result = mg_events.get({
    event: "stored"
  })

  # To Ruby standard Hash.
  result.to_h["items"].each do |item|
    key = item["storage"]["key"]
    access_url = "https://api:#{ENV["MAILGUN_API_KEY"]}@sw.api.mailgun.net/v3/domains/#{ENV["EMAIL_DOMAIN"]}/messages/#{key}"

    response = begin
      response = JSON.parse(RestClient.get(access_url).body)
    rescue => e
    end

    if response
      file_path = "/data/responses.csv"
      unless File.readlines(file_path).grep(/#{response["Date"]}/).size > 0
        open(file_path, "a") { |f|
          f.puts "'#{response["Date"]}',#{response["stripped-text"]}"
        }
      end
    end
  end
end

scheduler.join
