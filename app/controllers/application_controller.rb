# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication

  helper_method :current_user

  private

  def current_user
    Current.user
  end
end
