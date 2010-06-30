class HomeController < ApplicationController
  has_mobile_fu

  def index
    @search = Search.new
    @title = "USA Search"
  end
  
  def contact_form
    @title = "USA.gov Mobile"
    if request.method == :post
      @email = params["email"]
      @message = params["message"]
      if @email.blank? || @message.blank?
        flash[:notice] = "Missing required fields (*)"
      else
        if @email =~ /^[a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$/
          Emailer.deliver_mobile_feedback(@email, @message)
          flash[:notice] = "Thank you for contacting USA.gov. We will respond to you within two business days."
          @thank_you = true
        else
          flash[:notice] = "Email address is not valid"
        end
      end
    end
  end
end
