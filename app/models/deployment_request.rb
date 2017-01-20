# A incoming deployment requests that's valid and available to release.
class DeploymentRequest
  attr_accessor :command_handler

  delegate :pipeline_name, :branch, :environment, :forced,
           :hosts, :second_factor,
           to: :command_handler

  delegate :command, to: :command_handler
  delegate :channel_name, :team_id, to: :command

  delegate :user, to: :command
  delegate :slack_user_id, :slack_user_name, to: :user

  def self.process(command_handler)
    request = new(command_handler)
    request.process
  end

  def initialize(command_handler)
    @command_handler = command_handler
  end

  def process
    heroku_application.preauth(second_factor) if second_factor

    heroku_build = create_heroku_build
    reap_heroku_build(heroku_build)
  rescue Escobar::Heroku::BuildRequest::Error => e
    handle_escobar_exception(e)
  rescue StandardError => e
    Raven.capture_exception(e)
    command_handler.error_response_for(e.message)
  end

  private

  def create_heroku_build
    heroku_build = heroku_build_request.create(
      "deploy", environment, branch, forced, notify_payload
    )
    heroku_build.command_id = command.id
    heroku_build
  end

  def command_expired?
    command.created_at < 60.seconds.ago
  end

  def notify_payload
    {
      notify: {
        room: channel_name,
        team_id: team_id,
        user: slack_user_id,
        user_name: slack_user_name
      }
    }
  end

  def default_heroku_application
    @default_heroku_application ||=
      pipeline.default_heroku_application(environment)
  end

  def pipeline
    @pipeline ||= command_handler.pipeline
  end

  def heroku_application
    @heroku_application ||= default_heroku_application
  end

  def heroku_build_request
    @heroku_build_request ||= heroku_application.build_request_for(pipeline)
  end

  def handle_escobar_exception(error)
    CommandExecutorJob
      .set(wait: 0.5.seconds)
      .perform_later(command_id: command.id) unless command_expired?

    if command.processed_at.nil?
      command_handler.error_response_for_escobar(error)
    else
      {}
    end
  end

  def reap_heroku_build(heroku_build)
    DeploymentReaperJob
      .set(wait: 10.seconds)
      .perform_later(heroku_build.to_job_json)
    {}
  end
end