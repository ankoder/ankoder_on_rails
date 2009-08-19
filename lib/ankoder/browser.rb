require 'net/http'
require 'hmac'
require 'hmac-sha1'

module Ankoder
  # This class is used to request the _ankoderapi_session service.
  #
  #   Browser::get '/video', session
  #   Browser::post '/download', {:url => 'http://host.com/video.avi'}, session
  #   Browser::put '/video/54000', {:name => 'new title'}, session
  #   Browser::delete '/video/54000', session
  class Browser
    class << self
      # Raise when code response != 2xx
      def raise_if_response_error(res)
        code = res.response.code.to_i
        message = res.response.message
        return if code.to_s =~ /^2/

          raise RequestError, Ankoder::response(res.body) if code == 400
        raise UnprocessableEntityError, Ankoder::response(res.body).to_yaml if code == 422
        raise NotAuthorized, message if code == 401
        raise ResourceNotFound, message if code == 404
        raise ServerError, message if code == 500
      end

      def header(session=nil,action=nil,path=nil) #:nodoc:
        h = {}
        h.merge!({"Cookie" => "_ankoderapi_session=#{session};"}) if session
        h.merge!({"User-Agent" => "_ankoderapi_session ruby API - #{VERSION::STRING}"})
        if !Configuration::access_key.blank? and !Configuration::private_key.blank?
          h.merge!({"ankoder_access_key" => Configuration::access_key}) 
          h.merge!({"ankoder_date" => Time.now.httpdate })

          salt = Digest::SHA1.hexdigest("-#{Time.now.httpdate}-#{action}-#{path}-")[0..19]
          passkey = Base64.encode64(HMAC::SHA1::digest(Configuration::private_key, salt)).strip
          h.merge!({"ankoder_passkey" => "#{passkey}"})
        end
        h
      end

      # Login to _ankoderapi_session service. Return the session ID.
      #
      # You should not use it directly, use Auth#create instead
      #
      #  Browser::login 'login', 'password'
      def login(login, password) #:nodoc:
        res = Browser::post("/auth/login", :login => login, :password => password)
        return res["Set-cookie"].match(/_ankoderapi_session=(.*);/i)[1].to_s
      end

      # GET on path
      def get(path, session=nil)
        path += ".#{OUT_FORMAT}" unless path.include? "."
        p path
        res = Net::HTTP.start(Configuration::host,Configuration::port) {|http| http.get(path, header(session,"GET",path))}
        raise_if_response_error(res)
        res
      end

      # POST on path and pass the query(Hash)
      def post(path, query={}, session=nil)
        res = Net::HTTP.start(Configuration::host,Configuration::port) {|http| http.post(path, query.merge(:format => OUT_FORMAT).to_a.map{|x| x.join("=")}.join("&"), self.header(session,"POST",path))}
        raise_if_response_error(res)
        res
      end

      # PUT on path and pass the query(Hash)
      def put(path, query={}, session=nil)
        req = Net::HTTP::Put.new(path, header(session,"PUT",path))
        req.form_data = query.merge(:format => OUT_FORMAT)
        res = Net::HTTP.new(Configuration::host,Configuration::port).start {|http| http.request(req) }
        raise_if_response_error(res)
        true
      end

      # DELETE on path
      def delete(path, session=nil)
        res = Net::HTTP.start(Configuration::host,Configuration::port) {|http| http.delete(path+"."+OUT_FORMAT, header(session,"DELETE",path+"."+OUT_FORMAT))}
        raise_if_response_error(res)
        true
      end

      def post_multipart(path, attributes={}, session=nil) #:nodoc:
        file = attributes.delete(:file)
        params = [file_to_multipart("data", File.basename(file),"application/octet-stream", File.read(file))]
        attributes.merge("format" => OUT_FORMAT).each_pair{|k,v| params << text_to_multipart(k.to_s, v.to_s)}

        boundary = '349832898984244898448024464570528145'
        query = params.collect {|p| '--' + boundary + "\r\n" + p}.join('') + "--" + boundary + "--\r\n"
        res = Net::HTTP.start(Configuration::host,Configuration::port) {|http| http.post(path, query, header(session,"POST",path).merge("Content-Type" => "multipart/form-data; boundary=" + boundary))}
        raise_if_response_error(res)
        res
      end

      def text_to_multipart(key,value) #:nodoc:
        return "Content-Disposition: form-data; name=\"#{CGI::escape(key.to_s)}\"\r\n" + 
               "\r\n" + 
               "#{value}\r\n"
      end

      def file_to_multipart(key,filename,mime_type,content) #:nodoc:
        return "Content-Disposition: form-data; name=\"#{CGI::escape(key.to_s)}\"; filename=\"#{filename}\"\r\n" +
               "Content-Transfer-Encoding: binary\r\n" +
               "Content-Type: #{mime_type}\r\n" + 
               "\r\n" + 
               "#{content}\r\n"
      end
    end
  end
end
