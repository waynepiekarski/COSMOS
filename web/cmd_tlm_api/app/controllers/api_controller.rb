class ApiController < ApplicationController
  def screens
    render :json => Screen.all(params[:scope].upcase, params[:target].upcase)
  end

  def screen
    screen = Screen.find(params[:scope].upcase, params[:target].upcase, params[:screen].downcase)
    if screen
      render :json => screen
    else
      head :not_found
    end
  end

  def api
    req = Rack::Request.new(request.env)

    # ACL allow_addr? function takes address in the form returned by
    # IPSocket.peeraddr.
    req_addr = ["AF_INET", req.port, req.host.to_s, req.ip.to_s]

    # if Cosmos::CmdTlmServer.instance.json_drb.acl and !Cosmos::CmdTlmServer.instance.json_drb.acl.allow_addr?(req_addr)
    #  status       = 403
    #  content_type = "text/plain"
    #  body         = "Forbidden"
    if request.post?
      status, content_type, body = handle_post(req)
    else
      status       = 405
      content_type = "text/plain"
      body         = "Request not allowed"
    end

    rack_response = Rack::Response.new([body], status, {'Content-Type' => content_type})
    self.response = ActionDispatch::Response.new(*rack_response.to_a)
    self.response.close
  end

  # Handles an http post.
  #
  # @param request [Rack::Request] - A rack post request
  # @return [Integer, String, String] - Http response code, content type,
  #   response body.
  def handle_post(request)
    request_data = request.body.read
    start_time = Time.now.sys
    response_data, error_code = Cosmos::CmdTlmServer.instance.json_drb.process_request(request_data, start_time)

    # Convert json error code into html status code
    # see http://www.jsonrpc.org/historical/json-rpc-over-http.html#errors
    if error_code
      case error_code
        when Cosmos::JsonRpcError::ErrorCode::PARSE_ERROR      then status = 500 # Internal server error
        when Cosmos::JsonRpcError::ErrorCode::INVALID_REQUEST  then status = 400 # Bad request
        when Cosmos::JsonRpcError::ErrorCode::METHOD_NOT_FOUND then status = 404 # Not found
        when Cosmos::JsonRpcError::ErrorCode::INVALID_PARAMS   then status = 500 # Internal server error
        when Cosmos::JsonRpcError::ErrorCode::INTERNAL_ERROR   then status = 500 # Internal server error
        when Cosmos::JsonRpcError::ErrorCode::AUTH_ERROR       then status = 401
        when Cosmos::JsonRpcError::ErrorCode::FORBIDDEN_ERROR  then status = 403
        else status = 500 # Internal server error
      end
    else
      status = 200 # OK
    end

    return status, "application/json-rpc", response_data
  end
end