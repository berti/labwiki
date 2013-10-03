require 'grit'
require 'httparty'
require 'omf-web/content/git_repository'
require 'omf-web/session_store'
require 'labwiki/plugin_manager'

class SessionInit < OMF::Base::LObject
  def initialize(app, opts = {})
    @app = app
  end

  def call(env)
    req = ::Rack::Request.new(env)
    req.session['sid'] ||= "s#{(rand * 10000000).to_i}_#{(rand * 10000000).to_i}"
    Thread.current["sessionID"] = req.session['sid'] # needed for Session Store
    if env['warden'].authenticated?
      user = env['warden'].user

      update_user(user)
      # We need to fresh this every time user logged in
      update_geni_projects_slices(user)

      unless OMF::Web::SessionStore[:initialised, :session]
        if LabWiki::Configurator[:gimi]
          init_git_repository(id) if LabWiki::Configurator[:gimi][:git]
          init_gimi_experiments(id) if LabWiki::Configurator[:gimi][:ges]
          init_irods_repository(id) if LabWiki::Configurator[:gimi][:irods]
        end
        LabWiki::PluginManager.init_session()
        OMF::Web::SessionStore[:initialised, :session] = true
      end
    end
    @app.call(env)
  end

  private

  def update_user(user)
    if user.kind_of? Hash
      pretty_name = user['http://geni.net/user/prettyname'].first
      urn = user['http://geni.net/user/urn'].first
      OMF::Web::SessionStore[:urn, :user] = urn
      OMF::Web::SessionStore[:name, :user] = pretty_name
      OMF::Web::SessionStore[:id, :user] = urn && urn.split('|').last
    elsif user.kind_of? String
      OMF::Web::SessionStore[:urn, :user] = user
      OMF::Web::SessionStore[:name, :user] = user
      OMF::Web::SessionStore[:id, :user] = user
    end
  end

  def init_gimi_experiments(id)
    ges_url = LabWiki::Configurator[:gimi][:ges]
    # FIXME use real uid when integrated
    id = 'user1' if LabWiki::Configurator[:gimi][:mocking]
    begin
      response = HTTParty.get("#{ges_url}/users/#{id}")
    rescue
      error "Gimi experiment service not available"
      return
    end

    if response['projects'].nil?
      warn "User, logged in as #{id}, does not have any projects associated "
      return
    end

    gimi_experiments = response['projects'].map do |p|
      HTTParty.get("#{ges_url}/projects/#{p['name']}")['experiments']
    end.flatten.compact

    OMF::Web::SessionStore[:exps, :gimi] = gimi_experiments
  end

  def update_geni_projects_slices(user)
    if user.kind_of?(Hash) &&
      (geni_projects = user['http://geni.net/projects']) &&
      (geni_slices = user['http://geni.net/slices'])

      projects = geni_projects.map do |p|
        uuid, name = *(p.split('|'))
        { uuid: uuid, name: name, slice: {}}
      end

      geni_slices.each do |s|
        uuid, project_uuid, name = *s.split('|')
        if (p = projects.find { |v| v[:uuid] == project_uuid })
          p[:slice] = { uuid: uuid, name: name }
        end
      end

      OMF::Web::SessionStore[:projects, :geni_portal] = projects
    end
  end

  def init_irods_repository(id)
    irods_home = LabWiki::Configurator[:gimi][:irods][:home]
    id = 'user1' if LabWiki::Configurator[:gimi][:mocking]
    opts = { type: :irods, top_dir: "#{irods_home}/#{id}/#{LabWiki::Configurator[:gimi][:irods][:script_folder]}" }
    repo = OMF::Web::ContentRepository.register_repo(id, opts)
    repo ||= OMF::Web::ContentRepository.find_repo_for("irods:#{id}")

    OMF::Web::SessionStore[:plan, :repos] = [repo]
    OMF::Web::SessionStore[:prepare, :repos] = [repo]
    OMF::Web::SessionStore[:execute, :repos] = [repo]
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

