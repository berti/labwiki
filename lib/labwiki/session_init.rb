require 'grit'
require 'httparty'
require 'omf-web/content/git_repository'
require 'omf-web/session_store'

class SessionInit < OMF::Common::LObject
  def initialize(app, opts = {})
    @app = app
  end

  def call(env)
    req = ::Rack::Request.new(env)
    req.session['sid'] ||= "s#{(rand * 10000000).to_i}_#{(rand * 10000000).to_i}"
    Thread.current["sessionID"] = req.session['sid'] # needed for Session Store
    if env['warden'].authenticated?
      user = env['warden'].user
      id = user.split('=').last
      OMF::Web::SessionStore[:email, :user] = id
      OMF::Web::SessionStore[:name, :user] = id
      OMF::Web::SessionStore[:id, :user] = id
      if LabWiki::Configurator[:gimi]
        init_git_repository(id) if LabWiki::Configurator[:gimi][:git]
        init_irods_repository(id) if LabWiki::Configurator[:gimi][:irods]
        init_gimi_experiments(id) if LabWiki::Configurator[:gimi][:ges]
      end
    end
    @app.call(env)
  end

  private

  def init_gimi_experiments(id)
    ges_url = LabWiki::Configurator[:gimi][:ges]
    id = 'user1' # FIXME use real uid when integrated
    response = HTTParty.get("#{ges_url}/users/#{id}")

    gimi_experiments = response['projects'].map do |p|
      HTTParty.get("#{ges_url}/projects/#{p['name']}/experiments")['experiments']
    end.flatten.compact

    OMF::Web::SessionStore[:exps, :gimi] = gimi_experiments
  end

  def init_irods_repository(id)
    raise NotImplementedError
  end

  def init_git_repository(id)
    git_path = File.expand_path("#{LabWiki::Configurator[:gimi][:git][:repos_dir]}/#{id}/")
    repos_dir_path = File.expand_path(LabWiki::Configurator[:gimi][:git][:repos_dir])
    sample_path = File.expand_path(LabWiki::Configurator[:gimi][:git][:sample_repo])

    begin
      unless File.exist?("#{git_path}.git")
        FileUtils.mkdir_p(git_path)
        Dir.chdir(repos_dir_path) do
          system "git clone #{sample_path} #{id}"
        end
      end

      opts = { type: :git, top_dir: git_path }
      OMF::Web::ContentRepository.register_repo(id, opts)

      repo = OMF::Web::ContentRepository.find_repo_for("git:#{id}")
      # Set the repos to search for content for each column
      OMF::Web::SessionStore[:plan, :repos] = [repo]
      OMF::Web::SessionStore[:prepare, :repos] = [repo]
      OMF::Web::SessionStore[:execute, :repos] = [repo]
    rescue => e
      error e.message
    end
  end
end

