require 'warden-openid'
require 'labwiki/authentication/ruby_openid_patch'

module LabWiki
  class Authentication
    class OpenID < Authentication
      register_type :openid

      PROVIDERS = {
        "google" => {
          provider: "http://www.google.com/accounts/o8/id",
          required_fields: [
            "http://axschema.org/namePerson/last",
            "http://axschema.org/contact/email",
            "http://axschema.org/namePerson/first"
          ],
          login_content:
            Erector.inline do
              p do
                a :href => "/?openid_identifier=http://www.google.com/accounts/o8/id", :class => "btn btn-lg btn-success" do
                  i :class => "fa fa-google fa-lg"
                  text " Login with Google ID"
                end
              end
            end
        },
        "geni" => {
          provider: "https://portal.geni.net/server/server.php",
          required_fields: [
            "http://geni.net/projects",
            "http://geni.net/slices",
            "http://geni.net/user/urn",
            "http://geni.net/user/prettyname",
            "http://geni.net/irods/username",
            "http://geni.net/irods/zone"
          ],
          login_content:
            Erector.inline do
              p { img :src => "/resource/login/img/geni.png", :alt => "GENI" }
              p do
                a :href => "/?openid_identifier=https://portal.geni.net/server/server.php", :class => "btn btn-success" do
                  text "Login with GENI ID"
                end
              end
            end
        }
      }

      def initialize(opts)
        super
        @users = {} # Authenticated users
        # Default we let google do it
        @provider = opts[:provider] || "google"

        unless PROVIDERS.keys.include?(@provider)
          raise StandardError, "Unknown OpenID provider '#{@provider}'"
        end

        Warden::OpenID.configure do |config|
          config.required_fields = PROVIDERS[@provider][:required_fields]
          config.user_finder do |response|
            identity_url = response.identity_url
            user_data = ::OpenID::AX::FetchResponse.from_success_response(response).data
            user_data['lw:auth_type'] = "openid.#{@provider}"

            @users[identity_url] = user_data

            identity_url
          end
        end
      end

      def parse_user(identity_url)
        user = @users[identity_url]
        return if user.nil?

        user.each { |k, v| user[k] = v.try(:first)
        OMF::Web::SessionStore[:data, :user] = user

        case @provider
        when "geni"
          if (urn = user['http://geni.net/user/urn'])
            OMF::Web::SessionStore[:id, :user] = urn.split('|').last
          end
          OMF::Web::SessionStore[:name, :user] = user['http://geni.net/user/prettyname']
        when "google"
          OMF::Web::SessionStore[:id, :user] = user["http://axschema.org/contact/email"].try(:first)
          last_name = user["http://axschema.org/namePerson/last"].try(:first)
          first_name = user["http://axschema.org/namePerson/first"].try(:first)
          OMF::Web::SessionStore[:name, :user] = "#{first_name} #{last_name}"
        end
      end

      def login_content
        PROVIDERS[@provider][:login_content]
      end
    end
  end
end
