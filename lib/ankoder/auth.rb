module Ankoder
  # Authenticate to the ankoder service
  #
  #  user = Auth.create("login", "password")
  #  user.account
  #
  # If you want to recover a session:
  #
  #  user = Auth.recover(session_id)
  #  user.account
  #
  # The initialize and create methods can take blocks.
  #
  #  Auth.create("login", "password") do |user|
  #    video = user.videos.find(:first)
  #    profile = user.profiles.find(:first, :conditions => {:name => "iPod 4:3"})
  #    user.jobs.create :original_file_id => video.id, :profile_id => profile.id
  #  end
  #
  # All the resources (pluralized) are available within the Auth class:
  #
  #  jobs, videos, profiles, downloads, account 
  #
  class Auth
    attr_reader :session
    @@sessions = {}

    # Authenticate to the _ankoderapi_session service
    #
    # options can be:
    #
    # * <tt>:login</tt> _ankoderapi_session username
    # * <tt>:password</tt> _ankoderapi_session password
    # * <tt>:session</tt> A previous session, using this option, you will not be reconnected, you will just recover your session
    def initialize(options={}, &block)
      if options[:session]
        @session = options[:session]
      else
        @session = Browser::login(options[:login], options[:password])
        @@sessions.merge!(@session => true)
      end
      yield self if block_given?
    end

    # Same as initialize
    #
    def self.create(login= Configuration::auth_user, password =Configuration::auth_password, &block)
      new(:login => login, :password => password, &block)
    end

    # Recover a session
    #
    #  Auth.recover(session_id)
    def self.recover(session, &block)
      #raise SessionNotFound if @@sessions[session].nil?
      new(:session => session, &block)
    end

    RESOURCES.each do |k|
      Auth.module_eval(%{
                         def #{k.to_s+"s"}
                           klass = #{k.to_s.ankoder_camelize}
                           klass.session = @session
                           klass
                         end
                        }
                      )
    end

    # Delete the current session
    def destroy
      @@sessions.delete(@session)
      @session = nil
    end

  end
end
