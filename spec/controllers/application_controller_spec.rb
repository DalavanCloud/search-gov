require 'spec/spec_helper'

# An example controller for testing various things.
class ExampleController < ApplicationController 
  def missing_template
    respond_to do |format|
      format.html{ render :text => 'Hello, World!' }
      format.any
    end
  end  
end

# draw the route for he example controller

describe ExampleController do
  render_views
  before do
    Rails.application.routes.draw do |map|
      resources :example, :only => [:index] do
        collection do
          get :missing_template
        end
      end
    end
  end
  
  after do
    Rails.application.reload_routes!
  end
    
  context "when a request raises an ActionView::MissingTemplate error" do
    context "when the format for the request is a valid format" do
      it "should raise an error" do
        lambda { get :missing_template, :format => 'json' }.should raise_error(ActionView::MissingTemplate)
      end
    end
    
    context "when the format for the request is not a valid format" do
      it "should render a 406" do
        get :missing_template, :format => "orig"
        response.code.should == "406"
      end
    end
  end  
end